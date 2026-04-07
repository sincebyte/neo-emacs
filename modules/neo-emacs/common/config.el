(defun doom-dashboard-widget-footer () "For empty element." (insert ""))
(setq fancy-splash-image (concat doom-user-dir "images/logo.png"))
(set-default 'truncate-lines nil   )
(setq-default with-editor-emacsclient-executable "emacsclient")

(global-set-key (kbd "<RET>" ) 'evil-ret )

(setq enable-local-variables :safe
      byte-compile-warnings '(not free-vars unresolved callargs redefine obsolete noruntime cl-functions interactive-only make-local))

(prefer-coding-system 'utf-8-unix)
(setq-default buffer-file-coding-system 'utf-8-unix)
;; (global-undo-tree-mode)
;; (add-hook 'evil-local-mode-hook 'turn-on-undo-tree-mode)
(setq undo-tree-auto-save-history nil)

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

(defun copy-buffer-file-name ()
  "Copy current buffer's file name with line number(s) to kill-ring.
  In normal mode: copies filename:line
  In visual mode: copies filename:start,end"
  (interactive)
  (when (buffer-file-name)
    (let ((filename (file-name-nondirectory (buffer-file-name)))
          (start-line (line-number-at-pos (if (region-active-p) (region-beginning) (point))))
          (end-line (and (region-active-p) (line-number-at-pos (region-end)))))
      (if (and (region-active-p) end-line (> end-line start-line))
          (kill-new (format "%s:%d,%d" filename start-line end-line))
        (kill-new (format "%s:%d" filename start-line)))
      (message "Copied: %s" 
               (if (and (region-active-p) end-line (> end-line start-line))
                   (format "%s:%d,%d" filename start-line end-line)
                 (format "%s:%d" filename start-line))))))
