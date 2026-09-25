#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import ctypes
import os
import threading
import time
import weakref
from ctypes import byref, c_bool, c_double, c_float, c_int32, c_long, c_uint32, c_void_p

from PyQt6.QtCore import QEvent, QObject, QPoint, QPointF, QTimer, Qt, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QCursor, QImage, QMouseEvent
from PyQt6.QtWidgets import QApplication

from core.utils import eval_in_emacs, get_emacs_func_result


class CGPoint(ctypes.Structure):
    _fields_ = [("x", c_double), ("y", c_double)]


class CGSize(ctypes.Structure):
    _fields_ = [("width", c_double), ("height", c_double)]


class CGRect(ctypes.Structure):
    _fields_ = [("origin", CGPoint), ("size", CGSize)]


class NSPoint(ctypes.Structure):
    _fields_ = [("x", c_double), ("y", c_double)]


class NSSize(ctypes.Structure):
    _fields_ = [("width", c_double), ("height", c_double)]


class NSRect(ctypes.Structure):
    _fields_ = [("origin", NSPoint), ("size", NSSize)]


class MacOSDisplayLink:
    """Drive a callback from CoreVideo's real display-refresh cadence.

    CoreVideo invokes this callback shortly before each display frame.  It
    does not increase a 60 Hz display to 120 Hz; it merely replaces an
    arbitrarily phased QTimer with the WindowServer's actual refresh signal.
    """

    def __init__(self, callback):
        self.callback = callback
        self.core_video = ctypes.CDLL(
            "/System/Library/Frameworks/CoreVideo.framework/CoreVideo")
        callback_type = ctypes.CFUNCTYPE(
            c_int32, c_void_p, c_void_p, c_void_p,
            ctypes.c_uint64, ctypes.POINTER(ctypes.c_uint64), c_void_p)

        self.core_video.CVDisplayLinkCreateWithActiveCGDisplays.argtypes = [
            ctypes.POINTER(c_void_p)]
        self.core_video.CVDisplayLinkCreateWithActiveCGDisplays.restype = c_int32
        self.core_video.CVDisplayLinkSetOutputCallback.argtypes = [
            c_void_p, callback_type, c_void_p]
        self.core_video.CVDisplayLinkSetOutputCallback.restype = c_int32
        self.core_video.CVDisplayLinkStart.argtypes = [c_void_p]
        self.core_video.CVDisplayLinkStart.restype = c_int32
        self.core_video.CVDisplayLinkStop.argtypes = [c_void_p]
        self.core_video.CVDisplayLinkStop.restype = c_int32
        self.core_video.CVDisplayLinkRelease.argtypes = [c_void_p]
        self.core_video.CVDisplayLinkRelease.restype = None
        self.core_video.CVDisplayLinkGetActualOutputVideoRefreshPeriod.argtypes = [
            c_void_p]
        self.core_video.CVDisplayLinkGetActualOutputVideoRefreshPeriod.restype = (
            c_double)

        self._callback = callback_type(self._handle_frame)
        self._link = c_void_p()
        result = self.core_video.CVDisplayLinkCreateWithActiveCGDisplays(
            byref(self._link))
        if result != 0 or not self._link:
            raise OSError(result, "CVDisplayLinkCreateWithActiveCGDisplays failed")

        result = self.core_video.CVDisplayLinkSetOutputCallback(
            self._link, self._callback, None)
        if result != 0:
            self._release()
            raise OSError(result, "CVDisplayLinkSetOutputCallback failed")

        result = self.core_video.CVDisplayLinkStart(self._link)
        if result != 0:
            self._release()
            raise OSError(result, "CVDisplayLinkStart failed")

    def _handle_frame(self, _display_link, _now, _output_time,
                      _flags_in, _flags_out, _context):
        try:
            self.callback()
        except Exception:
            import traceback
            traceback.print_exc()
        return 0

    @property
    def refresh_period(self):
        if not self._link:
            return 0.0
        return self.core_video.CVDisplayLinkGetActualOutputVideoRefreshPeriod(
            self._link)

    def stop(self):
        if self._link:
            self.core_video.CVDisplayLinkStop(self._link)
            self._release()

    def _release(self):
        if self._link:
            self.core_video.CVDisplayLinkRelease(self._link)
            self._link = c_void_p()

    def __del__(self):
        try:
            self.stop()
        except Exception:
            pass


class MacOSWindowBridge:
    """Read native macOS window geometry and foreground application state."""

    window_list_options = 1 | 16  # On-screen windows, excluding desktop elements.
    cf_number_sint32_type = 3

    def __init__(self):
        self.core_graphics = ctypes.CDLL(
            "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
        self.core_foundation = ctypes.CDLL(
            "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
        ctypes.CDLL("/System/Library/Frameworks/AppKit.framework/AppKit")
        self.objc = ctypes.CDLL("/usr/lib/libobjc.A.dylib")

        self._configure_core_graphics()
        self._configure_objc()

    def _configure_core_graphics(self):
        cg = self.core_graphics
        cf = self.core_foundation

        cg.CGWindowListCopyWindowInfo.argtypes = [c_uint32, c_uint32]
        cg.CGWindowListCopyWindowInfo.restype = c_void_p
        cg.CGRectMakeWithDictionaryRepresentation.argtypes = [
            c_void_p, ctypes.POINTER(CGRect)]
        cg.CGRectMakeWithDictionaryRepresentation.restype = c_bool

        cg.CGEventSourceCreate.restype = c_void_p
        cg.CGEventSourceCreate.argtypes = [c_uint32]
        cg.CGEventSourceButtonState.restype = c_bool
        cg.CGEventSourceButtonState.argtypes = [c_uint32, c_uint32]
        self.event_source = cg.CGEventSourceCreate(1)  # HIDSystemState.

        cg.CGEventCreateMouseEvent.restype = c_void_p
        cg.CGEventCreateMouseEvent.argtypes = [
            c_void_p, c_uint32, ctypes.POINTER(CGPoint), c_uint32]
        cg.CGEventPost.restype = None
        cg.CGEventPost.argtypes = [c_uint32, c_void_p]
        cg.CGEventPostToPid.restype = None
        cg.CGEventPostToPid.argtypes = [c_int32, c_void_p]
        self.event_tap_hid = 0

        cf.CFArrayGetCount.argtypes = [c_void_p]
        cf.CFArrayGetCount.restype = c_long
        cf.CFArrayGetValueAtIndex.argtypes = [c_void_p, c_long]
        cf.CFArrayGetValueAtIndex.restype = c_void_p
        cf.CFDictionaryGetValue.argtypes = [c_void_p, c_void_p]
        cf.CFDictionaryGetValue.restype = c_void_p
        cf.CFNumberGetValue.argtypes = [c_void_p, c_long, c_void_p]
        cf.CFNumberGetValue.restype = c_bool
        cf.CFRelease.argtypes = [c_void_p]

        self.owner_pid_key = c_void_p.in_dll(cg, "kCGWindowOwnerPID").value
        self.window_number_key = c_void_p.in_dll(cg, "kCGWindowNumber").value
        self.window_layer_key = c_void_p.in_dll(cg, "kCGWindowLayer").value
        self.bounds_key = c_void_p.in_dll(cg, "kCGWindowBounds").value

    def _configure_objc(self):
        self.objc.objc_getClass.argtypes = [ctypes.c_char_p]
        self.objc.objc_getClass.restype = c_void_p
        self.objc.sel_registerName.argtypes = [ctypes.c_char_p]
        self.objc.sel_registerName.restype = c_void_p

        self.send_object = ctypes.CFUNCTYPE(
            c_void_p, c_void_p, c_void_p)(("objc_msgSend", self.objc))
        self.send_pid = ctypes.CFUNCTYPE(
            c_int32, c_void_p, c_void_p)(("objc_msgSend", self.objc))
        self.send_object_pid = ctypes.CFUNCTYPE(
            c_void_p, c_void_p, c_void_p, c_int32)(
                ("objc_msgSend", self.objc))
        self.send_bool_options = ctypes.CFUNCTYPE(
            c_bool, c_void_p, c_void_p, ctypes.c_ulong)(
                ("objc_msgSend", self.objc))
        self.send_object_object = ctypes.CFUNCTYPE(
            c_void_p, c_void_p, c_void_p, c_void_p)(
                ("objc_msgSend", self.objc))
        self.send_object_object_bool = ctypes.CFUNCTYPE(
            c_void_p, c_void_p, c_void_p, c_void_p, ctypes.c_bool)(
                ("objc_msgSend", self.objc))
        self.send_rect = ctypes.CFUNCTYPE(
            NSRect, c_void_p, c_void_p)(("objc_msgSend", self.objc))
        self.send_point_arg = ctypes.CFUNCTYPE(
            NSPoint, c_void_p, c_void_p, NSPoint)(
                ("objc_msgSend", self.objc))
        self.send_long = ctypes.CFUNCTYPE(
            c_long, c_void_p, c_void_p)(("objc_msgSend", self.objc))
        self.send_mouse_event = ctypes.CFUNCTYPE(
            c_void_p, c_void_p, c_void_p,
            c_int32, NSPoint, ctypes.c_ulong, c_double, c_long,
            c_void_p, c_long, c_long, c_float)(
                ("objc_msgSend", self.objc))
        # [NSColor colorWithSRGBRed:green:blue:alpha:] -> NSColor.
        self.send_color = ctypes.CFUNCTYPE(
            c_void_p, c_void_p, c_void_p,
            c_double, c_double, c_double, c_double)(
                ("objc_msgSend", self.objc))
        # Methods with a single BOOL argument, e.g. [NSWindow setHasShadow:].
        self.send_bool_arg = ctypes.CFUNCTYPE(
            c_void_p, c_void_p, c_void_p, c_bool)(
                ("objc_msgSend", self.objc))

        workspace_class = self.objc.objc_getClass(b"NSWorkspace")
        self.workspace = self.send_object(
            workspace_class, self.objc.sel_registerName(b"sharedWorkspace"))
        self.frontmost_application_selector = self.objc.sel_registerName(
            b"frontmostApplication")
        self.process_identifier_selector = self.objc.sel_registerName(
            b"processIdentifier")
        self.running_application_class = self.objc.objc_getClass(
            b"NSRunningApplication")
        self.running_application_selector = self.objc.sel_registerName(
            b"runningApplicationWithProcessIdentifier:")
        self.activate_selector = self.objc.sel_registerName(
            b"activateWithOptions:")
        application_class = self.objc.objc_getClass(b"NSApplication")
        self.application = self.send_object(
            application_class,
            self.objc.sel_registerName(b"sharedApplication"))
        self.set_activation_policy_selector = self.objc.sel_registerName(
            b"setActivationPolicy:")

    def _dictionary_int(self, dictionary, key):
        value = self.core_foundation.CFDictionaryGetValue(dictionary, key)
        if not value:
            return None

        result = c_int32()
        if self.core_foundation.CFNumberGetValue(
                value, self.cf_number_sint32_type, byref(result)):
            return result.value
        return None

    def emacs_windows(self, emacs_pid):
        """Return on-screen, normal-layer windows owned by Emacs."""
        windows = self.core_graphics.CGWindowListCopyWindowInfo(
            self.window_list_options, 0)
        if not windows:
            return {}

        result = {}
        try:
            for index in range(self.core_foundation.CFArrayGetCount(windows)):
                info = self.core_foundation.CFArrayGetValueAtIndex(windows, index)
                if self._dictionary_int(info, self.owner_pid_key) != emacs_pid:
                    continue
                if self._dictionary_int(info, self.window_layer_key) != 0:
                    continue

                window_number = self._dictionary_int(
                    info, self.window_number_key)
                bounds_dictionary = self.core_foundation.CFDictionaryGetValue(
                    info, self.bounds_key)
                bounds = CGRect()
                if (window_number is not None and bounds_dictionary and
                        self.core_graphics.CGRectMakeWithDictionaryRepresentation(
                            bounds_dictionary, byref(bounds))):
                    result[window_number] = (
                        bounds.origin.x,
                        bounds.origin.y,
                        bounds.size.width,
                        bounds.size.height)
        finally:
            self.core_foundation.CFRelease(windows)

        return result

    def frontmost_pid(self):
        """Return the process identifier of the frontmost macOS application."""
        application = self.send_object(
            self.workspace, self.frontmost_application_selector)
        if not application:
            return None
        return self.send_pid(application, self.process_identifier_selector)

    def left_button_down(self):
        """Return whether the left mouse button is down anywhere on the system.

        Uses the HID-system state, so it reflects clicks on OTHER applications
        (the EAF process never sees those events), unlike Qt's
        `QApplication.mouseButtons'."""
        return bool(self.core_graphics.CGEventSourceButtonState(1, 0))

    def post_mouse_click(self, x, y):
        """Post a real left-button click at global coordinates (X, Y).

        Delivered by the window server to the frontmost application at that
        point, so once EAF is frontmost this behaves exactly like a genuine
        user click (Chromium places the caret, DOM gets focus).  Requires the
        EAF process to have Accessibility permission; fails silently otherwise."""
        cg = self.core_graphics
        point = CGPoint(x, y)
        for event_type in (1, 2):  # kCGEventLeftMouseDown, kCGEventLeftMouseUp.
            event = cg.CGEventCreateMouseEvent(
                self.event_source, event_type, ctypes.byref(point), 0)
            if event:
                cg.CGEventPost(self.event_tap_hid, event)
                self.core_foundation.CFRelease(event)

    def post_mouse_click_to_pid(self, pid, x, y):
        """Post a real left-button click into process PID at (X, Y).

        `CGEventPostToPid' delivers the event straight to the given process's
        event queue.  Posting to EAF's own pid usually works without the
        Accessibility permission that `CGEventPost' needs, and the event lands
        on the window under the point exactly like a real click."""
        cg = self.core_graphics
        point = CGPoint(x, y)
        for event_type in (1, 2):  # kCGEventLeftMouseDown, kCGEventLeftMouseUp.
            event = cg.CGEventCreateMouseEvent(
                self.event_source, event_type, ctypes.byref(point), 0)
            if event:
                cg.CGEventPostToPid(int(pid), event)
                self.core_foundation.CFRelease(event)

    def send_real_click(self, ns_view, global_x, global_y):
        """Deliver a genuine mouse click to the NSWindow containing NS_VIEW.

        Builds real NSEvents and posts them into our own NSApplication queue,
        so they travel Qt's normal input path and QtWebEngine processes them
        like a real user click -- no Accessibility permission required (unlike
        `CGEventPost').  GLOBAL_X/Y are in top-left-origin screen points."""
        try:
            objc = self.objc
            nswindow = self.send_object(
                int(ns_view), objc.sel_registerName(b"window"))
            if not nswindow:
                return False
            frame = self.send_rect(nswindow, objc.sel_registerName(b"frame"))
            screen = self.send_object(
                self.application, objc.sel_registerName(b"mainScreen"))
            screen_frame = self.send_rect(
                screen, objc.sel_registerName(b"frame"))
            # Convert top-left-origin global point to window base coords
            # (AppKit screen coords are bottom-left origin).
            screen_point = NSPoint(
                float(global_x),
                screen_frame.size.height - float(global_y))
            base = self.send_point_arg(
                nswindow, objc.sel_registerName(b"convertScreenToBase:"),
                screen_point)
            win_num = self.send_long(
                nswindow, objc.sel_registerName(b"windowNumber"))
            event_cls = objc.objc_getClass(b"NSEvent")
            create_sel = objc.sel_registerName(
                b"mouseEventWithType:location:modifierFlags:timestamp:"
                b"windowNumber:context:eventNumber:clickCount:pressure:")
            post_sel = objc.sel_registerName(b"postEvent:atStart:")
            for event_type in (1, 2):  # LeftMouseDown, LeftMouseUp.
                event = self.send_mouse_event(
                    event_cls, create_sel,
                    event_type, base, 0, 0.0, win_num, None, 0, 1, 1.0)
                if event:
                    self.send_object_object_bool(
                        self.application, post_sel, event, False)
            return True
        except Exception:
            import traceback
            traceback.print_exc()
            return False

    def activate_application(self, pid):
        """Activate a running application immediately through AppKit."""
        application = self.send_object_pid(
            self.running_application_class,
            self.running_application_selector,
            int(pid))
        if not application:
            return False
        return self.send_bool_options(
            application, self.activate_selector, 1)  # Activate all windows.

    def hide_dock_icon(self):
        """Run EAF as a UI accessory without a Dock or Cmd-Tab icon."""
        return self.send_bool_options(
            self.application,
            self.set_activation_policy_selector,
            1)  # NSApplicationActivationPolicyAccessory.

    def make_key_window(self, ns_view):
        """Make the NSWindow containing NS_VIEW the key window of the app.

        Qt's `activateWindow' can leave a sibling window as the key window when
        several EAF views exist, so we ask AppKit directly."""
        try:
            objc = self.objc
            nswindow = self.send_object(
                int(ns_view), objc.sel_registerName(b"window"))
            if nswindow:
                self.send_object_object(
                    nswindow, objc.sel_registerName(b"makeKeyAndOrderFront:"),
                    None)
                return True
        except Exception:
            return False
        return False

    def _nswindow_of_view(self, ns_view):
        """Return the NSWindow hosting NS_VIEW (an NSView pointer), or None."""
        try:
            return self.send_object(
                int(ns_view), self.objc.sel_registerName(b"window"))
        except Exception:
            return None

    def set_view_has_shadow(self, ns_view, has_shadow):
        """Enable/disable the native NSWindow shadow of an EAF view window.

        Frameless Qt windows still get a system-drawn shadow on macOS
        (NoDropShadowWindowHint is not honoured); while the window is being
        dragged or re-shown that shadow reads as a light/white frame around
        the outermost edges.  Turn it off on the real NSWindow."""
        try:
            nswindow = self._nswindow_of_view(ns_view)
            if nswindow:
                self.send_bool_arg(
                    nswindow,
                    self.objc.sel_registerName(b"setHasShadow:"),
                    c_bool(bool(has_shadow)))
        except Exception:
            pass

    def set_view_background(self, ns_view, r, g, b):
        """Paint the NSWindow background of NS_VIEW with (R, G, B) in 0..1.

        Qt paints the dark theme inside the window, but the native NSWindow
        backing is default white; while the window is moved/resized during a
        drag or re-shown, the window server can present that white backing
        around the (lagging) web content -- a white border on the outermost
        edge.  Filling the NSWindow's own background makes every frame the
        window server draws use the theme color instead."""
        try:
            nswindow = self._nswindow_of_view(ns_view)
            if not nswindow:
                return
            objc = self.objc
            color_class = objc.objc_getClass(b"NSColor")
            color = self.send_color(
                color_class,
                objc.sel_registerName(b"colorWithSRGBRed:green:blue:alpha:"),
                float(r), float(g), float(b), 1.0)
            if color:
                self.send_object_object(
                    nswindow,
                    objc.sel_registerName(b"setBackgroundColor:"),
                    color)
        except Exception:
            pass


class MacOSWindowTracker(QObject):
    """Keep top-level EAF views aligned with their macOS Emacs windows."""

    edge_anchor_margin = 100
    _display_link_frame = pyqtSignal()

    def __init__(self, emacs_pid, views, bridge=None, hide_views=None):
        super().__init__()
        self.emacs_pid = int(emacs_pid)
        self.eaf_pid = os.getpid()
        self.views = views
        self.hide_views = hide_views
        # Follow the Emacs frame's movement in real time.  With this off the
        # only geometry source is Emacs's `eaf--monitor-configuration-change',
        # which is debounced (0.08s after the last change), so dragging the
        # Emacs window leaves the EAF window trailing behind.  The native
        # per-tick path reads the real NSWindow bounds each tick and avoids
        # timer-phase sampling error; the independent top-level window can
        # still incur WindowServer's normal display-commit delay.
        self._test_no_reposition = False
        # Keep *sizes* on the Emacs path.  Resizing the QtWebEngine window every
        # few ms (which a continuous resize drag would do) is a suspected trigger
        # of the compositor black frame, and Emacs already sends the settled size
        # once the resize stops.  Position-only tracking is enough to fix the
        # movement lag and never resizes the web view.
        self._allow_tracker_resize = False
        self.bridge = bridge or MacOSWindowBridge()
        self.last_frontmost_pid = None
        # Cold-start wake-up.  A freshly spawned EAF process has never been the
        # active application, so its always-on-top QtWebEngine windows never get
        # an exposure/focus event and stay black until the user clicks one.
        # For a short window after start we reproduce that click's activation
        # once per buffer (then hand focus back to Emacs) instead of reloading.
        self._started_at = time.monotonic()
        self._wake_done = set()
        # Polled left-button state: we record the position and time of the
        # button going down so a click that activates Emacs (from the EAF
        # process's point of view an event on another application) can be
        # replayed regardless of exactly which 16ms tick notices it.
        self._was_down = False
        self._down_pos = None
        self._down_time = None
        # Click-replay window state.  During the replay the tracker must NOT
        # reset the replayed buffer's input_mode when Emacs happens to be
        # frontmost again (the original click can re-activate Emacs late), and
        # we periodically re-assert EAF frontmost + web focus to win the race.
        self._replay_buffer_id = None
        self._replay_view = None
        self._replay_widget = None
        self._replay_pos = None
        self._replay_focus_js = None
        self._replay_until = 0.0
        self._replay_timer = None

        # Black-window watchdog.  A QtWebEngine view on macOS can lose its
        # compositor and start presenting a uniform near-black frame while the
        # page keeps running (no crash, no error); it has no deterministic
        # trigger, so instead of trying to prevent it we sample each visible
        # view and reload the ones that went black.  hide/show and a
        # resize-tickle were measured NOT to recover the compositor, so reload
        # (which rebuilds the page) is the recovery; two reloads without a
        # healthy frame within ~10s stop and notify instead of looping.
        self._black_check_interval = 2.0
        self._black_elapsed = 0.0
        self._black_last_time = time.monotonic()
        # True reloads black views automatically (currently OFF while the root
        # cause is being diagnosed: reload-looping a window whose compositor is
        # dead was destroying app sessions for no benefit).
        self._black_auto_heal = False
        self._black_state = {}   # buffer_id -> dict(suspects, reloads, cooldown_until)

        self.timer = QTimer(self)
        self.timer.setTimerType(Qt.TimerType.PreciseTimer)
        self.timer.timeout.connect(self.update)
        # The default remains the old Qt-timer path.  Set
        # EAF_MACOS_TRACKER_DRIVER=display-link for the A/B experiment: the
        # callback is queued to the GUI thread once per actual display frame,
        # while this timer remains the immediate fallback if CoreVideo is
        # unavailable.  Neither path raises the physical 60 Hz refresh rate.
        self._display_link = None
        self._display_link_pending = False
        self._display_link_pending_lock = threading.Lock()
        self._display_link_frame.connect(
            self._on_display_link_frame,
            Qt.ConnectionType.QueuedConnection)
        driver = os.environ.get(
            "EAF_MACOS_TRACKER_DRIVER", "qt-timer").strip().lower()
        self.tracker_driver = driver
        if driver in ("display-link", "display_link", "native", "cadisplaylink"):
            tracker_ref = weakref.ref(self)

            def request_display_link_frame():
                tracker = tracker_ref()
                if tracker is not None:
                    tracker._queue_display_link_update()

            try:
                self._display_link = MacOSDisplayLink(
                    request_display_link_frame)
            except Exception:
                self._log_exception()
                self._display_link = None

        if self._display_link is not None:
            refresh_ms = self._display_link.refresh_period * 1000.0
            refresh_info = ("refresh=%.2fms" % refresh_ms
                            if refresh_ms > 0 else "refresh=adaptive")
            self._log("MacOSWindowTracker started (emacs=%s eaf=%s; "
                      "driver=display-link; %s)" %
                      (self.emacs_pid, self.eaf_pid, refresh_info))
        else:
            if driver not in ("qt-timer", "timer"):
                self._log("MacOSWindowTracker display-link unavailable; "
                          "falling back to qt-timer")
            # Poll once per display frame.  Measured on this machine: the EAF
            # window's position can only advance at the display refresh anyway
            # (app-driven window moves commit at vsync, ~17ms), while the
            # dragged Emacs frame moves per input event (~4ms).  A faster timer
            # therefore only adds duplicate wakeups; it does not remove the
            # residual independent-window commit delay.
            self.timer.start(16)
            self._log("MacOSWindowTracker started (emacs=%s eaf=%s; "
                      "driver=qt-timer; interval=16ms)" %
                      (self.emacs_pid, self.eaf_pid))

    @staticmethod
    def _contains(bounds, x, y):
        left, top, width, height = bounds
        return left <= x <= left + width and top <= y <= top + height

    @staticmethod
    def _distance_to_bounds(bounds, x, y):
        left, top, width, height = bounds
        nearest_x = min(max(x, left), left + width)
        nearest_y = min(max(y, top), top + height)
        return (x - nearest_x) ** 2 + (y - nearest_y) ** 2

    def _attach_view(self, view, windows):
        if not windows:
            return

        if view.emacs_frame_geometry is not None:
            frame_x, frame_y, frame_width, frame_height = \
                view.emacs_frame_geometry
            window_number, bounds = min(
                windows.items(),
                key=lambda candidate: (
                    (candidate[1][0] - frame_x) ** 2 +
                    (candidate[1][1] - frame_y) ** 2 +
                    (candidate[1][2] - frame_width) ** 2 +
                    (candidate[1][3] - frame_height) ** 2))
            metrics_bounds = view.emacs_frame_geometry
        else:
            center_x = view.x + view.width / 2
            center_y = view.y + view.height / 2
            containing_candidates = [
                (window_number, bounds)
                for window_number, bounds in windows.items()
                if self._contains(bounds, center_x, center_y)
            ]
            candidates = containing_candidates or list(windows.items())
            if containing_candidates:
                window_number, bounds = min(
                    candidates,
                    key=lambda candidate: candidate[1][2] * candidate[1][3])
            else:
                window_number, bounds = min(
                    candidates,
                    key=lambda candidate: self._distance_to_bounds(
                        candidate[1], center_x, center_y))
            metrics_bounds = bounds

        view.macos_window_number = window_number
        view.macos_window_metrics = (
            view.x - metrics_bounds[0],
            view.y - metrics_bounds[1],
            metrics_bounds[0] + metrics_bounds[2] - view.x - view.width,
            metrics_bounds[1] + metrics_bounds[3] - view.y - view.height,
            view.width,
            view.height)

    def _axis_geometry(self, start, extent, leading, trailing, view_extent):
        leading_anchored = 0 <= leading <= self.edge_anchor_margin
        trailing_anchored = 0 <= trailing <= self.edge_anchor_margin

        if leading_anchored and trailing_anchored:
            target_start = start + leading
            target_extent = max(1, extent - leading - trailing)
        elif leading_anchored:
            target_start = start + leading
            target_extent = view_extent
        elif trailing_anchored:
            target_extent = view_extent
            target_start = start + extent - trailing - target_extent
        else:
            target_extent = view_extent
            free_space = max(0, extent - target_extent)
            original_free_space = max(1, leading + trailing)
            target_start = start + free_space * leading / original_free_space

        return round(target_start), round(target_extent)

    def _update_view_position(self, view, windows):
        if view.macos_window_number is None:
            self._attach_view(view, windows)

        if (view.macos_window_number is None or
                view.macos_window_metrics is None or
                view.macos_window_number not in windows):
            return False

        bounds = windows[view.macos_window_number]
        left, top, right, bottom, view_width, view_height = \
            view.macos_window_metrics
        target_x, target_width = self._axis_geometry(
            bounds[0], bounds[2], left, right, view_width)
        target_y, target_height = self._axis_geometry(
            bounds[1], bounds[3], top, bottom, view_height)

        if target_x != view.x or target_y != view.y:
            handle = view.windowHandle()
            if handle is not None:
                view.x = target_x
                view.y = target_y
                handle.setPosition(QPoint(target_x, target_y))
        if self._allow_tracker_resize:
            if target_width != view.width or target_height != view.height:
                view.width = target_width
                view.height = target_height
                view.resize(target_width, target_height)
                return True
        return False

    def _update_frontmost_application(self):
        frontmost_pid = self.bridge.frontmost_pid()
        if frontmost_pid is None:
            return

        previous_pid = self.last_frontmost_pid

        if frontmost_pid == self.emacs_pid:
            for view in self.views():
                if not view.isVisible():
                    view.try_show_top_view()
            # Reset input mode when focus returns to Emacs so that a later
            # `switch_to_input_mode' toggle starts from the OFF state instead of
            # disabling an already-enabled mode (which would keep Emacs focused).
            # Skip the buffer that is mid click-replay: a late Emacs
            # re-activation (from the original click still being processed)
            # must not kill the input mode the replay just enabled.
            for view in self.views():
                buffer = getattr(view, 'buffer', None)
                if (buffer is None or
                        not getattr(buffer, 'input_mode', False)):
                    continue
                if (buffer.buffer_id == self._replay_buffer_id and
                        time.monotonic() < self._replay_until):
                    continue
                buffer.input_mode = False
                try:
                    eval_in_emacs('eaf--toggle-input-mode',
                                  [buffer.buffer_id, "'nil"])
                except Exception:
                    pass

            # A left-click that brought Emacs back from another application and
            # landed inside an EAF view is replayed into the browser: it enables
            # input mode (EAF regains focus, Emacs loses it) and drops the caret
            # where the user clicked, so clicking a text box re-enters typing
            # directly instead of leaving focus stuck on Emacs.  Run it after a
            # short delay so Emacs has processed the click and selected the
            # window that was clicked (see `_maybe_replay_click').
            if previous_pid not in (None, self.emacs_pid, self.eaf_pid):
                QTimer.singleShot(100, self._maybe_replay_click)

        if frontmost_pid == self.eaf_pid:
            # While typing (input mode) EAF itself is frontmost.  A focus
            # hiccup -- e.g. an IME/candidate window briefly registering as a
            # separate frontmost application -- can run the hide path above,
            # and the Emacs-frontmost re-show never fires afterwards, leaving
            # the Emacs buffer underneath empty (which reads as a black box
            # while the user keeps typing).  Re-show any hidden view whenever
            # EAF is frontmost so this state cannot persist.
            for view in self.views():
                if not view.isVisible():
                    self._log("  re-show hidden view on EAF frontmost")
                    view.try_show_top_view()

        external_application = (
            frontmost_pid != self.emacs_pid and
            frontmost_pid != self.eaf_pid)

        if frontmost_pid == self.last_frontmost_pid:
            return

        self.last_frontmost_pid = frontmost_pid
        if (external_application and
                (previous_pid is None or
                 previous_pid in (self.emacs_pid, self.eaf_pid))):
            if self.hide_views is not None:
                # Capture and hide in one Qt event-loop turn.  Hiding here and
                # asking Emacs to capture later races with the asynchronous
                # RPC and produces an empty placeholder.
                self.hide_views()
            else:
                eval_in_emacs('eaf--topmost-macos-focus-out', [])

    def _maybe_replay_click(self):
        """Focus the EAF view whose window the user just clicked back into.

        While Emacs is unfocused EAF hides its Qt views and Emacs shows
        screenshot placeholders, so the click that returns to Emacs lands on the
        image instead of the browser.  Replaying it on the live view enables
        input mode (via BrowserView's MouseButtonPress handler) and places the
        caret where the user clicked.

        Emacs knows exactly which window received the click (clicking selects
        it), so we ask Emacs for the EAF buffer in the current window instead of
        guessing from geometry -- this is what makes multi-window Emacs layouts
        behave: clicking the left window focuses the left browser.

        Only fires for a genuine click (recorded by `_poll_mouse_down' within
        the last half second), so a Cmd-Tab refocus never steals focus from
        Emacs."""
        if self._down_time is None:
            self._log("transition detected, but no mouse-down recorded")
        else:
            self._log("transition detected, down-delta=%.3fs" %
                      (time.monotonic() - self._down_time))
        if (self._down_time is None or
                time.monotonic() - self._down_time > 0.5):
            return

        pos = self._down_pos
        self._log("replay candidate at %s" % (pos,))

        views = self.views()
        self._log("  all views: [%s]" % ", ".join(
            "buffer=%s geom=%s" % (
                getattr(getattr(v, 'buffer', None), 'buffer_id', '?'),
                v.geometry())
            for v in views))

        # Primary: the smallest view whose on-screen rect contains the click
        # point.  The view geometry is reliable, so clicking the left window
        # always selects the left view.
        view = None
        best = None
        best_area = None
        for v in views:
            b = getattr(v, 'buffer', None)
            if b is None:
                continue
            rect = v.geometry()
            if rect.isNull() or not rect.contains(pos):
                continue
            area = rect.width() * rect.height()
            if best_area is None or area < best_area:
                best, best_area = v, area
        view = best

        # Fallback: Emacs's idea of which window the click landed in.
        if view is None:
            buffer_id = None
            try:
                buffer_id = get_emacs_func_result('my/eaf-clicked-buffer-id', [])
            except Exception:
                pass
            self._log("  emacs says clicked buffer: %s" % (buffer_id,))
            if buffer_id:
                for v in views:
                    if (getattr(v, 'buffer', None) is not None and
                            v.buffer.buffer_id == buffer_id):
                        view = v
                        break

        if view is None:
            self._log("  no view matched")
            return

        self._log("  focus view buffer=%s geom=%s" % (
            getattr(view.buffer, 'buffer_id', '?'), view.geometry()))
        view.try_show_top_view()
        # Wait for the window to be mapped before activating and clicking.
        QTimer.singleShot(
            80,
            lambda v=view, p=pos: self._deliver_click_to_view(v, p))

    def _deliver_click_to_view(self, view, global_pos):
        """Give the browser focus and deliver a click at GLOBAL_POS.

        Input mode is enabled by hand instead of via `switch_to_input_mode':
        that function's `_focus_input_window' retries (0/100/250/500ms) activate
        `widget.window()', which is the wrong window when several EAF views
        exist (it reports a window at (0,0)) and steals keyboard focus right
        after the click-replay -- the cause of "text goes nowhere / must click
        twice".  We set input_mode, activate EAF, report to Emacs (so the Rime
        switch and input-mode advice fire) and focus the correct View ourselves.
        The failure is non-fatal: the synthetic press that follows also enables
        input mode via BrowserView's event filter."""
        try:
            if not view.isVisible():
                view.try_show_top_view()

            buffer = getattr(view, 'buffer', None)
            if buffer is not None:
                self._log("  enabling input mode for %s" %
                          getattr(buffer, 'buffer_id', '?'))
                try:
                    buffer.current_event_string = "t"
                    buffer.input_mode = True
                    self.bridge.activate_application(self.eaf_pid)
                    eval_in_emacs('eaf--toggle-input-mode',
                                  [buffer.buffer_id, "'t"])
                    # Open the replay window: the tracker must not reset this
                    # buffer's input_mode during it, and we keep re-asserting
                    # EAF frontmost + web focus to beat the original click's
                    # late Emacs re-activation.
                    self._replay_buffer_id = buffer.buffer_id
                    self._replay_view = view
                    self._replay_widget = buffer.buffer_widget
                    self._replay_pos = global_pos
                    self._replay_focus_js = None
                    self._replay_until = time.monotonic() + 1.0
                    if self._replay_timer is None:
                        self._replay_timer = QTimer()
                        self._replay_timer.setInterval(100)
                        self._replay_timer.timeout.connect(
                            self._reassert_replay)
                    self._replay_timer.start()
                except Exception:
                    self._log_exception()

            QTimer.singleShot(
                150,
                lambda v=view, p=global_pos: self._deliver_synthetic_click(v, p))
        except Exception:
            self._log_exception()

    def _reassert_replay(self):
        """Re-assert EAF frontmost + web focus during the click-replay window.

        The user's original click can re-activate Emacs after we've switched to
        EAF; the tracker would then (without the replay-window guard) reset
        input mode and the first keystrokes would go to Emacs.  This keeps EAF
        in front and the render widget + page element focused until the race
        settles."""
        try:
            if time.monotonic() > self._replay_until:
                if self._replay_timer is not None:
                    self._replay_timer.stop()
                return
            self.bridge.activate_application(self.eaf_pid)
            view = self._replay_view
            widget = self._replay_widget
            if view is not None:
                if not view.isVisible():
                    view.try_show_top_view()
                handle = view.windowHandle()
                if handle is not None:
                    self.bridge.make_key_window(handle.winId())
                view.activateWindow()
            if widget is not None:
                proxy = widget.focusProxy()
                if proxy is not None:
                    proxy.setFocus(Qt.FocusReason.ActiveWindowFocusReason)
                if self._replay_focus_js:
                    widget.eval_js(self._replay_focus_js)
            self._log("  reassert frontmost=%s" %
                      (self.bridge.frontmost_pid() == self.eaf_pid))
        except Exception:
            self._log_exception()

    def _wake_view(self, view):
        """Start VIEW's QtWebEngine compositor on a cold start.

        At EAF process start the view window is shown while the EAF
        application has never been active, so QtWebEngine never receives the
        exposure/focus event that starts compositing and the page stays black
        until the user clicks the window.  Reproduce that click's activation
        here (no synthetic mouse events, no input mode) and then hand keyboard
        focus straight back to Emacs, since the view is always-on-top and keeps
        rendering once the compositor is live."""
        try:
            self.bridge.activate_application(self.eaf_pid)
            if not view.isVisible():
                view.try_show_top_view()
            view.show()
            view.raise_()
            handle = view.windowHandle()
            if handle is not None:
                self.bridge.make_key_window(handle.winId())
            view.activateWindow()
            buffer = getattr(view, 'buffer', None)
            widget = getattr(buffer, 'buffer_widget', None)
            if widget is not None:
                widget.setFocus(Qt.FocusReason.ActiveWindowFocusReason)
                proxy = widget.focusProxy()
                if proxy is not None:
                    proxy.setFocus(Qt.FocusReason.ActiveWindowFocusReason)
            self._log("  wake view buffer=%s geom=%s" % (
                getattr(buffer, 'buffer_id', '?'), view.geometry()))
        except Exception:
            self._log_exception()
        finally:
            QTimer.singleShot(
                400, lambda: self.bridge.activate_application(self.emacs_pid))

    def _deliver_synthetic_click(self, view, global_pos):
        """Place the caret and hand web focus to VIEW at GLOBAL_POS.

        Two complementary mechanisms, both targeting VIEW's own web contents so
        they can never land in a sibling EAF window:

        1. JS `elementFromPoint().focus()` at the click point -- deterministic.
        2. A synthetic Qt mouse press+release delivered straight to VIEW's
           browser widget, so contenteditable editors get a real click too."""
        try:
            if not view.isVisible():
                view.try_show_top_view()
            buffer = getattr(view, 'buffer', None)
            if buffer is None:
                return
            widget = buffer.buffer_widget
            # `widget.window()` is unreliable when multiple EAF views exist (it
            # can report a sibling window), so focus the View itself -- it IS
            # the top-level window that owns this buffer's web contents.
            try:
                view.show()
                view.raise_()
                handle = view.windowHandle()
                if handle is not None:
                    key = self.bridge.make_key_window(handle.winId())
                    self._log("  makeKeyAndOrderFront=%s" % (key,))
                view.activateWindow()
                # The render widget (focusProxy) must be Qt's focus widget or
                # keys never reach the page.  `makeKeyAndOrderFront:' above
                # resets Qt focus to the window, so set it LAST and re-assert
                # shortly after so nothing has a chance to steal it back.
                widget.setFocus(Qt.FocusReason.ActiveWindowFocusReason)
                proxy = widget.focusProxy()
                if proxy is not None:
                    proxy.setFocus(Qt.FocusReason.ActiveWindowFocusReason)
                    QTimer.singleShot(
                        60,
                        lambda p=proxy: p.setFocus(
                            Qt.FocusReason.ActiveWindowFocusReason))
                    self._log("  proxy type=%s hasFocus=%s" % (
                        type(proxy).__name__, proxy.hasFocus()))
            except Exception:
                self._log_exception()
            try:
                self._log("  view=%s view.window()=%s widget.window()=%s" % (
                    view.geometry(),
                    view.window().geometry(),
                    widget.window().geometry()))
            except Exception:
                pass
            local = widget.mapFromGlobal(global_pos)
            self._log("  caret buffer=%s widget-local=%s view-visible=%s" % (
                getattr(buffer, 'buffer_id', '?'), local, view.isVisible()))

            # QtWebEngine maps CSS px 1:1 to widget logical px at zoom 1, so the
            # widget-local point is the page viewport point directly.
            css_x = local.x()
            css_y = local.y()
            self._log("  css=(%.1f,%.1f)" % (css_x, css_y))

            focus_js = (
                "(()=>{"
                "const X=%s,Y=%s;"
                "function pick(d,x,y){"
                "let e=d.elementFromPoint(x,y);"
                "if(e&&e.tagName==='IFRAME'){try{const r=e.getBoundingClientRect();"
                "const p=pick(e.contentDocument,x-r.left,y-r.top);if(p&&p.el)return p;}catch(_){}}"
                "return {el:e,d:d,x:x,y:y};}"
                "const p=pick(document,X,Y);let e=p.el;if(!e)return;"
                "let n=e;while(n&&n!==p.d.body&&!/^(INPUT|TEXTAREA|SELECT)$/.test(n.tagName)&&!n.isContentEditable)n=n.parentElement;"
                "let el=(n&&n!==p.d.body)?n:e;"
                "if(/^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName)){el.focus();el.click&&el.click();return;}"
                "if(el.isContentEditable){el.focus();"
                "const r=el.ownerDocument.caretRangeFromPoint?el.ownerDocument.caretRangeFromPoint(p.x,p.y):null;"
                "if(r){const s=el.ownerDocument.getSelection();s.removeAllRanges();s.addRange(r);}return;}"
                "                if(el.querySelector){const q=el.querySelector('input,textarea,select,[contenteditable]');"
                "if(q){q.focus();if(/^(INPUT|TEXTAREA|SELECT)$/.test(q.tagName))q.click&&q.click();}}})()"
                % (css_x, css_y))
            if (self._replay_view is view and
                    time.monotonic() < self._replay_until):
                self._replay_focus_js = focus_js

            # 1) A synthetic press/release straight to the render widget.
            try:
                proxy = widget.focusProxy()
                target = proxy if proxy is not None else widget
                target_local = target.mapFromGlobal(global_pos)
                for event_type in (QEvent.Type.MouseButtonPress,
                                   QEvent.Type.MouseButtonRelease):
                    event = QMouseEvent(
                        event_type,
                        QPointF(target_local),
                        QPointF(global_pos),
                        Qt.MouseButton.LeftButton,
                        Qt.MouseButton.LeftButton,
                        Qt.KeyboardModifier.NoModifier)
                    accepted = QApplication.sendEvent(target, event)
                    self._log("  mouse %s -> %s accepted=%s" % (
                        event_type.name, type(target).__name__, accepted))
            except Exception:
                self._log_exception()

            # 3) JS focus as a guarantee, retried so a page that was not ready
            #    for focus at delivery time still gets the caret.
            for delay in (0, 250, 500):
                QTimer.singleShot(
                    delay, lambda js=focus_js: widget.eval_js(js))

            # Verify what ended up focused (delayed so the clicks have landed).
            QTimer.singleShot(
                400, lambda: self._log_verify_focus(widget))

            try:
                info = widget.execute_js(
                    "(()=>{"
                    "const X=%s,Y=%s;"
                    "function pick(d,x,y){"
                    "let e=d.elementFromPoint(x,y);"
                    "if(e&&e.tagName==='IFRAME'){try{const r=e.getBoundingClientRect();"
                    "const p=pick(e.contentDocument,x-r.left,y-r.top);if(p&&p.el)return p;}catch(_){}}"
                    "return {el:e,d:d,x:x,y:y};}"
                    "const p=pick(document,X,Y);const e=p.el;if(!e)return 'none';"
                    "const ce=e.isContentEditable?'ce':'notce';"
                    "const kids=e.querySelectorAll?e.querySelectorAll('input,textarea,select,[contenteditable]').length:-1;"
                    "return e.tagName+'#'+(e.id||'')+' '+ce+' kids='+kids;})()"
                    % (css_x, css_y))
                self._log("  elementFromPoint -> %s" % (info,))
            except Exception:
                self._log_exception()
            try:
                active = QApplication.activeWindow()
                self._log("  activeWindow geom=%s" %
                          (active.geometry() if active else None))
            except Exception:
                pass
        except Exception:
            self._log_exception()

    def _log_verify_focus(self, widget):
        """Log the page + Qt focus state after the click replay settles."""
        try:
            active = widget.execute_js(
                "(()=>{const e=document.activeElement;"
                "return 'hasFocus='+document.hasFocus()+"
                "' active='+((e&&e.tagName)||'none')+"
                "' id='+((e&&e.id)||'');})()")
            self._log("  VERIFY %s" % (active,))
        except Exception:
            self._log_exception()
        try:
            fw = QApplication.focusWidget()
            proxy = None
            try:
                proxy = widget.focusProxy()
            except Exception:
                pass
            self._log("  VERIFY qt-focus=%s widgetHasFocus=%s proxyHasFocus=%s frontmost=%s" % (
                type(fw).__name__ if fw else None,
                widget.hasFocus(),
                proxy.hasFocus() if proxy is not None else 'n/a',
                self.bridge.frontmost_pid() == self.eaf_pid))
        except Exception:
            pass

    def _poll_mouse_down(self):
        """Record the position/time of the left button going down (HID-wide)."""
        down = self.bridge.left_button_down()
        if down and not self._was_down:
            self._down_pos = QCursor.pos()
            self._down_time = time.monotonic()
        self._was_down = down

    @staticmethod
    def _log(message):
        print("[click-replay] " + message, flush=True)
        try:
            with open("/tmp/eaf_click_replay.log", "a") as fh:
                fh.write("[click-replay] " + message + "\n")
        except Exception:
            pass

    @staticmethod
    def _log_exception():
        import traceback
        message = traceback.format_exc()
        print(message, flush=True)
        try:
            with open("/tmp/eaf_click_replay.log", "a") as fh:
                fh.write("[click-replay] EXCEPTION: " + message + "\n")
        except Exception:
            pass

    def activate_emacs_after_mouse_release(self):
        """Return focus only if EAF is still the frontmost application."""
        if self.bridge.frontmost_pid() == self.eaf_pid:
            self.bridge.activate_application(self.emacs_pid)

    def _sample_black_view(self, view):
        """Return True if VIEW currently renders a uniform near-black frame.

        A QtWebEngine view that lost its compositor paints a single flat color
        (measured ~rgb(24,24,26) on this setup) with essentially no content
        pixels, whereas even a dark-themed page has some text/accents above
        luminance ~90.  Grab the view and count those two populations."""
        try:
            pixmap = view.grab()
            image = pixmap.toImage().convertToFormat(
                QImage.Format.Format_RGB32).scaled(
                    96, 64,
                    Qt.AspectRatioMode.IgnoreAspectRatio,
                    Qt.TransformationMode.SmoothTransformation)
            width = image.width()
            height = image.height()
            if width <= 0 or height <= 0:
                return False
            dark = 0
            lit = 0
            total = 0
            for y in range(height):
                for x in range(width):
                    color = image.pixelColor(x, y)
                    luminance = (0.299 * color.red() +
                                 0.587 * color.green() +
                                 0.114 * color.blue())
                    total += 1
                    if luminance < 48:
                        dark += 1
                    elif luminance >= 96:
                        lit += 1
            if total == 0:
                return False
            return (dark / total >= 0.985 and lit / total <= 0.006)
        except Exception:
            return False

    def _heal_black_view(self, view, state):
        """Reload the render widget of a view that went black (GUI thread).

        hide/show and resize-tickling were measured NOT to fix the black frame
        (the QtWebEngine compositor for that view is gone and only a fresh page
        rebuilds it), so skip straight to the reliable recovery: reload.  The
        buffer's own `refresh_page' path is avoided (it re-activates Windows
        windows); `buffer_widget.reload()' just reloads this page."""
        buffer = getattr(view, 'buffer', None)
        if buffer is None:
            return
        widget = getattr(buffer, 'buffer_widget', None)
        if widget is None:
            state['reloads'] = state.get('reloads', 0) + 1
            state['cooldown_until'] = time.monotonic() + 60.0
            return
        state['reloads'] = state.get('reloads', 0) + 1
        buffer_id = buffer.buffer_id
        self._log("  black-heal[%s]: reload page" % buffer_id)
        try:
            widget.reload()
        except Exception:
            self._log_exception()
        # Reload + paint needs a few seconds; back off so a page that stays
        # legitimately black is not reload-loop attacked.
        state['cooldown_until'] = time.monotonic() + 8.0

    def _watch_black_views(self):
        """Sample visible views and auto-recover any that went black."""
        frontmost = self.bridge.frontmost_pid()
        if frontmost not in (self.emacs_pid, self.eaf_pid):
            return
        now = time.monotonic()
        for view in self.views():
            try:
                buffer = getattr(view, 'buffer', None)
                if (buffer is None or not view.isVisible() or
                        not hasattr(buffer, 'buffer_id')):
                    continue
                if (self._replay_view is view and
                        now < self._replay_until):
                    continue
                buffer_id = buffer.buffer_id
                state = self._black_state.setdefault(
                    buffer_id, {'suspects': 0, 'reloads': 0,
                                'cooldown_until': 0.0, 'last': 0.0})
                widget = getattr(buffer, 'buffer_widget', None)
                # Skip while the page is loading; grabbing mid-load reads a
                # not-yet-painted frame and would false-positive (this also
                # holds right after our own recovery reload).
                try:
                    if (widget is not None and
                            getattr(widget, 'loadProgress',
                                    lambda: 100)() < 100):
                        state['suspects'] = 0
                        continue
                except Exception:
                    pass
                if now < state.get('cooldown_until', 0.0):
                    continue
                if now - state.get('last', 0.0) < self._black_check_interval:
                    continue
                state['last'] = now
                black = self._sample_black_view(view)
                if not black:
                    state['suspects'] = 0
                    if state.get('reloads', 0) != 0:
                        self._log("  black-heal[%s]: recovered" % buffer_id)
                        self._black_state.pop(buffer_id, None)
                    continue
                state['suspects'] = state.get('suspects', 0) + 1
                # Require two consecutive black samples (~4s) before healing,
                # so a transient dark frame never reloads a page.
                if state['suspects'] >= 2:
                    state['suspects'] = 0
                    # Cold start: the first frames of a freshly spawned EAF
                    # process are black because the never-active Qt app has not
                    # been given an exposure event.  Reproduce the click that
                    # normally fixes it (activate + focus, then hand focus back
                    # to Emacs) rather than reloading; reloading a page whose
                    # compositor has not started yet does not help.
                    if (time.monotonic() - self._started_at < 60.0 and
                            buffer_id not in self._wake_done):
                        self._wake_done.add(buffer_id)
                        self._wake_view(view)
                        state['cooldown_until'] = time.monotonic() + 5.0
                        continue
                    if self._black_auto_heal:
                        self._heal_black_view(view, state)
                    else:
                        # Auto-reload is disabled during root-cause work: it was
                        # found to reload-loop a view whose page loads fine but
                        # whose window compositor stays dead, destroying app
                        # sessions.  Just keep a timestamped sighting record.
                        self._log("  black-view[%s]: seen (auto-heal off)" %
                                  buffer_id)
                        state['cooldown_until'] = time.monotonic() + 30.0
            except Exception:
                self._log_exception()

    def _queue_display_link_update(self):
        """Request one coalesced GUI-thread update from the display callback."""
        with self._display_link_pending_lock:
            if self._display_link_pending:
                return
            self._display_link_pending = True
        self._display_link_frame.emit()

    @pyqtSlot()
    def _on_display_link_frame(self):
        # Keep the pending bit set while update() runs.  If the GUI thread is
        # briefly busy, CoreVideo callbacks are coalesced instead of building
        # a backlog of stale window moves.
        try:
            self.update()
        finally:
            with self._display_link_pending_lock:
                self._display_link_pending = False

    def update(self):
        """Synchronize EAF position and visibility with native macOS state."""
        self._poll_mouse_down()
        if not self._test_no_reposition:
            windows = self.bridge.emacs_windows(self.emacs_pid)
            for view in self.views():
                self._update_view_position(view, windows)
        self._update_frontmost_application()
        # Black-window watchdog, ticked from this same timer.  Use the real
        # elapsed time so the 2s cadence is independent of the timer interval.
        now = time.monotonic()
        self._black_elapsed += now - self._black_last_time
        self._black_last_time = now
        if self._black_elapsed >= self._black_check_interval:
            self._black_elapsed = 0.0
            self._watch_black_views()
