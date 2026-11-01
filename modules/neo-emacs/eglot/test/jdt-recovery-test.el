;;; jdt-recovery-test.el --- Recovery regression tests -*- lexical-binding: t; -*-
(require 'ert)
(require 'jdt-recovery)

(ert-deftest jdt-recovery-latest-session-only ()
  (let* ((root (make-temp-file "jdt-recovery-" t))
         (metadata (expand-file-name "jdtls-test/.metadata" root))
         (log (expand-file-name ".log" metadata))
         (output (concat log ".\n")))
    (unwind-protect
        (progn
          (make-directory metadata t)
          (with-temp-file log
            (insert "!SESSION old\norg.eclipse.core.internal.dtree.ObjectNotFoundException\n"
                    "org.eclipse.core.internal.resources.SaveManager.restore\n"))
          ;; Simulate the allowed cache root without touching real caches.
          (cl-letf (((symbol-function 'file-in-directory-p) (lambda (&rest _) t)))
            (should (equal metadata (+eglot-java-recovery--metadata output)))
            (with-temp-buffer
              (insert "!SESSION new\nUnrelated JVM failure\n")
              (write-region (point-min) (point-max) log t 'silent))
            (should-not (+eglot-java-recovery--metadata output))))
      (delete-directory root t))))

(ert-deftest jdt-recovery-backup-preserves-content ()
  (let* ((root (make-temp-file "jdt-recovery-" t))
         (metadata (expand-file-name ".metadata" root))
         (eglot--servers-by-project (make-hash-table :test #'equal))
         reconnected)
    (unwind-protect
        (progn
          (make-directory metadata)
          (with-temp-file (expand-file-name ".log" metadata) (insert "evidence"))
          (cl-letf (((symbol-function 'jsonrpc-running-p) (lambda (_) nil))
                    ((symbol-function 'eglot--project) (lambda (_) (cons 'transient root)))
                    ((symbol-function 'eglot-reconnect) (lambda (_) (setq reconnected t))))
            (+eglot-java-recovery--restart 'server metadata))
          (should reconnected)
          (should-not (file-exists-p metadata))
          (let ((backup (car (directory-files root t "^\\.metadata\\.bak-"))))
            (should backup)
            (with-temp-buffer
              (insert-file-contents (expand-file-name ".log" backup))
              (should (equal (buffer-string) "evidence")))))
      (delete-directory root t))))

(ert-deftest jdt-recovery-ignores-path-outside-cache ()
  (let* ((root (make-temp-file "jdt-recovery-" t))
         (metadata (expand-file-name "jdtls-test/.metadata" root))
         (log (expand-file-name ".log" metadata)))
    (unwind-protect
        (progn
          (make-directory metadata t)
          (with-temp-file log
            (insert "!SESSION test\norg.eclipse.core.internal.dtree.ObjectNotFoundException\n"
                    "org.eclipse.core.internal.resources.SaveManager.restore\n"))
          (should-not (+eglot-java-recovery--metadata (concat log ".\n"))))
      (delete-directory root t))))
