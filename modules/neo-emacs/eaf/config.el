;;; $DOOMDIR/modules/neo-emacs/eaf/config.el -*- lexical-binding: t; -*-

;; Apply vendored Python patches to the straight-managed EAF source so the
;; fixes survive `doom sync' / package updates.  Patched core files live in
;; ~/.doom.d/patches/eaf/core/ (emacs-application-framework repo) and browser
;; files in ~/.doom.d/patches/eaf/browser/ (eaf-browser repo); they are copied
;; over the straight repo when they differ (e.g. right after an update reset
;; the repo).
(defun my/eaf--files-same-contents-p (a b)
  "Return non-nil if files A and B have identical contents."
  (when (and (file-exists-p a) (file-exists-p b))
    (with-temp-buffer
      (insert-file-contents a)
      (let ((content (buffer-string)))
        (with-temp-buffer
          (insert-file-contents b)
          (equal content (buffer-string)))))))

(defun my/eaf-apply-patches (&optional force)
  "Apply EAF Python patches from ~/.doom.d/patches/eaf/ to the straight repos.

Core patches live under `patches/eaf/core/' and go to the
`emacs-application-framework' repo; `eaf-browser' patches live under
`patches/eaf/browser/' and go to the separate `eaf-browser' repo."
  (let* ((local-dir (or (bound-and-true-p doom-local-dir)
                        "~/.config/emacs/.local/"))
         (patch-dir (expand-file-name
                     "patches/eaf/"
                     (or (bound-and-true-p doom-user-dir) "~/.doom.d/")))
         ;; (REPO . ((SOURCE-REL . TARGET-REL) ...))
         (targets
          `((,(expand-file-name "straight/repos/emacs-application-framework/" local-dir)
             ("eaf.py"       . "eaf.py")
             ("core/view.py"    . "core/view.py")
             ("core/webengine.py" . "core/webengine.py")
             ("core/macos.py"   . "core/macos.py")
             ("core/buffer.py"  . "core/buffer.py"))
            (,(expand-file-name "straight/repos/eaf-browser/" local-dir)
             ("browser/buffer.py" . "buffer.py")))))
    (dolist (group targets)
      (let ((repo (car group)))
        (dolist (pair (cdr group))
          (let ((source (expand-file-name (car pair) patch-dir))
                (target (expand-file-name (cdr pair) repo)))
            (when (and (file-exists-p source)
                       (or force
                           (not (my/eaf--files-same-contents-p source target))))
              (copy-file source target t)
              (message "[EAF] applied patch: %s" (car pair)))))))))
(my/eaf-apply-patches)

(use-package! eaf
  :init
  (setenv "QTWEBENGINE_CHROMIUM_FLAGS" "--no-sandbox --disable-features=WebRtcHideLocalIpsWithMdns --enable-features=PlatformHEVCDecoderSupport --enable-gpu-rasterization --ignore-gpu-blocklist --proxy-server=http://127.0.0.1:10887 --user-agent=\"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36\"")
  (setenv "QTWEBENGINE_DISABLE_SANDBOX" "1")
  (setenv "PYTHONIOENCODING" "utf-8")
  ;; A/B experiment: CoreVideo follows the real display refresh (about 60 Hz
  ;; here) instead of using an arbitrary 16 ms phase.  Change this to
  ;; "qt-timer" and restart EAF to compare against the previous behavior.
  (setenv "EAF_MACOS_TRACKER_DRIVER" "display-link")
  (setq eaf-python-command "/opt/homebrew/bin/python3"
        eaf-browser-continue-where-left-off t
        eaf-browser-enable-adblocker t
        eaf-proxy-type "http"
        eaf-proxy-host "127.0.0.1"
        eaf-proxy-port "10887"
        eaf-start-python-process-when-require nil)
  :config
  (setq browse-url-browser-function 'eaf-open-browser)
  (defalias 'browse-web #'eaf-open-browser)
  (require 'eaf-browser)
  (eaf-setq eaf-browser-default-search-engine "google")

  (setq eaf-browser-auto-import-chrome-cookies t
        eaf-browser-enable-adblocker t
        eaf-browser-enable-autofill t
        eaf-browser-dark-mode "ignore"
        eaf-chrome-bookmark-file "~/Desktop/bookmarks_2026_8_17.html"
        eaf-browser-default-zoom 1.0
        eaf-browser-enable-javascript t
        eaf-browser-enable-aria2 t
        eaf-browser-aria2-download-dir "~/Downloads/"
        eaf-browser-history-file (concat doom-data-dir "eaf/browser/history.log")
        eaf-browser-bookmark-file (concat doom-data-dir "eaf/browser/bookmarks.log")
        eaf-browser-cookie-file (concat doom-data-dir "eaf/browser/cookies"))

  (setq eaf-frame-title-format '(""))

  (eaf-bind-key history_backward "M-[" eaf-browser-keybinding)
  (eaf-bind-key history_forward "M-]" eaf-browser-keybinding)
  (eaf-bind-key history_backward "s-[" eaf-browser-keybinding)
  (eaf-bind-key history_forward "s-]" eaf-browser-keybinding)

  (eaf-bind-key +workspace/switch-left "J" eaf-browser-keybinding)
  (eaf-bind-key +workspace/switch-right "K" eaf-browser-keybinding)
  ;; (eaf-bind-key consult-buffer "B" eaf-browser-keybinding)
  (eaf-bind-key eaf-restart-process "R" eaf-browser-keybinding)
  (eaf-bind-key eaf-safe-close-buffer "Q" eaf-browser-keybinding)

  (eaf-bind-key copy_text "s-c" eaf-browser-keybinding)
  (eaf-bind-key yank_text "s-v" eaf-browser-keybinding)

  (defun eaf-consult-yank-pop ()
    "Select kill-ring entry via consult and paste into EAF."
    (interactive)
    (let ((text (with-temp-buffer
                  (consult-yank-pop)
                  (buffer-string))))
      (when (and text (not (string-empty-p text)))
        (eaf-call "send_key" "yank_text" text))))

  (eaf-bind-key eaf-consult-yank-pop "M-y" eaf-browser-keybinding)

  (setf (map-elt eaf-browser-keybinding "s-i") 'my/eaf-toggle-input-mode)
  (setf (map-elt eaf-browser-keybinding "M-i") 'my/eaf-toggle-input-mode)
  (setf (map-elt eaf-browser-keybinding "i") nil)
  (setf (map-elt eaf-browser-keybinding "f") nil)
  (setf (map-elt eaf-browser-keybinding "m") nil)
  (setf (map-elt eaf-browser-keybinding "p") nil)
  (setf (map-elt eaf-browser-keybinding "t") nil)
  (setf (map-elt eaf-browser-keybinding "x") nil)
  (setf (map-elt eaf-browser-keybinding ".") nil)
  (setf (map-elt eaf-browser-keybinding ";") nil)
  (setf (map-elt eaf-browser-keybinding "3") nil)
  (setf (map-elt eaf-browser-keybinding "C-j") nil)
  (setf (map-elt eaf-browser-keybinding "C--") nil)
  (setf (map-elt eaf-browser-keybinding "C-=") nil)
  (setf (map-elt eaf-browser-keybinding "C-0") nil)
  (setf (map-elt eaf-browser-keybinding "-") nil)
  (setf (map-elt eaf-browser-keybinding "=") nil)
  (setf (map-elt eaf-browser-keybinding "0") nil)

  (advice-add 'eaf--monitor-buffer-kill :around
              (lambda (orig-fn &rest args)
                (condition-case nil
                    (apply orig-fn args)
                  (error
                   (eaf--kill-python-process)
                   (eaf-start-process)))))

  (defun eaf-translate-text (text)
    "Translate TEXT using gt, or silently ignore if gt is unavailable."
    (if (fboundp 'gt-do-translate)
        (gt-do-translate text)
      (ignore)))

  (defun eaf-safe-close-buffer ()
    "Close current EAF browser buffer safely."
    (interactive)
    (when (derived-mode-p 'eaf-mode)
      (kill-buffer (current-buffer))))

  (map! :leader
        :desc "EAF Browser" "o b" #'eaf-open-browser
        :desc "EAF Browser (history)" "o B" #'eaf-open-browser-with-history)
  (map! :leader
        :desc "EAF open file" "o e" #'eaf-open)
  (map! :desc "EAF Bookmarks" "C-c b" #'eaf-open-bookmark))

;; On macOS EAF uses "stay on top" windows and the native `MacOSWindowTracker'
;; polls the real NSWindow bounds every few ms to keep them aligned with Emacs.
;; Emacs's own `move-frame-functions' update is debounced and, while the window
;; is being dragged, reports a *stale* frame position: it yanks the EAF window
;; back mid-drag and fights the tracker, which reads as the window trailing
;; behind the mouse.  Drop that update on macOS and let the native tracker own
;; frame translation; window splits / buffer switches still go through
;; `window-configuration-change-hook' as before.
(when (eq system-type 'darwin)
  (defun my/eaf--drop-stale-move-hook (&rest _)
    "Remove Emacs's move-driven EAF repositioning on macOS.
`eaf--schedule-monitor-configuration-change' re-adds itself to
`move-frame-functions' on every EAF start, so re-remove it afterwards."
    (remove-hook 'move-frame-functions
                 #'eaf--schedule-monitor-configuration-change))
  (with-eval-after-load 'eaf
    (my/eaf--drop-stale-move-hook)
    (unless (advice-member-p #'my/eaf--drop-stale-move-hook 'eaf-start-process)
      (advice-add 'eaf-start-process :after #'my/eaf--drop-stale-move-hook))))

(defun my/eaf-enable-proxy (&rest _)
  (ignore-errors
    (when (and (boundp 'eaf-proxy-type)
                eaf-proxy-type
                eaf-epc-process)
      (eaf-call-async "enable_proxy"))))
(advice-add 'eaf-open-browser :after #'my/eaf-enable-proxy)

;; The newer EAF calls `eaf--toggle-input-mode' via eval_in_emacs to report the
;; input-mode state, but the installed eaf.el does not define it. Provide it.
;;
;; Python encodes the state as a quoted Symbol, so it arrives here as the symbol
;; `t'/nil, NOT the string "'t".  Track it in `my/eaf-input-mode' instead of
;; `eaf-buffer-input-focus', which `eaf-update-focus-state' owns and which means
;; "the page has a focused input element" (a different concept entirely).
(defvar-local my/eaf-input-mode nil
  "Non-nil when this EAF buffer's input mode is enabled.")

(defun eaf--toggle-input-mode (buffer-id &optional state)
  "Record EAF input-mode STATE for BUFFER-ID."
  (ignore-errors
    (let ((buf (eaf-get-buffer buffer-id)))
      (when buf
        (with-current-buffer buf
          (setq-local my/eaf-input-mode (equal state t)))))))

(defun my/eaf-rime-on-input-mode (_buffer-id state)
  "Switch to Rime (Chinese) input when EAF enters input mode."
  (when (eq state t)
    (my/mac-switch-to-rime)))
(advice-add 'eaf--toggle-input-mode :after #'my/eaf-rime-on-input-mode)

(defun my/eaf-auto-input-mode (&rest _)
  "Auto-enter input mode when EAF browser opens."
  (ignore-errors
    (when (and (boundp 'eaf-epc-process) eaf-epc-process)
      (let ((buffer-id eaf--buffer-id))
        (run-at-time 0.5 nil
                     (lambda ()
                       (eaf-call-async "eval_function" buffer-id "switch_to_input_mode" "t")))))))
(advice-add 'eaf-open-browser :after #'my/eaf-auto-input-mode)

(defun my/eaf-toggle-input-mode ()
  "Enable EAF input mode for the current buffer (idempotent).

The event string \"t\" makes `switch_to_input_mode' enable input mode without
toggling it back off, so a single press always hands keyboard focus to the Qt
browser.  On macOS the newer EAF activates the EAF (Qt) application when
enabling and re-activates Emacs when disabling (or when Emacs regains focus)."
  (interactive)
  (when (derived-mode-p 'eaf-mode)
    (my/eaf-enable-input-mode eaf--buffer-id)))

(defun my/eaf-enable-input-mode (buffer-id)
  "Force input mode ON for BUFFER-ID unless it is already enabled."
  (let ((buffer (eaf-get-buffer buffer-id)))
    (when (and buffer
               (with-current-buffer buffer (derived-mode-p 'eaf-mode))
               (not (buffer-local-value 'my/eaf-input-mode buffer)))
      (eaf-call-async "eval_function" buffer-id "switch_to_input_mode" "t"))))

(defun my/eaf-clicked-buffer-id ()
  "Return the EAF buffer id of the window under the mouse pointer, or nil.

Called by the EAF macOS window tracker right after focus returns to Emacs.
The mouse is still at the click point, so the window physically under it is the
one the user clicked back into -- this does not depend on window selection.
Falls back to the selected window.  Returns nil when neither is an EAF buffer."
  (let* ((mouse-pos (mouse-position))
         (frame (car mouse-pos))
         (x (cadr mouse-pos))
         (y (cddr mouse-pos))
         (window (and (framep frame) (integerp x) (integerp y)
                      (window-at x y frame))))
    (unless window
      (setq window (selected-window)))
    (when window
      (let ((buf (window-buffer window)))
        (when (eq (buffer-local-value 'major-mode buf) 'eaf-mode)
          (buffer-local-value 'eaf--buffer-id buf))))))

(defun my/eaf-on-input-mode-enabled (buffer-id &optional state)
  "Trigger `my/eaf-toggle-input-mode' when the browser reports input mode
enabled -- via keybinding, mouse click, or any other trigger.

`eaf--toggle-input-mode' is the single report point for every input-mode
change, so this also fires when a mouse click enables the browser directly
in Python.  `my/eaf-toggle-input-mode' is idempotent (it no-ops when
`my/eaf-input-mode' is already set), so the re-report produced by our own
\"t\" command is a no-op and cannot recurse."
  (when (equal state t)
    (let ((buffer (eaf-get-buffer buffer-id)))
      (when buffer
        (with-current-buffer buffer
          (my/eaf-toggle-input-mode))))))
(advice-add 'eaf--toggle-input-mode :after #'my/eaf-on-input-mode-enabled)

;;; Fix EAF content shifting right / white right edge on focus loss (macOS)
;;;
;;; EAF positions its Qt widget at `window-pixel-edges' (the window's TOTAL edge,
;;; which includes the left fringe). On focus loss EAF hides the widget and shows
;;; a screenshot via `insert-image'. Two Emacs 31 quirks then apply:
;;;
;;; 1) With wrapping enabled (`truncate-lines' nil) the display engine reserves
;;;    one character column and clamps the image to body-width-10, leaving a
;;;    white vertical strip on the right edge of the placeholder.
;;; 2) A full-width image leaves point at the right edge, so auto-hscroll shifts
;;;    the content ~30px left.
;;;
;;; Fix: zero-width fringes (placeholder aligns with the widget, no shift),
;;; `truncate-lines t' (image fills the full width, no white strip), and pin
;;; point to the image start after display (no auto-hscroll).

(add-hook 'eaf-mode-hook
          (lambda ()
            (setq-local left-fringe-width 0)
            (setq-local right-fringe-width 0)
            (setq-local truncate-lines t)
            (face-remap-add-relative 'default :background "#000000")
            (let ((win (get-buffer-window (current-buffer) 0)))
              (when win
                (set-window-fringes win 0 0)))))

;; `eaf-mode' sets `cursor-type' to nil, but Evil re-applies its state cursor
;; (a `box' for normal state) on every state change / cursor refresh.  The
;; frame's `cursor-color' is near-white (#efeff1) and
;; `cursor-in-non-selected-windows' is nil, so only the *selected* EAF window
;; draws it: a white block in the corner that reads as a white frame over the
;; Qt view.  Force the cursor off in EAF buffers no matter what Evil wants.
(defun my/eaf--suppress-evil-cursor (orig &optional state buffer)
  "Keep EAF buffers cursor-less when Evil refreshes its cursor."
  (with-current-buffer (or buffer (current-buffer))
    (if (derived-mode-p 'eaf-mode)
        (setq cursor-type nil)
      (funcall orig state buffer))))
(after! evil
  (advice-add 'evil-refresh-cursor :around #'my/eaf--suppress-evil-cursor))

;; `eaf--display-image' leaves point after the full-width screenshot, which
;; triggers auto-hscroll and shifts the content. Pin point to the image start.
(advice-add 'eaf--display-image :after
            (lambda (&rest _)
              (when (derived-mode-p 'eaf-mode)
                (goto-char (point-min)))))

;; Cold-start (e.g. Emacs startup) drops every `eaf-open' call after the first:
;; `eaf-open' only queues the first URL into `eaf--first-start-app-buffers'
;; before the EPC process is live, and the rest are silently discarded.  Wait
;; until the process is ready, then open the URL in the other window (which
;; also does the right split).
(defun my/eaf-open-browser-other-window-when-ready (url)
  "Open URL in the other window once the EAF process is ready.

Split left:right at 7:3 (current window takes 70%, the new one 30%)."
  (if (and (boundp 'eaf-epc-process) (eaf-epc-live-p eaf-epc-process))
      (let ((right-width (round (* 0.7 (window-total-width)))))
        (split-window-right right-width)
        (other-window 1)
        (eaf-open-browser url))
    (run-with-idle-timer 0.5 nil #'my/eaf-open-browser-other-window-when-ready url)))

;;; Coalesce EAF geometry updates around workspace switches (fixes the
;;; "page redraws / DOM jumps after switching back to the EAF workspace"
;;; flicker).
;;;
;;; Two layers are involved:
;;;
;;; 1) Python side (patches/eaf/eaf.py): `update_views' only resizes a
;;;    non-fit_to_view buffer (the browser) when that buffer has a surviving
;;;    view in the new layout.  Previously it resized hidden buffers to a
;;;    stale `emacs_width/emacs_height' and re-queried Emacs for the buffer's
;;;    window size (`resize_view'), which during a workspace window restore
;;;    returns a foreign/transient size -- so the live page re-laid-out to a
;;;    bogus geometry while invisible, then re-laid-out again (visibly) to the
;;;    correct size on switch back.
;;; 2) Emacs side (below): defer ALL geometry updates between
;;;    `persp-before-switch-functions' and `persp-activated-functions' (while
;;;    the synchronous window-state restore is in flight), then run exactly
;;;    ONE authoritative update once the switch has settled.  The 0.08s
;;;    debounce cannot merge the restore's intermediate
;;;    `window-configuration-change-hook' firings on its own, so without this
;;;    the final geometry gets pushed mid-restore with transient values.
(defvar my/eaf--ws-defer-p nil
  "Non-nil while a persp workspace switch is being restored.")
(defvar my/eaf--ws-defer-start nil
  "Timestamp when deferral started, so a stuck defer heals itself.")

(defun my/eaf--ws-switch-before (&rest _)
  "Defer EAF geometry updates until the switch's window config settles."
  (setq my/eaf--ws-defer-p t
        my/eaf--ws-defer-start (current-time)))

(defun my/eaf--ws-switch-after (&rest _)
  "Re-enable EAF geometry updates and force one final authoritative layout."
  (setq my/eaf--ws-defer-p nil
        my/eaf--ws-defer-start nil)
  (when (and (boundp 'eaf-epc-process) (eaf-epc-live-p eaf-epc-process))
    ;; Small delay so any deferred redisplay settles; the result is the one
    ;; and only viewport resize the page sees after the switch.
    (run-with-timer 0.05 nil #'eaf--monitor-configuration-change-now)))

(defun my/eaf--ws-skip-during-switch-a (orig-fn &rest args)
  "Skip EAF geometry updates while a workspace switch is being restored.

Also acts as a watchdog: if the deferral has been active for more than
2 seconds (e.g. an odd switch path that never fired the after-hook), clear
it and let the update through -- the tree has long since settled by then."
  (unless (and my/eaf--ws-defer-p
               my/eaf--ws-defer-start
               (time-less-p (current-time)
                            (time-add my/eaf--ws-defer-start 2)))
    (setq my/eaf--ws-defer-p nil)
    (apply orig-fn args)))

(advice-add 'eaf--monitor-configuration-change-now :around
            #'my/eaf--ws-skip-during-switch-a)

(with-eval-after-load 'persp-mode
  (add-hook 'persp-before-switch-functions #'my/eaf--ws-switch-before)
  (add-hook 'persp-activated-functions #'my/eaf--ws-switch-after))
