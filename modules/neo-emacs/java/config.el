
;;; neoemacs/java/config.el -*- lexical-binding: t; -*-
;;;
(setenv "XMLLINT_INDENT" "    ")
(use-package xml-format
  :demand t
  :defer t
  :after nxml-mode)

;; (use-package prism
;;   :defer t
;;   :config
;;   (prism-set-colors :lightens '(0 5 10) :desaturations '(-2.5 0 2.5)
;;                     :colors (-map #'doom-color
;;                                   '(red orange yellow green blue violet))))


(setq ;;company-box-doc-enable                   nil
 lsp-print-io                               nil
 lsp-log-io                                 nil
 company-tooltip-limit                      7
 ;; company-auto-update-doc                    nil
 ;; company-frontends                       '(company-pseudo-tooltip-frontend company-echo-metadata-frontend)
 ;; company-dabbrev-ignore-case             nil
 ;; lsp-enable-file-watchers                   nil
 indent-guides-char                         ?│
 lsp-progress-prefix                        "󰫆 "
 company-format-margin-function             'company-text-icons-margin
 company-text-icons-format                  " %s "
 company-text-icons-add-background          t
 company-text-face-extra-attributes         '(:weight bold :family "Street Stencil")
 company-tooltip-flip-when-above            t
 company-show-quick-access                  nil
 ;; lsp-pylsp-plugins-autopep8-enabled         t
 ;; lsp-pylsp-plugins-rope-autoimport-code-actions-enabled  t
 ;; lsp-pylsp-plugins-rope-autoimport-enabled  t
 ;; lsp-pylsp-plugins-pydocstyle-enabled       nil
 ;; +format-on-save-disabled-modes             (add-to-list '+format-on-save-disabled-modes 'c++-mode)
 ;; +format-on-save-disabled-modes             (add-to-list '+format-on-save-disabled-modes 'c-mode))
 )
(use-package kind-icon
  :ensure t
  :after corfu
  :custom
  (kind-icon-blend-background t)
                                        ; (kind-icon-default-face 'corfu-default) ; only needed with blend-background
  :config
  (setq kind-icon-use-icons  nil
        corfu-count          7    )
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))
(after! corfu
  (corfu-popupinfo-mode -1)              ; 强制禁用
  (setq corfu-popupinfo-delay nil        ; 禁止延迟触发
        corfu-popupinfo-hide t           ; 隐藏可能残留的弹窗
        corfu-auto                t
        corfu-preselect           'first
        corfu-bar-width           0.3
        corfu-quit-at-boundary    nil
        corfu-quit-no-match       nil
        corfu-popupinfo-max-width 0      ; 确保弹窗尺寸为零
        corfu-popupinfo-max-height 0)
  (custom-set-faces!
    '(corfu-current :background "#2C3946" :foreground "#7BB6E2" :weight bold))
  (define-key corfu-map (kbd "<escape>") nil))

(with-eval-after-load 'vertico
  (keymap-set vertico-map "C-j" #'vertico-next)
  (keymap-set vertico-map "C-k" #'vertico-previous))


;; (setq lsp-semgrep-languages '()
;;       +tree-sitter-hl-enabled-modes '(java-mode go-mode)
;;       lsp-warn-no-matched-clients nil)
;;
(setq-default flymake-no-changes-timeout 30)
(add-hook 'go-mode-hook
          (lambda ()
            (setq lsp-modeline-code-action-fallback-icon                         "")))
(add-hook 'web-mode-hook (lambda ()
                           ;; (prism-mode)
                           (rainbow-delimiters-mode)
                           (setq display-line-numbers                       t
                                 lsp-modeline-code-actions-enable           nil
                                 ;; +format-on-save-disabled-modes (add-to-list '+format-on-save-disabled-modes 'web-mode)
                                 doom-modeline-icon                         nil)))
(add-hook 'js-mode-hook (lambda ()
                          ;; (prism-mode)
                          (rainbow-delimiters-mode)
                          (setq display-line-numbers                        t)))
(add-hook 'emacs-lisp-mode-hook (lambda ()
                                  (rainbow-delimiters-mode)
                                  (setq display-line-numbers                      t)))

(add-hook 'python-ts-mode-hook (lambda ()
                                 (focus-mode)
                                 (rainbow-delimiters-mode)
                                 (setq lsp-modeline-code-action-icons-enable nil)
                                 (setq lsp-modeline-code-actions-enable nil)
                                 (setq doom-modeline-check-icon nil)
                                 (setq display-line-numbers                      t)))

;; (setq company-text-icons-add-background t)
;; (set-face-background 'font-lock-variable-name-face "#00e5ee")
(add-hook 'java-ts-mode-hook
          (lambda ()
            (lsp)
            (setq display-line-numbers t)))
(after! lsp-mode
  (set-face-attribute 'lsp-face-highlight-read nil :slant 'normal)
  (set-face-attribute 'lsp-face-highlight-write nil :slant 'normal)
  (setq lsp-modeline-code-action-icons-enable nil
        lsp-modeline-code-actions-enable nil))

(with-eval-after-load 'lsp-mode
  (focus-mode)
  (apheleia-global-mode -1)
  (setq-local lsp-enable-file-watchers nil
              lsp-modeline-code-actions-enable nil)
  (rainbow-delimiters-mode)
  (indent-bars-mode 1)
  (customize-set-variable 'lsp-ui-sideline-enable nil)
  (setq display-line-numbers                       t
        lsp-idle-delay                             nil
        corfu-popupinfo-mode                       nil
        lsp-java-compile-null-analysis-mode        "automatic"
        ;; company-text-icons-format                  "%s ⇢ "
        ;; company-text-icons-add-background          t
        ;; company-auto-update-doc                    nil
        lsp-completion-show-annotation             nil
        lsp-completion-show-label-description      nil
        lsp-completion-show-detail                 t
        lsp-enable-symbol-highlighting             t
        lsp-ui-doc-show-with-cursor                nil
        ;; lsp-ui-sideline-show-diagnostics           t
        ;; lsp-ui-sideline-show-hover                 t
        lsp-ui-sideline-enable                     nil
        lsp-ui-sideline-diagnostic-max-lines       1
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
        lsp-java-implementations-code-lens-enabled nil
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
        lsp-java-completion-guess-method-arguments t
        lsp-completion-enable-additional-text-edit t
        lsp-java-progress-reports-enabled          nil
        lsp-progress-prefix                        "󰫆 "
        lsp-modeline-diagnostics-enable            t
        lsp-modeline-diagnostics-scope             :workspace
        lsp-modeline-code-actions-enable           nil
        lsp-modeline-code-action-icons-enable      nil
        lsp-java-completion-overwrite              nil
        lsp-enable-file-watchers                   t
        lsp-file-watch-threshold                   2000
        lsp-lens-enable                            t))

(setq
 ;; lsp-java-format-settings-url   (expand-file-name (concat doom-user-dir "neoemacs/eclipse-codestyle.xml"))
 lsp-java-java-path             (concat (getenv "JAVA_21_HOME") "/bin/java")
 lsp-java-server-install-dir    "~/lsp-java/"
 lsp-maven-path                 (concat (getenv "MAVEN_HOME") "/conf/settings.xml")
 lsp-java-jdt-download-url      "http://localhost:8080/jdt-language-server-1.50.0-202509041425.tar.gz"
 ;; lsp-java-jdt-download-url      "http://1.117.167.195/download/jdt-language-server-1.38.0-202407151826.tar.gz"
 lsp-java-configuration-maven-user-settings (expand-file-name lsp-maven-path )
 lsp-java-vmargs                `(
                                  ;; "-XX:+UseParallelGC"
                                  ;; "-XX:GCTimeRatio=4"
                                  ;; "-XX:AdaptiveSizePolicyWeight=90"
                                  ;; "-Dsun.zip.disableMemoryMapping=true"
                                  ;; "-Xmx1G"
                                  "-Xms128m",
                                  (concat "-javaagent:"
                                          (expand-file-name (concat doom-user-dir "neoemacs/lombok1.18.38.jar")))))

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
      :n "; i"     #'lsp-java-add-import
      :v "; l"     #'lsp-java-extract-to-local-variable
      :v "; s"     #'lsp-java-extract-to-local-variable
      :v "; m"     #'lsp-java-extract-method
      :n "SPC t e" #'lsp-treemacs-java-deps-list
      :n "SPC t s" #'lsp-workspace-restart)


(custom-set-faces `(lsp-face-highlight-textual ((t (:background unspecified )))))
;; (custom-set-faces `(lsp-face-highlight-textual ((t (:background nil )))))
(custom-set-faces `(lsp-face-highlight-read ((t (:underline nil :weight bold :slant italic)))))
(custom-set-faces `(lsp-face-highlight-write ((t (:underline nil :weight bold :slant italic)))))
;; (custom-set-faces `(tide-hl-identifier-face ((t (:foreground "#57a6db" :background nil)))))

;; (company-posframe-mode 1)

(setq-hook! 'web-mode-hook indent-tabs-mode nil)

(after! lsp-mode
  (setq doom-modeline-icon nil)
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

(setq tramp-default-method "ssh"
      tramp-copy-size-limit (* 1024 1024)
      tramp-verbose 0
      remote-file-name-inhibit-locks t
      tramp-use-scp-direct-remote-copying t
      remote-file-name-inhibit-auto-save-visited t)
(with-eval-after-load 'tramp
  (with-eval-after-load 'compile
    (remove-hook 'compilation-mode-hook #'tramp-compile-disable-ssh-controlmaster-options)))

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
          "[/\\\\]logs$"
          "[/\\\\]resources$"
          "[/\\\\]node_modules$"
          "[/\\\\]\\.classpath$"
          "[/\\\\]\\.project$"
          "[/\\\\]\\.settings$"
          "[/\\\\]target$"
          "[/\\\\]build$")))
(with-eval-after-load 'lsp-java
  (add-to-list 'lsp-file-watch-ignored-files
        "[/\\\\][^/\\\\]*\\.\\(json\\|html\\|xml\\|md\\|txt\\|sql\\|sh\\|org\\|yaml\\)$"))

;; (add-hook 'lsp-mode-hook #'lsp-lens-mode)
;; (add-hook 'java-mode-hook #'lsp-java-boot-lens-mode)

(defun my/convert-unicode-in-region (beg end)
  "Convert Unicode escape sequences in the selected region to characters.
Example: \\u6587 -> 文"
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char (point-min))
      (while (re-search-forward "\\\\u\\([0-9a-fA-F]\\{4\\}\\)" nil t)
        (replace-match (string (string-to-number (match-string 1) 16)) t nil)))))

(defun +java-to-xml-mapper ()
  "Jump from a Java mapper file to the corresponding XML mapper file in Spring Boot project."
  (interactive)
  (let* ((java-file (buffer-file-name))
         (project-root (locate-dominating-file java-file "pom.xml")) ; 找到项目根目录
         (java-file-name (file-name-nondirectory java-file)) ; 获取Java文件名
         (base-name (file-name-sans-extension java-file-name)) ; 去掉扩展名
         ;; 构建XML文件路径
         (xml-file (when project-root
                     (expand-file-name
                      (format "src/main/resources/mapper/%s.xml" base-name)
                      project-root)))
         (method-name (thing-at-point 'symbol t)))

    (message "Java file: %s" java-file)
    (message "Project root: %s" project-root)
    (message "Looking for XML: %s" xml-file)

    (cond
     ((not project-root)
      (message "Could not find project root (pom.xml)"))

     ((not (file-exists-p xml-file))
      (message "XML file not found: %s" xml-file))

     (t
      (find-file xml-file)
      (goto-char (point-min))
      (if (and method-name (re-search-forward (format "id=\"%s\"" method-name) nil t))
          (message "Jumped to method: %s" method-name)
        (message "Opened XML file, but method '%s' not found" method-name))))))
