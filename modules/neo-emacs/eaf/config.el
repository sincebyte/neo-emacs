;;; $DOOMDIR/modules/neo-emacs/eaf/config.el -*- lexical-binding: t; -*-

(use-package! eaf
  :init
  (setenv "QTWEBENGINE_CHROMIUM_FLAGS" "--no-sandbox --disable-features=WebRtcHideLocalIpsWithMdns --enable-features=PlatformHEVCDecoderSupport --enable-gpu-rasterization --ignore-gpu-blocklist --proxy-server=http://127.0.0.1:10887 --user-agent=\"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36\"")
  (setenv "QTWEBENGINE_DISABLE_SANDBOX" "1")
  (setenv "PYTHONIOENCODING" "utf-8")
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

  (eaf-bind-key history_backward "M-[" eaf-browser-keybinding)
  (eaf-bind-key history_forward "M-]" eaf-browser-keybinding)

  (eaf-bind-key +workspace/switch-left "J" eaf-browser-keybinding)
  (eaf-bind-key +workspace/switch-right "K" eaf-browser-keybinding)
  (eaf-bind-key consult-buffer "B" eaf-browser-keybinding)
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

  (eaf-bind-key switch_to_input_mode "M-i" eaf-browser-keybinding)
  (setf (map-elt eaf-browser-keybinding "s-i") 'my/eaf-toggle-input-mode)
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

(defun my/eaf-enable-proxy (&rest _)
  (ignore-errors
    (when (and (boundp 'eaf-proxy-type)
                eaf-proxy-type
                eaf-epc-process)
      (eaf-call-async "toggle_proxy"))))
(advice-add 'eaf-open-browser :after #'my/eaf-enable-proxy)

;; The newer EAF calls `eaf--toggle-input-mode' via eval_in_emacs to report the
;; input-mode state, but the installed eaf.el does not define it. Provide it.
(defun eaf--toggle-input-mode (buffer-id &optional state)
  "Record EAF input-mode STATE for BUFFER-ID."
  (ignore-errors
    (let ((buf (eaf-get-buffer buffer-id)))
      (when buf
        (with-current-buffer buf
          (setq-local eaf-buffer-input-focus (equal state "'t")))))))

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
  "Enable EAF input mode (idempotent).

The event string \"t\" makes `switch_to_input_mode' enable input mode without
toggling it back off, so a single press always hands keyboard focus to the Qt
browser.  On macOS the newer EAF activates the EAF (Qt) application when
enabling and re-activates Emacs when disabling (or when Emacs regains focus)."
  (interactive)
  (when (derived-mode-p 'eaf-mode)
    (message "my/eaf-toggle-input-mode: sending switch_to_input_mode t")
    (eaf-call-async "eval_function" eaf--buffer-id "switch_to_input_mode" "t")))

;;; Fix EAF content shifting right when Emacs loses focus (macOS)
;;;
;;; Root cause: EAF positions its Qt widget at `window-pixel-edges' (the window's
;;; TOTAL edge, which includes the left fringe). But when focus is lost, EAF hides
;;; the widget and shows a screenshot via `insert-image', which lands in the TEXT
;;; AREA (after the left fringe). The screenshot is therefore offset right by the
;;; fringe width (~8px), matching the observed 5-15px jump.
;;;
;;; Fix: Give EAF buffers zero-width fringes so the text area (where the
;;; screenshot is drawn) coincides with the widget position.

(add-hook 'eaf-mode-hook
          (lambda ()
            (setq-local left-fringe-width 0)
            (setq-local right-fringe-width 0)
            (let ((win (get-buffer-window (current-buffer) 0)))
              (when win
                (set-window-fringes win 0 0)))))
