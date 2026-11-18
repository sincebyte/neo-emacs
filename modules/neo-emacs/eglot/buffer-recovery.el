;;; buffer-recovery.el -*- lexical-binding: t; -*-

(require 'eglot)

(defvar-local +eglot-buffer-recovery--timer nil)

(defun +eglot-buffer-recovery--repair ()
  "补接当前文件的存活服务器，并恢复丢失的补全入口。
不冷启动服务器；没有配置 LSP 的文件仍使用原来的补全。"
  (when (and buffer-file-name
             (not (minibufferp)))
    (when-let* ((server (eglot-current-server))
                (_ (jsonrpc-running-p server)))
      (unless (eglot-managed-p)
        (eglot--maybe-activate-editing-mode))
      (when (eglot-managed-p)
        (unless (memq #'eglot-completion-at-point completion-at-point-functions)
          (add-hook 'completion-at-point-functions #'eglot-completion-at-point nil t))
        ;; 尊重 Corfu 的全局开关及模式筛选，不覆盖 buffer 的自动补全偏好。
        (when (and (bound-and-true-p global-corfu-mode)
                   (not (bound-and-true-p corfu-mode))
                   (fboundp 'global-corfu-mode-enable-in-buffer))
          (global-corfu-mode-enable-in-buffer))
        t))))

(defun +eglot-buffer-recovery--run (buffer)
  "在 BUFFER 仍然存活时执行一次修复。"
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq +eglot-buffer-recovery--timer nil)
      (condition-case err
          (+eglot-buffer-recovery--repair)
        (error (message "[eglot] buffer 补全检查失败 (%s): %s"
                        (buffer-name) (error-message-string err)))))))

(defun +eglot-buffer-recovery--schedule ()
  "等当前初始化钩子结束后检查文件，合并重复触发。"
  (when (and buffer-file-name
             (not (timerp +eglot-buffer-recovery--timer)))
    (setq +eglot-buffer-recovery--timer
          (run-with-idle-timer 0.2 nil #'+eglot-buffer-recovery--run
                               (current-buffer)))))

(defun +eglot-buffer-recovery--window-change (frame)
  "检查 FRAME 上切换后可见的文件。"
  (dolist (window (window-list frame 'no-minibuffer))
    (with-current-buffer (window-buffer window)
      (+eglot-buffer-recovery--schedule))))

(defun +eglot-repair-buffer ()
  "修复当前文件的 Eglot 接管及补全入口，无需关闭 buffer。"
  (interactive)
  (if (+eglot-buffer-recovery--repair)
      (progn
        (when (fboundp 'eglot--capf-session-flush)
          (eglot--capf-session-flush))
        (message "[eglot] 当前 buffer 已接管，补全入口已恢复"))
    (user-error "当前文件没有可用的 Eglot 连接；请先检查 M-x eglot")))

(add-hook 'find-file-hook #'+eglot-buffer-recovery--schedule 90)
(add-hook 'after-change-major-mode-hook #'+eglot-buffer-recovery--schedule 90)
(add-hook 'eglot-managed-mode-hook #'+eglot-buffer-recovery--schedule 90)
(add-hook 'window-buffer-change-functions #'+eglot-buffer-recovery--window-change)

(provide 'eglot-buffer-recovery)
;;; buffer-recovery.el ends here
