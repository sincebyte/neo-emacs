(defun doom-dashboard-widget-footer () "For empty element." (insert ""))
(setq fancy-splash-image (concat doom-user-dir "images/logo.png"))
(set-default 'truncate-lines nil   )
(setq-default with-editor-emacsclient-executable "emacsclient")

(global-set-key (kbd "<RET>" ) 'evil-ret )

(setq enable-local-variables :safe
      byte-compile-warnings '(not free-vars unresolved callargs redefine obsolete noruntime cl-functions interactive-only make-local))

(prefer-coding-system 'utf-8-unix)
(setq-default buffer-file-coding-system 'utf-8-unix)
(global-undo-tree-mode)
(add-hook 'evil-local-mode-hook 'turn-on-undo-tree-mode)

(setq gc-cons-threshold 100000000) ; Increase garbage collection threshold
(setq read-process-output-max (* 1024 1024)) ; Increase the

(map! :after evil
      :map evil-normal-state-map
      :ne "K" nil)
(map! :after evil
      :map evil-normal-state-map
      :ne "K" #'+workspace/switch-right)

(menu-bar-mode -1)
(keyfreq-mode 1)
(keyfreq-autosave-mode 1)
