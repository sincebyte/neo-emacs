;;; neoemacs/alpha/config.el -*- lexical-binding: t; -*-

;;set the alpha background
(setq-default alpha-list '((99 100) (100 100)))
(defun loop-alpha ()
  ;;doc
  (interactive)
  (let ((h (car alpha-list)))
    ((lambda (a ab)
       (set-frame-parameter (selected-frame) 'alpha (list a ab))
       (add-to-list 'default-frame-alist (cons 'alpha (list a ab)))
       ) (car h) (car (cdr h)))
    (setq alpha-list (cdr (append alpha-list (list h))))
    )
)
(loop-alpha)
;; (setq default-frame-alist '((alpha-background . 80)))

(setq frame-title-format nil)
