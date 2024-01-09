;;; neoemacs/java/config.el -*- lexical-binding: t; -*-
(setenv "XMLLINT_INDENT" "    ")
(use-package xml-format
  :demand t
  :defer t
  :after nxml-mode)

(setq ;;company-box-doc-enable                   nil
 company-tooltip-limit                      7
 company-auto-update-doc                    nil
 ;; company-frontends                       '(company-pseudo-tooltip-frontend company-echo-metadata-frontend)
 company-format-margin-function             'company-text-icons-margin
 company-text-icons-format                  " %s "
 company-text-icons-add-background          t
 company-text-face-extra-attributes         '(:weight bold :slant italic)
 ;; company-dabbrev-ignore-case             nil
 company-tooltip-flip-when-above            t
 company-show-quick-access                  nil)

(add-hook 'web-mode-hook (lambda ()
                           (setq display-line-numbers                       t)))
(add-hook 'js-mode-hook (lambda ()
                          (setq display-line-numbers                       t)))
(add-hook 'lisp-mode-hook (lambda ()
                            (setq display-line-numbers                       t)))
(add-hook 'lsp-mode-hook (lambda ()
                           (tree-sitter-hl-mode)
                           (setq display-line-numbers                       t
                                 lsp-enable-symbol-highlighting             t
                                 company-auto-update-doc                    nil
                                 ;; lsp-ui-doc-show-with-cursor                t
                                 lsp-idle-delay                             0.1
                                 lsp-signature-render-documentation         nil
                                 lsp-eldoc-render-all                       t
                                 lsp-signature-auto-activate                t
                                 lsp-signature-doc-lines                    1
                                 lsp-eldoc-enable-hover                     nil
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
(setq lsp-java-format-settings-url   (expand-file-name (concat doom-user-dir "neoemacs/Intellij_Spring_Boot_Java_Conventions.xml"))
      lsp-java-java-path             (concat (getenv "JAVA_17_HOME") "/bin/java")
      lsp-java-server-install-dir    "~/.m2/lsp-java/"
      lsp-maven-path                 "~/.m2/settings.xml"
      lsp-java-jdt-download-url      "http://1.117.167.195/download/jdt-language-server-1.27.1-202309140221.tar.gz"
      lsp-java-configuration-maven-user-settings (expand-file-name lsp-maven-path )
      lsp-java-vmargs                `("-XX:+UseParallelGC"
                                       "-XX:GCTimeRatio=4"
                                       "-XX:AdaptiveSizePolicyWeight=90"
                                       "-Dsun.zip.disableMemoryMapping=true"
                                       "-Xmx2G"
                                       "-Xms100m",
                                       (concat "-javaagent:"
                                               (expand-file-name (concat doom-user-dir "neoemacs/lombok.jar")))))

;; ;; ;; java key setting
(map! :nve "; c"     'comment-line                        )
(map! :ne  "; r"     'string-inflection-java-style-cycle  )
(map! :ne "SPC c I"  #'lsp-java-open-super-implementation )
(map! :map global-map "s-n" nil)

(map! :after lsp-java
      :map   lsp-mode-map
      :n "SPC f b" #'lsp-format-buffer
      :v "SPC f g" #'lsp-format-region
      :n "; i"     #'lsp-java-organize-imports
      :n "; s"     #'lsp-signature-activate
      :n "SPC t e" #'lsp-treemacs-java-deps-list
      :n "SPC t s" #'lsp-workspace-restart)

(custom-set-faces `(lsp-face-highlight-textual ((t (:background nil )))))
(custom-set-faces `(lsp-face-highlight-read ((t (:foreground "#57a6db" :background nil :weight bold :underline nil)))))
(custom-set-faces `(lsp-face-highlight-write ((t (:foreground "#57a6db" :background nil :weight bold :underline nil)))))
(custom-set-faces `(tide-hl-identifier-face ((t (:foreground "#57a6db" :background nil)))))

(company-posframe-mode 1)

(setq-hook! 'web-mode-hook indent-tabs-mode nil)
