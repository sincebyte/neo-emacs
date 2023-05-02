;;; private/common/config.el -*- lexical-binding: t; -*-
(blink-cursor-mode   0             )
(tool-bar-mode       0             )
(menu-bar-mode       0             )
(scroll-bar-mode     0             )

;; gc setting
(defmacro k-time (&rest body) `(let ((time (current-time))) ,@body (float-time (time-since time))))
(defvar k-gc-timer (run-with-idle-timer 15 t 'garbage-collect  ))

(defun kill-other-buffer ()
  (interactive)
  (dolist (buffer (delq (current-buffer) (buffer-list))) (kill-buffer buffer)))

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

(setq org-html-mathjax-options
  '((path "https://cdn.bootcss.com/mathjax/3.0.5/es5/tex-mml-chtml.js")))

(remove-hook 'doom-first-buffer-hook #'global-hl-line-mode)
(custom-set-variables '(x-select-enable-clipboard t))

(set-default 'truncate-lines nil  )
(setq-default treemacs-width 175  )


(defun my/disable-scroll-bars (frame)
  (modify-frame-parameters frame
                           '((vertical-scroll-bars . nil)
                             (horizontal-scroll-bars . nil))))
(defun popup-handler (app-name window-title x y w h)
  (set-frame-position (selected-frame) (+ x 800) (+ y (+ h 600)))
  (unless (zerop w)
    (set-frame-size (selected-frame) 800 200 t))
)
;; Hook your function
(add-hook 'ea-popup-hook 'popup-handler)
(add-hook 'after-make-frame-functions 'my/disable-scroll-bars)

;; set the alpha background
;; (setq-default alpha-list '((99 100) (100 100)))
;; (defun loop-alpha ()
;;   ;;doc
;;   (interactive)
;;   (let ((h (car alpha-list)))
;;     ((lambda (a ab)
;;        (set-frame-parameter (selected-frame) 'alpha (list a ab))
;;        (add-to-list 'default-frame-alist (cons 'alpha (list a ab)))
;;        ) (car h) (car (cdr h)))
;;     (setq alpha-list (cdr (append alpha-list (list h))))
;;     )
;; )
;; (loop-alpha)

(prefer-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)

(custom-set-faces '(lsp-face-highlight-read  ((t (:foreground "#57a6db" :background "#292C33" :underline nil)))))
(custom-set-faces '(lsp-face-highlight-write ((t (:foreground "#57a6db" :background "#292C33" :underline nil)))))
(custom-set-faces '(tide-hl-identifier-face  ((t (:foreground "#57a6db" :background "#292C33")))))

;; neotree setting
(setq neo-show-updir-line t
      neo-show-hidden-files nil
      neo-hidden-regexp-list
        '(;; vcs folders
          "^\\.\\(?:git\\|hg\\|svn\\)$"
          ;; eclipse
          "\\.\\(settings\\|classpath\\|factorypath\\)$"
          ;; store
          "^\\.DS_Store$"
          ;; compiled files
          "\\.\\(?:pyc\\|o\\|elc\\|lock\\|css.map\\|class\\)$"
          ;; generated files, caches or local pkgs
          "^\\(?:node_modules\\|vendor\\|.\\(project\\|cask\\|yardoc\\|sass-cache\\)\\)$"
          ;; org-mode folders
          "^\\.\\(?:sync\\|export\\|attach\\)$"
          ;; temp files
          "~$"
          "^#.*#$"))
