(defun doom-dashboard-widget-footer () "For empty element." (insert ""))
(setq fancy-splash-image (concat doom-user-dir "logo.png"))
(set-default 'truncate-lines nil   )

;; use `SPC o n` for open node on operate system
(defun neo/opendir ()
  (interactive)
  (shell-command (concat "open " (shell-command-to-string "pwd"))))
(map! :n "SPC o n" 'neo/opendir)
