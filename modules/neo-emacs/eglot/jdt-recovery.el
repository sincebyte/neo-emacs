;;; jdt-recovery.el --- Recover corrupt JDT workspaces -*- lexical-binding: t; -*-

(require 'eglot)
(require 'cl-lib)

(defvar +eglot-java-recovery-attempts (make-hash-table :test #'equal)
  "Workspaces already recovered during this Emacs session.
Keep the limit even after a successful connection to prevent crash loops.")

(defun +eglot-java-recovery--metadata (output)
  "Return corrupt cache metadata reported in OUTPUT, or nil.
Only inspect the last Eclipse session and only accept local JDT caches."
  (let (log)
    (with-temp-buffer
      (insert output)
      (goto-char (point-min))
      (while (re-search-forward "^\\(/[^\n\r]+/\\.metadata/\\.log\\)\\.?\r?$" nil t)
        (setq log (match-string-no-properties 1))))
    (when (and log (file-readable-p log) (not (file-remote-p log)))
      (let* ((metadata (directory-file-name (file-name-directory log)))
             (workspace (file-name-directory metadata))
             (cache (expand-file-name
                     (if (eq system-type 'darwin)
                         "~/Library/Caches/jdtls/" "~/.cache/jdtls/"))))
        (when (and (file-in-directory-p (file-truename log) cache)
                   (string-prefix-p "jdtls-" (file-name-nondirectory
                                              (directory-file-name workspace)))
                   (not (file-symlink-p metadata)))
          (with-temp-buffer
            ;; Eclipse logs grow across launches; bound IO on the sentinel path.
            (let ((size (file-attribute-size (file-attributes log))))
              (insert-file-contents log nil (max 0 (- size (* 256 1024)))))
            (goto-char (point-max))
            (when (re-search-backward "^!SESSION " nil t)
              (narrow-to-region (point) (point-max))
              (goto-char (point-min))
              (when (and (search-forward "org.eclipse.core.internal.dtree.ObjectNotFoundException" nil t)
                         (progn (goto-char (point-min))
                                (search-forward "org.eclipse.core.internal.resources.SaveManager.restore" nil t)))
                metadata))))))))

(defun +eglot-java-recovery--restart (server metadata)
  "Back up METADATA and reconnect SERVER after its sentinel has finished."
  (condition-case err
      (unless (or (jsonrpc-running-p server)
                  (cl-some #'jsonrpc-running-p
                           (gethash (eglot--project server) eglot--servers-by-project)))
        (let ((backup (make-temp-name (concat metadata ".bak-"))))
          (rename-file metadata backup)
          (message "[eglot] JDT 缓存损坏，已备份至 %s；自动重启一次…" backup)
          (let ((default-directory (project-root (eglot--project server)))
                (eglot-sync-connect nil))
            (eglot-reconnect server))))
    (error (message "[eglot] JDT 自动恢复失败，停止重试：%s" (error-message-string err)))))

(defun +eglot-java-recovery--on-shutdown (original server)
  "Run ORIGINAL cleanup and schedule one recovery for corrupt JDT SERVER."
  (let ((metadata
         (condition-case err
             (when (and (not (eglot--shutdown-requested server))
                        (or (assoc 'java-mode (eglot--languages server))
                            (assoc 'java-ts-mode (eglot--languages server))))
               (let* ((process (jsonrpc--process server))
                      (buffer (process-buffer process)))
                 (when (and (not (process-live-p process))
                            (= (process-exit-status process) 13)
                            (buffer-live-p buffer))
                   (+eglot-java-recovery--metadata
                    (with-current-buffer buffer
                      (buffer-substring-no-properties (point-min) (point-max)))))))
           (error (message "[eglot] 无法检查 JDT 缓存：%s" (error-message-string err))
                  nil))))
    (when metadata
      ;; Prevent Eglot's own reconnect racing the delayed recovery.
      (when (timerp (eglot--inhibit-autoreconnect server))
        (cancel-timer (eglot--inhibit-autoreconnect server)))
      (setf (eglot--inhibit-autoreconnect server) t))
    (unwind-protect
        (funcall original server)
      (when metadata
        (if (gethash metadata +eglot-java-recovery-attempts)
            (message "[eglot] JDT 缓存恢复已尝试过，停止自动重试：%s" metadata)
          (puthash metadata t +eglot-java-recovery-attempts)
          (run-at-time 0 nil #'+eglot-java-recovery--restart server metadata))))))

(advice-add 'eglot--on-shutdown :around #'+eglot-java-recovery--on-shutdown)

(provide 'jdt-recovery)
;;; jdt-recovery.el ends here
