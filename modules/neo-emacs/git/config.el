(use-package! magit-delta
  :hook (magit-mode . magit-delta-mode))

(after! magit
  (setq magit-display-buffer-function
        #'magit-display-buffer-same-window-except-diff-v1))

;; (after! persp-mode
;;   (persp-def-buffer-save/load
;;    :tag-symbol 'def-indirect-buffer
;;    :predicate #'buffer-base-buffer
;;    :save-function (lambda (buf tag vars)
;;                     (list tag (buffer-name buf) vars
;;                           (buffer-name (buffer-base-buffer buf))))
;;    :load-function (lambda (savelist &rest _rest)
;;                     (cl-destructuring-bind (buf-name _vars base-buf-name &rest _)
;;                         (cdr savelist)
;;                       (push (cons buf-name base-buf-name)
;;                             +workspaces--indirect-buffers-to-restore)
;;                       nil))))
