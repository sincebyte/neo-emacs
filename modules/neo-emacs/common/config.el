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

(defvar toggle-one-window-window-configuration nil
  "The window configuration use for `toggle-one-window'.")
(defun toggle-one-window ()
  "Toggle between window layout and one window, keeping cursor in the restored window."
  (interactive)
  (if (equal (length (cl-remove-if #'window-dedicated-p (window-list))) 1)
      (if toggle-one-window-window-configuration
          (let ((current-window (selected-window)))
            ;; 恢复窗口配置
            (set-window-configuration toggle-one-window-window-configuration)
            ;; 清空配置变量
            (setq toggle-one-window-window-configuration nil)
            ;; 如果当前窗口和之前保存的是同一个，则切换到另一个窗口
            (when (eq (selected-window) current-window)
              (other-window 1)))
        (message "No other windows exist."))
    ;; 保存当前窗口配置
    (setq toggle-one-window-window-configuration (current-window-configuration))
    ;; 删除其他窗口
    (delete-other-windows)))

(defun copy-buffer-file-name ()
  "Copy current buffer's file name (without path) to kill-ring."
  (interactive)
  (when (buffer-file-name)
    (kill-new (file-name-nondirectory (buffer-file-name)))
    (message "Copied: %s" (file-name-nondirectory (buffer-file-name)))))
