;;; neoemacs/org/config.el -*- lexical-binding: t; -*-
(use-package! dotsk :defer t)
(use-package! ds2   :defer t)
;; common setting
(setq
 org-plantuml-executable-path  (expand-file-name (concat doom-user-dir "neoemacs/plantuml.jar"))
 org-plantuml-args             '("-headless")
 org-plantuml-jar-path         (expand-file-name (concat doom-user-dir "neoemacs/plantuml.jar"))
 dot-exec-path                 "/opt/homebrew/bin/dot"                                  ;; dot           exec path
 org-roam-graph-executable     dot-exec-path
 org-directory                 "~/org"
 org-roam-directory            "~/org/org-roam"
 ;; org-confirm-babel-evaluate    nil
 yas-indent-line               'fixed
 yas-also-auto-indent-first-line t
 global-auto-revert-mode       1
 org-export-with-broken-links  t ;; org link broken but do not effect
 auto-revert-verbose           nil ;; 禁用自动显示 Auto-Revert 的消息
 org-roam-v2-ack               t
 org-agenda-files              (list (concat org-roam-directory "/agenda/GTD.org"))
 org-image-actual-width        '(300)
 org-id-track-globally         t   ;; M-x org-id-update-id-locations , org-roam-update-org-id-locations
 org-html-mathjax-options      '((path "https://cdn.bootcss.com/mathjax/3.0.5/es5/tex-mml-chtml.js"))
 pdflatex-exec-path             "/Library/TeX/texbin/pdflatex"
 org-html-preamble-format      '(("en" "<p>Made ✐︎ by " (getenv "USER") "</p>"))
 org-roam-capture-templates    '(("d" "default" plain "%?"
                                  :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n#+subtitle: \n#+author: \n#+SETUPFILE: ~/.doom.d/org-classic-head.setup")
                                  :unnarrowed t))
 org-html-table-caption-above  nil
 gc-cons-threshold             (* 2 1000 1000)
 neo-show-updir-line           t
 neo-show-hidden-files         nil)
(add-to-list 'exec-path             pdflatex-exec-path )

;; org roam ui
;; (use-package! websocket
;;     :defer t
;;     :after org-roam)
(use-package! org-roam-ui
  :after org-roam ;; or :after org
  :defer t
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

;; (add-hook 'org-mode-hook '+org/close-all-folds)
;; (add-hook 'org-mode-hook
;;           (lambda ()
;;             (setq evil-shift-width 2)
;;             (+org/close-all-folds)))

(setq org-modern-todo nil)
(defun neo/org-set-todo-keyword-faces ()
  "Apply custom faces to TODO keywords."
  (mapc (lambda (face)
          (add-to-list 'org-todo-keyword-faces face))
        '(("TODO"      . (:foreground "#f1c40f" :weight bold))
          ("DOING"     . (:foreground "#00CFFF" :weight bold))
          ("BLOCK"     . (:foreground "#f39c12" :weight bold))
          ("TEST"      . (:foreground "#9b59b6" :weight bold))
          ("DONE"      . (:foreground "#27ae60" :weight bold))
          ("REPORT"    . (:foreground "#bdc3c7" :weight bold)))))

(after! org
  (setq evil-shift-width 2)
  (setq org-todo-keywords
        '((sequence "TODO" "DOING" "BLOCK" "TEST" "DONE" "REPORT")))
  (+org/close-all-folds)
  (open-company-english-helper))

;; (add-to-list 'load-path (expand-file-name (concat doom-user-dir "neoemacs/company-english-helper")))
;; (require 'company-english-helper)

(use-package! hl-todo
  :defer t
  :config
  ;; 配置高亮显示的关键字
  (setq hl-todo-keyword-faces
        '(("TODO"       . "#f1c40f")
          ("DOING"      . "#00CFFF")
          ("BLOCK"      . "#f39c12")
          ("TEST"       . "#9b59b6")
          ("DONE"       . "#27ae60")
          ("REPORT"     . "#bdc3c7")))
  ;; 启用全局 hl-todo 高亮显示
  (global-hl-todo-mode))

;; install mactex https://www.tug.org/mactex/
(with-eval-after-load 'ox-latex
  ;; http://orgmode.org/worg/org-faq.html#using-xelatex-for-pdf-export
  ;; latexmk runs pdflatex/xelatex (whatever is specified) multiple times
  ;; automatically to resolve the cross-references.
  (setq org-latex-pdf-process '("latexmk -xelatex -quiet -shell-escape -f %f"))
  (add-to-list 'org-latex-classes
               '("elegantpaper"
                 "\\documentclass[lang=cn]{elegantpaper}
                 [NO-DEFAULT-PACKAGES]
                 [PACKAGES]
                 [EXTRA]"
                 ("\\section{%s}" . "\\section*{%s}")
                 ("\\subsection{%s}" . "\\subsection*{%s}")
                 ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
                 ("\\paragraph{%s}" . "\\paragraph*{%s}")
                 ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))
  (setq org-latex-src-block-backend 'listings)
  (add-to-list 'org-latex-packages-alist '("" "minted"))
  (add-to-list 'org-latex-packages-alist '("" "listings"))
  (add-to-list 'org-latex-packages-alist '("" "color")))

;; html image base64
(defun org-html--format-image-old (source attributes info)
  (org-html-close-tag
   "img"
   (org-html--make-attunderlinete-string
    (org-combine-plists
     (list :src source
           :alt (if (string-match-p
                     (concat "^" org-preview-latex-image-directory) source)
                    (org-html-encode-plain-text
                     (org-find-text-property-in-string 'org-latex-src source))
                  (file-name-nondirectory source)))
     (if (string= "svg" (file-name-extension source))
         (org-combine-plists '(:class "org-svg") attributes '(:fallback nil))
       attributes)))
   info))
(defun org-org-html--format-image (source attributes info)
  ;; doc
  (if (string-match "http" source)
      (org-html--format-image-old source attributes info)
    (format "<img src=\"data:image/%s+xml;base64,%s\"%s width=%s />"
            (or (file-name-extension source) "")
            (base64-encode-string
             (with-temp-buffer
               (insert-file-contents-literally source)
               (string-replace "UNLICENSED COPY" " "
                               (buffer-string))))
            (file-name-nondirectory source)
            "")))
;; enable image to base64
;; (advice-add #'org-html--format-image :override #'org-org-html--format-image)

;; expand your latex
(use-package org-appear
  :defer t
  :hook (org-mode . org-appear-mode)
  :config
  (setq org-appear-autolinks       t )
  (setq org-appear-autosubmarkers  t )
  (setq org-appear-autoentities    t )
  (setq org-appear-autokeywords    t )
  (setq org-appear-inside-latex    t ))

(map! :after org
      :map org-mode-map
      :ne "; l" #'org-toggle-narrow-to-subtree)

(set-company-backend! 'org-mode
  'company-ispell 'company-yasnippet)

(setq system-time-locale "C")

(use-package org-modern
  :defer t
  :hook (org-mode . org-modern-mode)
  :custom
  (org-modern-list '((43 . "•") (45 . "◦")))
  (org-ellipsis " ")
  (org-modern-table nil)
  :config
  (neo/org-set-todo-keyword-faces)
  (setq org-modern-keyword '((t . t) ("caption" . "☰"))
        org-pretty-entities t
        org-tags-column 0
        org-modern-block-fringe 10
        org-modern-block-name t
        org-modern-star 'org-modern-replace-stars
        org-modern-replace-stars    '("⁞" "⁞⁞" "⁞⁞⁞" "⁞⁞⁞⁞" "⁞⁞⁞⁞⁞")))
;; (custom-set-faces `(org-block-begin-line ((t (:foreground "#008ED1" :background "#EAEAFF")))))
;; (custom-set-faces `(org-block-end-line   ((t (:foreground "#008ED1" :background "#EAEAFF")))))

(setq org-latex-create-formula-image-program 'dvipng)

(map! :after org
      :map (org-mode-map)
      "C-," nil)

(use-package org-modern-indent
  :defer t
  :load-path "~/.doom.d/neoemacs/org-modern-indent/"
  :config
  (add-hook 'org-mode-hook #'org-modern-indent-mode 90))

(defconst org-modern-indent-begin (propertize "┌"  'face 'org-modern-indent-bracket-line))
(defconst org-modern-indent-guide (propertize "│ " 'face 'org-modern-indent-bracket-line))
(defconst org-modern-indent-end   (propertize "└"  'face 'org-modern-indent-bracket-line))

(use-package emt
  :defer t
  :hook (after-init . emt-mode)
  :config (setq emt-lib-path (concat doom-user-dir "neoemacs/libEMT-aarch64.dylib" )))

;; so queer there should a delay
(defun open-company-english-helper ()
  (run-at-time "1 sec" nil #'open-company-english-helper-dy))

(defun open-company-english-helper-dy ()
  (interactive)
  (progn
    (setq company-backends (remove 'company-english-helper-search company-backends))
    ;; I need remove `company-english-helper-search' with `company-yasnippet',
    ;; it's not enough just remove `company-english-helper-search' from `company-backends'
    (setq company-backends (remove '(company-english-helper-search :with company-yasnippet) company-backends))
    (setq company-english-helper-active-p nil))
  (if (not company-mode)
      (company-mode t))
  (setq company-english-helper-active-p nil)
  (add-to-list 'company-backends 'company-english-helper-search)
  (setq company-english-helper-active-p t)
  (message "English helper has enable."))

(use-package company-english-helper
  :load-path "~/.doom.d/neoemacs/company-english-helper"
  :config
  (add-hook 'org-mode-hook #'open-company-english-helper))
