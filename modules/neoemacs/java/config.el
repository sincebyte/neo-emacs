;;; neoemacs/java/config.el -*- lexical-binding: t; -*-

;; (add-hook 'java-mode-hook 'lsp)
;; (add-hook 'java-mode-hook 'tree-sitter-hl-mode)
;; (add-hook 'java-mode-hook 'rainbow-delimiters-mode)
;; (add-hook 'java-mode-hook 'vimish-fold-mode)
;; (add-hook 'java-mode-hook

;; (set-company-backend! 'prog-mode
;;   '(:separate company-capf company-yasnippet company-dabbrev company-ispell))
;; company setting
(setq company-box-doc-enable                     nil
      company-tooltip-limit                      7
      ;; company-tooltip-offset-display             'scrollbar
      company-frontends                          '(company-pseudo-tooltip-frontend company-echo-metadata-frontend)
      company-format-margin-function             'company-text-icons-margin
      company-text-icons-format                  " %s "
      company-text-icons-add-background          t
      company-text-face-extra-attributes         '(:weight bold :slant italic)
      company-dabbrev-ignore-case                nil
      company-tooltip-flip-when-above            t
      company-show-quick-access                  nil)


(add-hook 'java-mode-hook
       (setq
        lsp-idle-delay                             0.1
        lsp-eldoc-enable-hover                     t
        lsp-java-format-comments-enabled           nil
        lsp-java-save-actions-organize-imports     nil
        lsp-java-autobuild-enabled                 t
        lsp-inhibit-message                        t
        lsp-java-completion-guess-method-arguments t
        lsp-completion-show-kind                   nil
        lsp-completion-sort-initial-results        t
        lsp-completion-show-detail                 nil
        lsp-completion-enable-additional-text-edit t
        lsp-java-progress-reports-enabled          nil
        lsp-completion-show-label-description      nil
        lsp-modeline-diagnostics-enable            t
        lsp-modeline-diagnostics-scope             :workspace
        lsp-modeline-code-actions-enable           nil
        lsp-enable-file-watchers                   nil
        lsp-lens-enable                            t))

(set-company-backend! 'prog-mode
  '(:separate company-capf company-yasnippet company-dabbrev company-ispell))

(setq lsp-java-format-settings-url   (expand-file-name (concat doom-user-dir "neoemacs/eclipse-codestyle.xml"))
      lsp-java-java-path             (concat (getenv "JAVA_HOME") "/bin/java")                ;; java11        exec path
      lsp-maven-path                 "~/.m2/settings.xml"                                     ;; maven setting path
      lsp-java-jdt-download-url      "http://1.117.167.195/download/jdt-language-server-1.7.0-202112161541.tar.gz"
      lsp-java-configuration-maven-user-settings (expand-file-name lsp-maven-path )
      plantuml-jar-path              ( expand-file-name (concat doom-user-dir "neoemacs/plantuml.jar"))
      plantuml-default-exec-mode     'jar
      lombok-jar-path                ( expand-file-name (concat doom-user-dir "neoemacs/lombok.jar"))
)
(setq lsp-java-configuration-runtimes '[(:name "JavaSE-17"
                                                :path "/Users/van/soft/jdk-17.0.6.jdk/Contents/Home"
                                                :default t)])

;; java key setting
(map! :ne "SPC v l" 'lsp-java-assign-statement-to-local        )
(map! :ne "; i"     'lsp-java-organize-imports                 )
(map! :ne ", m"     'lsp-java-add-unimplemented-methods        )
(map! :ne "; r"     'string-inflection-java-style-cycle        )
(map! :ne "SPC c u" 'lsp-java-open-super-implementation        )
(map! :ne "SPC c l" 'lsp-java-assign-statement-to-local        )
(map! :ne "SPC i n" 'marco-java-new                            )
(map! :ne "; s"     'lsp-workspace-restart                     )
(map! :nve ", f r"  'lsp-format-region                         )
(map! :ne ", f b"   'lsp-format-buffer                         )
(map! :ne "SPC v r" 'lsp-rename                                )
