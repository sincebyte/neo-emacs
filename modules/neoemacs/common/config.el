;;; neoemacs/common/config.el -*- lexical-binding: t; -*-
(blink-cursor-mode   0             )
(tool-bar-mode       0             )
(menu-bar-mode       0             )
(scroll-bar-mode     0             )
(yas-global-mode     1             )
(set-default 'truncate-lines nil   )
(setq-default treemacs-width 175   )
(setq-default indent-tabs-mode nil )

(custom-set-variables '(x-select-enable-clipboard t))

(after! warnings (add-to-list 'warning-suppress-types '(yasnippet backquote-change tree-sitter org org-loaddefs)))
(setq byte-compile-warnings '(cl-functions)
      frame-title-format    '(" ")
      display-time-default-load-average nil)

;;; doom welcome
(defun doom-dashboard-widget-banner ()
  "For neoemacs ascii logo."
 (let ((point (point)))
   (mapc (lambda (line)
           (insert (propertize (+doom-dashboard--center +doom-dashboard--width line)
                               'face 'doom-dashboard-banner) " ")
           (insert "\n"))
  '("|¯¯\\|¯¯|/¯x¯¯\\ /¯¯¯¯¯\\ /¯x¯¯\\|¯¯\\/¯¯¯| /¯¯¯¯|/¯¯¯¯\\ /¯¯¯¯¯/ "
    "|     '| (\\__/|| x   || (\\__/|      '|/    !||(\\__/|\\ __¯¯¯\\"
    "|__|\\__|\\____\\ \\_____/ \\____\\|._|\\/||/__/¯|_|\\____\\ /______/"
    "                                                         v1.3.1      "
    "                                                                     "))))
(defun doom-dashboard-widget-footer () "For empty element." (insert ""))

;; gc setting
(defmacro k-time (&rest body) `(let ((time (current-time))) ,@body (float-time (time-since time))))
(defvar k-gc-timer (run-with-idle-timer 15 t 'garbage-collect  ))
(remove-hook 'doom-first-buffer-hook #'global-hl-line-mode)

;; about scroll bars setting
(defun my/disable-scroll-bars (frame)
  (modify-frame-parameters frame
                           '((vertical-scroll-bars . nil)
                             (horizontal-scroll-bars . nil))))
(defun popup-handler (app-name window-title x y w h)
  (set-frame-position (selected-frame) (+ x 800) (+ y (+ h 600)))
  (unless (zerop w)
    (set-frame-size (selected-frame) 800 200 t))
)
(add-hook 'ea-popup-hook 'popup-handler)
(add-hook 'after-make-frame-functions 'my/disable-scroll-bars)


(prefer-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)

;; lsp face
(custom-set-faces `(lsp-face-highlight-read  ((t (:foreground "#57a6db" :background "#292C33" :weight bold :underline nil)))))
(custom-set-faces `(lsp-face-highlight-write ((t (:foreground "#57a6db" :background "#292C33" :weight bold :underline nil)))))
(custom-set-faces `(tide-hl-identifier-face  ((t (:foreground "#57a6db" :background "#292C33")))))
(custom-set-faces `(avy-lead-face   ((t (:foreground "#00dfff" :background nil :weight bold)))))
(custom-set-faces `(avy-lead-face-0 ((t (:foreground "#2b8db3" :background nil :weight bold)))))
(custom-set-faces `(avy-lead-face-1 ((t (:foreground "#104E8B" :background nil :weight bold)))))
(custom-set-faces `(avy-lead-face-2 ((t (:foreground "#104E8B" :background nil :weight bold)))))
(custom-set-faces `(line-number     ((t (:inherit 'default :foreground "#3f444a" :background nil :weight normal :slant normal)))))
(custom-set-faces `(line-number-current-line ((t (:inherit 'default :foreground "#51afef" :background nil :weight normal :slant normal)))))
(custom-set-faces `(aw-leading-char-face     ((t (:foreground "#FFFFFF" :background "#4EAEEF" :height 300 :weight normal :slant normal)))))

;; close the modeline default
(add-hook 'buffer-list-update-hook (lambda ()
                                     (unless (active-minibuffer-window)
                                       (hide-mode-line-mode))))
;; make emacs auto save buffer
(custom-set-variables
  '(auto-save-visited-mode t))
(setq auto-save-visited-interval 5)
(setq auto-save-visited-predicate
        (lambda () (or (eq major-mode 'java-mode)
                       (eq major-mode 'org-mode))))

;; when close windows close neotree neither
(defun zygospore-toggle-delete-other-windows@around (fn)
  (if (> (count-windows) 1) (neotree-hide))
  (funcall fn))
(advice-add 'zygospore-toggle-delete-other-windows :around 'zygospore-toggle-delete-other-windows@around)
