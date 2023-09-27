;;; neoemacs/java/config.el -*- lexical-binding: t; -*-

(setq ompany-box-doc-enable                     nil
      company-tooltip-limit                      7
      ;; company-frontends                          '(company-pseudo-tooltip-frontend company-echo-metadata-frontend)
      company-format-margin-function             'company-text-icons-margin
      company-text-icons-format                  " %s "
      company-text-icons-add-background          t
      company-text-face-extra-attributes         '(:weight bold :slant italic)
      ;; company-dabbrev-ignore-case                nil
      company-tooltip-flip-when-above            t
      company-show-quick-access                  nil)

(setq lsp-eldoc-enable-hover                     t)
(setq lsp-eldoc-render-all                     t)
(add-hook 'java-mode-hook (lambda ()
  (setq display-line-numbers                       t
        lsp-enable-symbol-highlighting             t
        lsp-idle-delay                             0.1
        lsp-signature-auto-activate                t
        lsp-signature-doc-lines                    10
        lsp-eldoc-enable-hover                     t
        lsp-java-signature-help-enabled            t
        lsp-java-references-code-lens-enabled      t
        lsp-java-implementations-code-lens-enabled t
        lsp-enable-on-type-formatting              t
        lsp-java-format-enabled                    t
        lsp-java-format-on-type-enabled            t
        lsp-java-format-comments-enabled           nil
        lsp-java-save-actions-organize-imports     nil
        lsp-java-maven-download-sources            "true"
        lsp-java-autobuild-enabled                 t
        lsp-java-inhibit-message                   nil
        lsp-completion-show-kind                   nil
        lsp-completion-sort-initial-results        t
        lsp-completion-show-detail                 nil
        lsp-java-completion-guess-method-arguments t
        lsp-completion-enable-additional-text-edit t
        lsp-java-progress-reports-enabled          nil
        lsp-completion-show-label-description      nil
        lsp-modeline-diagnostics-enable            t
        lsp-modeline-diagnostics-scope             :workspace
        lsp-modeline-code-actions-enable           nil
        lsp-enable-file-watchers                   nil
        lsp-lens-enable                            t)))

;; (set-company-backend! 'prog-mode
;;   '(:separate company-capf company-yasnippet company-dabbrev company-ispell))

(setq lsp-java-format-settings-url   (expand-file-name (concat doom-user-dir "neoemacs/Intellij_Spring_Boot_Java_Conventions.xml"))
      ;; lsp-java-java-path             (concat (getenv "$OJAVA_17_HOME") "/Users/van/soft/jdk/jdk-17.0.6.jdk/Contents/Home/bin/java")
      lsp-java-java-path             (concat "/Users/van/soft/jdk/jdk-17.0.6.jdk/Contents/Home/bin/java")
      lsp-maven-path                 "~/.m2/settings.xml"
      lsp-java-jdt-download-url      "http://1.117.167.195/download/jdt-language-server-1.22.0-202304131553.tar.gz"
      lsp-java-configuration-maven-user-settings (expand-file-name lsp-maven-path )
      inferior-lisp-program          "/opt/homebrew/bin//sbcl"
      lombok-jar-path                ( expand-file-name (concat doom-user-dir "neoemacs/lombok.jar")))

;; ;; ;; java key setting
(map! :nve "; c"     'comment-line                        )
(map! :ne  "; r"     'string-inflection-java-style-cycle  )
(map! :ne "SPC c I"  #'lsp-java-open-super-implementation )
(map! :map global-map "s-n" nil)

(map! :after lsp-java
      :map   lsp-mode-map
      :n "; i"     #'lsp-java-organize-imports
      :n "; s"     #'lsp-signature-activate
      :n "SPC t e" #'lsp-treemacs-java-deps-list
      :n "SPC t s" #'lsp-restart-workspace)

(add-hook 'java-mode-hook (lambda () (tree-sitter-hl-mode)))

;; (map! :after lsp-mode
;;       :map lsp-signature-mode-map
;;       :n "c-k"  nil
;;       :n "c-n"  nil
;;       :n "c-j"  nil)

;; (map! :after lsp-mode
;;       :map lsp-signature-mode-map
;;       :n "c-k"  #'lsp-signature-previous
;;       :n "c-n"  #'lsp-signature-previous
;;       :n "c-j"  #'lsp-signature-next)

;;(evil-define-key* 'normal lsp-signature-mode-map
;; "C-n" #'lsp-signature-next)
;; (add-hook 'java-mode-hook #'aggressive-indent-mode)
;; (add-hook 'lsp-save)
