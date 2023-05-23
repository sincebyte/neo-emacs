;;; neoemacs/java/config.el -*- lexical-binding: t; -*-

(setq ompany-box-doc-enable                     nil
      company-tooltip-limit                      7
      ;; company-frontends                          '(company-pseudo-tooltip-frontend company-echo-metadata-frontend)
      company-format-margin-function             'company-text-icons-margin
      company-text-icons-format                  " %s "
      company-text-icons-add-background          t
      company-text-face-extra-attributes         '(:weight bold :slant italic)
      company-dabbrev-ignore-case                nil
      company-tooltip-flip-when-above            t
      company-show-quick-access                  nil)

(after! lsp-java
       (setq
        lsp-idle-delay                             0.1
        lsp-eldoc-enable-hover                     t
        lsp-eldoc-render-all                       t
        lsp-java-format-enabled                    nil
        lsp-java-format-comments-enabled           nil
        lsp-java-format-on-type-enabled            t
        lsp-java-save-actions-organize-imports     nil
        lsp-java-maven-download-sources            t
        lsp-java-autobuild-enabled                 t
        lsp-inhibit-message                        t
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
        lsp-lens-enable                            t))

;; (set-company-backend! 'prog-mode
;;   '(:separate company-capf company-yasnippet company-dabbrev company-ispell))

(setq lsp-java-format-settings-url   (expand-file-name (concat doom-user-dir "neoemacs/eclipse-codestyle.xml"))
      lsp-java-java-path             (concat (getenv "JAVA_17_HOME") "/bin/java")
      lsp-maven-path                 "~/.m2/settings.xml"
      lsp-java-jdt-download-url      "http://1.117.167.195/download/jdt-language-server-1.22.0-202304131553.tar.gz"
      lsp-java-configuration-maven-user-settings (expand-file-name lsp-maven-path )
      plantuml-jar-path              ( expand-file-name (concat doom-user-dir "neoemacs/plantuml.jar"))
      plantuml-default-exec-mode     'jar
      inferior-lisp-program          "/opt/homebrew/bin//sbcl"
      lombok-jar-path                ( expand-file-name (concat doom-user-dir "neoemacs/lombok.jar")))

;; ;; ;; java key setting
(map! :nve "; c"     'comment-line                        )
(map! :ne  "; r"     'string-inflection-java-style-cycle  )
(map! :ne "SPC c I"  #'lsp-java-open-super-implementation )
(map! :ne "SPC c I"  #'lsp-java-open-super-implementation )
(map! :map global-map "s-n" nil)

(map! :after lsp-java
      :map lsp-mode-map
      :n "; s"  #'lsp-signature-activate)

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



