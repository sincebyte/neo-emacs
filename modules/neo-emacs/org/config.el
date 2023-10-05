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
      org-directory                 "~/org/org-roam"
      org-roam-directory            "~/org/org-roam"
      org-confirm-babel-evaluate    nil
      yas-indent-line               'fixed
      yas-also-auto-indent-first-line t
      org-roam-v2-ack               t
      org-agenda-files              (list (concat org-roam-directory "/agenda/GTD.org"))
      org-image-actual-width        '(300)
      org-id-track-globally         t   ;; M-x org-id-update-id-locations , org-roam-update-org-id-locations
      org-html-mathjax-options      '((path "https://cdn.bootcss.com/mathjax/3.0.5/es5/tex-mml-chtml.js"))
      pdflatex-exec-path             "/Library/TeX/texbin/pdflatex"
      org-html-preamble-format      '(("en" "<div id=\"preamble\" class=\"status\"><p class=\"author\">Made with ✍ by %a</p></div>"))
      org-roam-capture-templates    '(("d" "default" plain "%?"
                                    :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n#+subtitle: \n#+author: vanniuner\n#+SETUPFILE: ~/.doom.d/org-head.setup")
                                    :unnarrowed t))
      org-html-table-caption-above  nil
      gc-cons-threshold             (* 2 1000 1000)
      neo-show-updir-line           t
      neo-show-hidden-files         nil
      neo-hidden-regexp-list        '(
          ;; vcs folders
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
(add-to-list 'exec-path          pdflatex-exec-path               )

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
(add-hook 'org-mode-hook '+org/close-all-folds)

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
   (org-html--make-attribute-string
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
      "100%")))
(advice-add #'org-html--format-image :override #'org-org-html--format-image)

;; expand your latex
(use-package org-appear
  :defer t
  :hook (org-mode . org-appear-mode)
  :config
  (setq org-appear-autolinks t)
  (setq org-appear-autosubmarkers t)
  (setq org-appear-autoentities t)
  (setq org-appear-autokeywords t)
  (setq org-appear-inside-latex t))

(map! :after org
      :map org-mode-map
      :ne "; l" #'org-toggle-narrow-to-subtree)

(set-company-backend! 'org-mode
    'company-ispell 'company-yasnippet)
