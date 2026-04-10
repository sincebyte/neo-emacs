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
 ;; company-text-face-extra-attributes         '(:weight bold :family "Street Stencil")
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
(add-hook 'emacs-lisp-mode-hook (lambda ()
                                  (rainbow-delimiters-mode)
                                  (setq display-line-numbers                      t)))

(add-hook 'python-ts-mode-hook (lambda ()
                                 (focus-mode nil)
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
            (focus-mode)
            (setq display-line-numbers t)))
(after! lsp-mode
  (set-face-attribute 'lsp-face-highlight-read nil :slant 'normal)
  (set-face-attribute 'lsp-face-highlight-write nil :slant 'normal)
  (setq lsp-modeline-code-actions-enable nil))

(defun my/lsp--execute-command-around (orig-fn command &optional args)
  (if (and (derived-mode-p 'java-mode 'java-ts-mode)
           (string= command "java.completion.onDidSelect"))
      (let ((params (if args
                        (list :command command :arguments args)
                      (list :command command))))
        (lsp-request-async
         "workspace/executeCommand"
         params
         (lambda (_result) nil)
         :error-handler (lambda (_err) nil)))
    (funcall orig-fn command args)))
(advice-add 'lsp-send-execute-command :around #'my/lsp--execute-command-around)

;; when obs capture use company
(with-eval-after-load 'company
  (add-hook 'company-mode-hook
            (lambda ()
              (when (bound-and-true-p lsp-mode)
                (let ((fg (face-foreground 'vertico-current nil t))
                      (bg-tooltip (face-background 'diff-hunk-header nil t))
                      (bg (face-background 'vertico-current nil t)))
                      (setq company-tooltip-maximum-width 90)
                      (set-face-attribute 'company-tooltip nil :underline nil :background bg-tooltip :weight 'normal )
                      (set-face-attribute 'company-tooltip-selection nil :foreground fg :background nil :inherit 'vertico-current)
                      (set-face-attribute 'company-tooltip-mouse nil :foreground fg :background bg :inherit 'vertico-current)
                      (set-face-attribute 'company-tooltip-annotation-selection nil :foreground fg :background bg :inherit 'vertico-current)
                      (set-face-attribute 'company-tooltip-common nil :underline nil :weight 'normal )
                      (set-face-attribute 'company-tooltip-common-selection nil :underline nil :background bg :weight 'normal ))))))

(with-eval-after-load 'lsp-mode
  (apheleia-global-mode -1)
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
        lsp-java-workspace-dir                     (expand-file-name "lsp-java/workspace/" "~")
        lsp-java-workspace-cache-dir               (expand-file-name "lsp-java/workspace/.cache/" "~")
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
        lsp-semantic-highlighting-max-files 10
        lsp-ui-doc-enable nil
        lsp-modeline-code-actions-enable           nil
        lsp-modeline-code-action-icons-enable      nil
        lsp-java-completion-overwrite              nil
        lsp-enable-file-watchers                   nil
        lsp-file-watch-threshold                   2000
        lsp-lens-enable                            t))

(setq
 ;; lsp-java-format-settings-url   (expand-file-name (concat doom-user-dir "neoemacs/eclipse-codestyle.xml"))
 lsp-java-java-path             (concat (getenv "JAVA_25_HOME") "/bin/java")
 lsp-java-server-install-dir    "~/lsp-java/"
 lsp-maven-path                 (concat (getenv "MAVEN_HOME") "/conf/settings.xml")
 lsp-java-jdt-download-url      "http://localhost:8080/jdt-language-server-1.57.0-202602261110.tar.gz"
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


;; (after! lsp-mode
;;   (setq doom-modeline-icon nil)
;;   (setq lsp-disabled-clients '(xmlls)))

;;(add-hook 'java-mode-hook #'(lambda () (add-hook 'post-command-hook #'my-java-hook-function nil t)))
;; (defun my-java-hook-function () (lsp-signature-activate))
;;(add-to-list 'lsp-language-id-configuration '(".*\\.html\\.erb$" .(setq tab-always-indent ‘complete)


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

(defun my/java-ts-mode-for-jdt-decompiled ()
  "对 JDT 反编译缓存中的文件启用 `java-ts-mode'.
`lsp-java--get-filename' 对部分 jdt:// URI 会生成无 .java 后缀的缓存名
（例如 \"Foo(bar)\"），`+lookup/definition' 打开后不会命中 `auto-mode-alist'."
  (when (and buffer-file-name
             (boundp 'lsp-java-workspace-cache-dir)
             lsp-java-workspace-cache-dir
             (not (derived-mode-p 'java-ts-mode 'java-mode)))
    (let ((cache (file-name-as-directory (expand-file-name lsp-java-workspace-cache-dir)))
          (file (expand-file-name buffer-file-name)))
      (when (and (string-prefix-p cache file)
                 (not (string-suffix-p ".metadata" file)))
        (java-ts-mode)))))

(add-hook 'find-file-hook #'my/java-ts-mode-for-jdt-decompiled)

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

(defun +java-mapper-method-name-at-point ()
  "从 Mapper 接口方法声明附近解析方法名。
支持光标在「返回类型 + 方法名」行、仅方法名行、或 @Param 等参数行；
若行内出现 `(` 且非注解行，则取参数列表 `(` 之前的最后一个标识符；
否则取当前行末尾的标识符（如方法名单独成行时）。"
  (save-excursion
    (let ((result nil)
          (attempts 0))
      (while (and (not result) (< attempts 12))
        (setq attempts (1+ attempts))
        (let* ((line (buffer-substring-no-properties
                      (line-beginning-position) (line-end-position)))
               (trimmed (string-trim line)))
          (cond
           ((string-empty-p trimmed)
            (if (> (line-number-at-pos) 1)
                (forward-line -1)
              (setq attempts 100)))
           ((string-match-p "^@\\w" trimmed)
            (if (> (line-number-at-pos) 1)
                (forward-line -1)
              (setq attempts 100)))
           ((string-match-p "^(" trimmed)
            (if (> (line-number-at-pos) 1)
                (forward-line -1)
              (setq attempts 100)))
           (t
            (let ((paren (string-match "(" line)))
              (setq result
                    (if (and paren (not (string-match-p "^\\s*@\\w" line)))
                        (let ((before (string-trim-right (substring line 0 paren))))
                          (when (string-match "\\([a-zA-Z_][a-zA-Z0-9_]*\\)\\s-*\\'" before)
                            (match-string 1 before)))
                      (let ((tr (string-trim-right line)))
                        (when (string-match "\\([a-zA-Z_][a-zA-Z0-9_]*\\)\\s-*\\'" tr)
                          (match-string 1 tr))))))
            (unless result
              (if (> (line-number-at-pos) 1)
                  (forward-line -1)
                (setq attempts 100)))))))
      (or result (thing-at-point 'symbol t)))))

(defun +java--rg-xml-matches (root pattern)
  "在 ROOT 下对 PATTERN 执行 rg，返回 ((FILE LINE PREVIEW) ...) 列表。"
  (let ((root (directory-file-name (expand-file-name root)))
        out)
    (with-temp-buffer
      (let ((status
             (apply #'call-process
                    "rg" nil t nil
                    (append (list "-n" "--no-heading" "--color" "never" "-F"
                                  "-g" "*.xml" "-g" "!**/target/**" "-g" "!**/build/**"
                                  pattern)
                            (list root)))))
        (unless (member status '(0 1))
          (user-error "rg 失败（退出码 %S）" status))
        (when (zerop status)
          (goto-char (point-min))
          (while (not (eobp))
            (let ((l (buffer-substring-no-properties
                      (line-beginning-position) (line-end-position))))
              (when (string-match "\\`\\([^:]+\\):\\([0-9]+\\):\\(.*\\)\\'" l)
                (push (list (expand-file-name (match-string 1 l) root)
                            (string-to-number (match-string 2 l))
                            (match-string 3 l))
                      out)))
            (forward-line 1)))))
    (nreverse out)))

(defun +java-jump-to-mapper-xml (project-root method-name)
  "在 PROJECT-ROOT 的 *.xml 中定位 METHOD-NAME 对应 Mapper。
优先匹配 MyBatis `id='…'`，仅一处时直接 `find-file' 并定位行；多处时用 `completing-read' 选择。
（不使用 `consult-ripgrep'，因其为交互式搜索 UI，不会自动打开文件。）"
  (unless (executable-find "rg" t)
    (user-error "未找到 ripgrep (rg)，请先安装"))
  (let* ((root (expand-file-name project-root))
         (matches
          (or (+java--rg-xml-matches root (format "id=\"%s\"" method-name))
              (+java--rg-xml-matches root (format "id='%s'" method-name))
              (+java--rg-xml-matches root method-name))))
    (unless matches
      (user-error "未在 *.xml 中找到方法 %S（已尝试 id= 与全文）" method-name))
    (if (= (length matches) 1)
        (pcase-let ((`(,file ,line ,_) (car matches)))
          (find-file file)
          (goto-char (point-min))
          (forward-line (1- line))
          (message "已跳转: %s:%d" (file-relative-name file root) line))
      (let* ((pairs
              (mapcar
               (lambda (m)
                 (pcase-let ((`(,file ,line ,preview) m))
                   (cons (format "%s:%d  %s"
                                 (file-relative-name file root) line
                                 (string-trim preview))
                         m)))
               matches))
             (pick (completing-read "Mapper XML: " (mapcar #'car pairs) nil t))
             (chosen (cdr (assoc pick pairs))))
        (unless chosen
          (user-error "未选中有效条目"))
        (pcase-let ((`(,file ,line ,_) chosen))
          (find-file file)
          (goto-char (point-min))
          (forward-line (1- line))
          (message "已跳转: %s:%d" (file-relative-name file root) line))))))

(defun +java-to-xml-mapper ()
  "从 Java Mapper 接口光标处解析方法名，在项目 *.xml 中定位对应 SQL。
单条结果直接跳转；多条时 minibuffer 选择。不使用 consult 的实时搜索界面。"
  (interactive)
  (let* ((java-file (buffer-file-name))
         (project-root
          (or (locate-dominating-file java-file "pom.xml")
              (locate-dominating-file java-file "build.gradle")
              (locate-dominating-file java-file "build.gradle.kts")))
         (method-name (+java-mapper-method-name-at-point)))
    (unless java-file
      (user-error "当前缓冲区未关联文件"))
    (unless project-root
      (user-error "未找到项目根目录（pom.xml / build.gradle）"))
    (unless (and method-name (> (length method-name) 0))
      (user-error "未能解析 Mapper 方法名，请将光标放在方法声明或参数列表附近"))
    (+java-jump-to-mapper-xml (expand-file-name project-root) method-name)))

