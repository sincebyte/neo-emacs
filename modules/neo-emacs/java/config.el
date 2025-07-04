
;;; neoemacs/java/config.el -*- lexical-binding: t; -*-
;;;
(setenv "XMLLINT_INDENT" "    ")
(use-package xml-format
  :demand t
  :defer t
  :after nxml-mode)

(use-package prism
  :defer t
  :config
  (prism-set-colors :lightens '(0 5 10) :desaturations '(-2.5 0 2.5)
                    :colors (-map #'doom-color
                                  '(red orange yellow green blue violet))))


(setq ;;company-box-doc-enable                   nil
 company-tooltip-limit                      7
 ;; company-auto-update-doc                    nil
 ;; company-frontends                       '(company-pseudo-tooltip-frontend company-echo-metadata-frontend)
 ;; company-dabbrev-ignore-case             nil
 ;; lsp-enable-file-watchers                   t
 indent-guides-char                         ?│
 lsp-progress-prefix                        "󰫆 "
 company-format-margin-function             'company-text-icons-margin
 company-text-icons-format                  " %s "
 company-text-icons-add-background          t
 company-text-face-extra-attributes         '(:weight bold :family "Street Stencil")
 company-tooltip-flip-when-above            t
 company-show-quick-access                  nil
 +format-on-save-disabled-modes             (add-to-list '+format-on-save-disabled-modes 'c++-mode)
 +format-on-save-disabled-modes             (add-to-list '+format-on-save-disabled-modes 'c-mode))


(setq lsp-semgrep-languages '()
      +tree-sitter-hl-enabled-modes '(java-mode go-mode)
      lsp-warn-no-matched-clients nil)
(setq-default flymake-no-changes-timeout 30)
(add-hook 'go-mode-hook
          (lambda ()
            (setq lsp-modeline-code-action-fallback-icon                         "")))
(add-hook 'web-mode-hook (lambda ()
                           (prism-mode)
                           (setq display-line-numbers                       t
                                 lsp-modeline-code-actions-enable           nil
                                 +format-on-save-disabled-modes (add-to-list '+format-on-save-disabled-modes 'web-mode)
                                 doom-modeline-icon                         nil)))
(add-hook 'js-mode-hook (lambda ()
                          ;; (prism-mode)
                          (setq display-line-numbers                        t)))
(add-hook 'lisp-mode-hook (lambda ()
                            (focus-mode)
                            ;; (prism-mode)
                            (setq display-line-numbers                      t)))

;; (setq company-text-icons-add-background t)
;; (set-face-background 'font-lock-variable-name-face "#00e5ee")
(add-hook 'java-mode-hook (lambda ()
                            ;; (prism-mode)
                            (focus-mode)
                            (apheleia-global-mode -1)
                            (setq-local lsp-enable-file-watchers nil)
                            (tree-sitter-hl-mode)
                            (indent-bars-mode 1)
                            (setq display-line-numbers                       t
                                  lsp-java-compile-null-analysis-mode        "automatic"
                                  ;; company-text-icons-format                  "%s ⇢ "
                                  company-text-icons-add-background          t
                                  lsp-enable-symbol-highlighting             t
                                  company-auto-update-doc                    nil
                                  lsp-ui-doc-show-with-cursor                nil
                                  ;; lsp-ui-sideline-enable                     nil
                                  ;; lsp-ui-sideline-show-diagnostics           t
                                  ;; lsp-ui-sideline-show-hover                 t
                                  lsp-ui-sideline-diagnostic-max-lines       2
                                  lsp-ui-sideline-diagnostic-max-line-length 550
                                  lsp-ui-sideline-update-mode                'point
                                  lsp-idle-delay                             0.1
                                  lsp-signature-render-documentation         nil
                                  lsp-signature-auto-activate                nil
                                  lsp-eldoc-enable-hover                     t
                                  lsp-eldoc-render-all                       nil
                                  lsp-signature-auto-activate                t
                                  lsp-java-signature-help-enabled            t
                                  ;; lsp-signature-doc-lines                    1
                                  ;; lsp-java-references-code-lens-enabled      t
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
                                  lsp-completion-show-detail                 t
                                  lsp-java-completion-guess-method-arguments t
                                  lsp-completion-enable-additional-text-edit t
                                  lsp-java-progress-reports-enabled          nil
                                  lsp-progress-prefix                        "󰫆 "
                                  ;; lsp-completion-show-label-description      nil
                                  lsp-modeline-diagnostics-enable            t
                                  lsp-modeline-diagnostics-scope             :workspace
                                  lsp-modeline-code-actions-enable           nil
                                  lsp-lens-enable                            t)))
(setq lsp-java-format-settings-url   (expand-file-name (concat doom-user-dir "neoemacs/eclipse-codestyle.xml"))
      lsp-java-java-path             (concat (getenv "JAVA_21_HOME") "/bin/java")
      lsp-java-server-install-dir    "~/lsp-java/"
      lsp-maven-path                 (concat (getenv "MAVEN_HOME") "/conf/settings.xml")
      lsp-java-jdt-download-url      "http://localhost:8080/jdt-language-server-1.47.0-202505151856.tar.gz"
      ;; lsp-java-jdt-download-url      "http://1.117.167.195/download/jdt-language-server-1.38.0-202407151826.tar.gz"
      lsp-java-configuration-maven-user-settings (expand-file-name lsp-maven-path )
      lsp-java-vmargs                `("-XX:+UseParallelGC"
                                       "-XX:GCTimeRatio=4"
                                       "-XX:AdaptiveSizePolicyWeight=90"
                                       "-Dsun.zip.disableMemoryMapping=true"
                                       "-Xmx2G"
                                       "-Xms100m",
                                       (concat "-javaagent:"
                                               (expand-file-name (concat doom-user-dir "neoemacs/lombok1.18.38.jar"))))
)

;; ;; ;; java key setting
(map! :nve "; c"     'comment-line                        )
(map! :ne  "; r"     'string-inflection-java-style-cycle  )
(map! :ne "SPC c I"  #'lsp-java-open-super-implementation )
(map! :map global-map "s-n" nil)

(unbind-key "c f" doom-leader-map)
(map! :after lsp-java
      :map   general-override-mode-map
      :v     "SPC c f" nil)
(map! :after evil
      :map evil-normal-state-map
      :ne "; i" nil)
evil-normal-state-map
(map! :after lsp-java
      :map   lsp-mode-map
      :n "SPC f b" #'lsp-format-buffer
      :v "SPC c f" #'lsp-format-region
      :v "SPC f g" #'lsp-format-region
      :n "; i"     #'lsp-java-organize-imports
      :n "; s"     #'lsp-signature-activate
      :n "SPC t e" #'lsp-treemacs-java-deps-list
      :n "; p"     #'(lambda () (interactive) (lsp-ui-find-workspace-symbol (concat "@/")))
      :n "SPC t s" #'lsp-workspace-restart)


(custom-set-faces `(lsp-face-highlight-textual ((t (:background unspecified )))))
;; (custom-set-faces `(lsp-face-highlight-textual ((t (:background nil )))))
(custom-set-faces `(lsp-face-highlight-read ((t (:underline nil :weight bold :slant italic)))))
(custom-set-faces `(lsp-face-highlight-write ((t (:underline nil :weight bold :slant italic)))))
;; (custom-set-faces `(tide-hl-identifier-face ((t (:foreground "#57a6db" :background nil)))))

;; (company-posframe-mode 1)

(setq-hook! 'web-mode-hook indent-tabs-mode nil)

(after! lsp-mode
  (setq lsp-disabled-clients '(xmlls)))

;;(add-hook 'java-mode-hook #'(lambda () (add-hook 'post-command-hook #'my-java-hook-function nil t)))
;; (defun my-java-hook-function () (lsp-signature-activate))
;;(add-to-list 'lsp-language-id-configuration '(".*\\.html\\.erb$" .(setq tab-always-indent ‘complete)

(use-package web-mode
  :defer t
  :custom
  (web-mode-markup-indent-offset 2)
  (web-mode-css-indent-offset 2)
  (web-mode-code-indent-offset 2))

(after! tramp
  (setq explicit-shell-file-name "/bin/bash"))

(connection-local-set-profile-variables
 'remote-direct-async-process
 '((tramp-direct-async-process . t)))
(connection-local-set-profiles
 '(:application tramp :protocol "ssh")
 'remote-direct-async-process)

(setq tramp-default-method "ssh")
(setq tramp-verbose 0)
;; (setq tramp-connection-properties '(("hassio"  "root" "explicit-shell-file-name" "/bin/bash")))

(defun org-babel-edit-prep:java (babel-info)
  (setq-local buffer-file-name (->> babel-info caddr (alist-get :tangle)))
  (lsp))

;; (use-package pulsing-cursor
;;   :config (pulsing-cursor-mode +1))

(with-eval-after-load 'lsp-java
  (setq lsp-file-watch-ignored-directories
        '("[/\\\\]\\.git$"
          "[/\\\\]\\.m2$"
          "[/\\\\]node_modules$"
          "[/\\\\]\\.classpath$"
          "[/\\\\]\\.project$"
          "[/\\\\]\\.settings$"
          "[/\\\\]target$"
          "[/\\\\]build$")))

;; (add-hook 'lsp-mode-hook #'lsp-lens-mode)
;; (add-hook 'java-mode-hook #'lsp-java-boot-lens-mode)
;; (after! corfu
;;   (setq corfu-preselect 'prompt)     ;; 不自动选中鼠标悬停的项
;;   (setq corfu-on-exact-match nil))   ;; 防止鼠标悬浮自动补全
