;;; window-management.el --- Custom window management with popwin -*- lexical-binding: t; -*-

;; Store original window configuration for restoration
(defvar popwin-window-layout--original-config nil
  "Stores the original window configuration before closing other windows.")

(defvar popwin-window-layout--is-toggled nil
  "Flag indicating whether windows have been toggled to single view.")

(defvar popwin-window-layout--last-selected-window nil
  "Keep track of the last selected window before toggling.")

(defun popwin-window-layout-toggle-all-windows ()
  "Toggle between normal window layout and single window (all other closed).
   When switching to single window, stores the current window configuration.
   When switching back, restores the stored configuration."
  (interactive)
  (if popwin-window-layout--is-toggled
      ;; Restore original layout
      (progn
        (when popwin-window-layout--original-config
          (set-window-configuration popwin-window-layout--original-config)
          (setq popwin-window-layout--original-config nil))
        (setq popwin-window-layout--is-toggled nil)
        (setq popwin-window-layout--last-selected-window nil)
        (message "Restored original window layout"))
    ;; Store current layout and go to single window
    (progn
      (setq popwin-window-layout--original-config (current-window-configuration))
      (setq popwin-window-layout--last-selected-window (selected-window))
      (delete-other-windows)
      (setq popwin-window-layout--is-toggled t)
      (message "Closed other windows, press again to restore"))))

(defun popwin-window-layout-open-right (buffer-name &optional width)
  "Open BUFFER-NAME in a popup window on the right side of the frame.
WIDTH is the width of the popup window (default 60 chars)."
  (interactive "BBuffer name: \nnWidth (default 60): ")
  (let ((buffer (get-buffer-create buffer-name))
        (actual-width (or width 60)))
    (popwin:popup-buffer buffer
                 :width actual-width
                 :position 'right
                 :noselect nil)))

(defun popwin-window-layout-open-right-noselect (buffer-name &optional width)
  "Open BUFFER-NAME in a popup window on the right side without selecting it.
WIDTH is the width of the popup window (default 60 chars)."
  (interactive "BBuffer name: \nnWidth (default 60): ")
  (let ((buffer (get-buffer-create buffer-name))
        (actual-width (or width 60)))
    (popwin:popup-buffer buffer
                 :width actual-width
                 :position 'right
                 :noselect t)))

(defun popwin-window-layout-toggle-window-dedicated ()
  "Toggle dedication of the selected window (make it dedicated/not dedicated)"
  (interactive)
  (let ((current-win (selected-window)))
    (set-window-dedicated-p current-win (not (window-dedicated-p current-win)))
    (message "Window dedication %s" (if (window-dedicated-p current-win) "enabled" "disabled"))))

(defun popwin-window-layout-open-messages-right ()
  "Open *Messages* buffer in a popup window on the right side."
  (interactive)
  (popwin-window-layout-open-right "*Messages*" 0.3))

(defun popwin-window-layout-open-help-right ()
  "Open *Help* buffer in a popup window on the right side."
  (interactive)
  (let ((help-buffer (get-buffer-create "*Help*")))
    (popwin-window-layout-open-right (buffer-name help-buffer) 0.4)))

(defun popwin-window-layout-open-compilation-right ()
  "Open *Compilation* buffer in a popup window on the right side."
  (interactive)
  (popwin-window-layout-open-right "*Compilation*" 0.4))

(defun popwin-window-layout-kill-buffer-and-close-window ()
  "Kill current buffer and close its window if it's a popup window."
  (interactive)
  (let ((current-buf (current-buffer))
        (current-win (selected-window)))
    (if (and (window-parameter current-win 'window-side)
             (eq (window-parameter current-win 'window-side) 'right))
        ;; If it's a right-side popup, close popup and kill buffer
        (progn
          (popwin:close-popup-window)
          (kill-buffer current-buf))
      ;; Otherwise just kill buffer normally
      (kill-buffer current-buf))))

;; Set up popwin with right-side default for certain buffers
(after! popwin
  ;; Configure popwin to open certain buffers on the right side
  (push '("*Messages*" :width 0.3 :position right)
        popwin:special-display-config)
  (push '("*Help*" :width 0.4 :position right)
        popwin:special-display-config)
  (push '(compilation-mode :width 0.4 :position right :noselect t)
        popwin:special-display-config)
  (push '(occur-mode :width 0.4 :position right :noselect t)
        popwin:special-display-config)
  
  ;; Enable popwin mode
  (popwin-mode 1))
  
  ;; Set default position to right for popwin
  (setq popwin:popup-window-position 'right)
  (setq popwin:popup-window-width 60)
