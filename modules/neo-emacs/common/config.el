(defun doom-dashboard-widget-footer () "For empty element." (insert ""))
(setq fancy-splash-image (concat doom-user-dir "logo.png"))
(set-default 'truncate-lines nil   )
(setq-default with-editor-emacsclient-executable "emacsclient")

(global-set-key (kbd "<RET>" ) 'evil-ret )

(menu-bar-mode -1)
(keyfreq-mode 1)
(keyfreq-autosave-mode 1)
