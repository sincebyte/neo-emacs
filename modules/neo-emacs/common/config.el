(defun doom-dashboard-widget-footer () "For empty element." (insert ""))
(setq fancy-splash-image (concat doom-user-dir "logo.png"))
(set-default 'truncate-lines nil   )
(setq-default with-editor-emacsclient-executable "emacsclient")

(global-set-key (kbd "<RET>" ) 'evil-ret )

(setq enable-local-variables :safe
      byte-compile-warnings '(not free-vars unresolved callargs redefine obsolete noruntime cl-functions interactive-only make-local))

(prefer-coding-system 'utf-8-unix)
(setq-default buffer-file-coding-system 'utf-8-unix)

(menu-bar-mode -1)
(keyfreq-mode 1)
(keyfreq-autosave-mode 1)
