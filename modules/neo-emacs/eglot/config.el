;;; neoemacs/eglot/config.el -*- lexical-binding: t; -*-
;;;
(setenv "XMLLINT_INDENT" "    ")
(use-package xml-format
  :demand t
  :defer t
  :after nxml-mode)

(use-package kind-icon
  :ensure t
  :after corfu
  :custom
  (kind-icon-blend-background t)
  :config
  (setq kind-icon-use-icons  nil
        kind-icon-blend-background nil
        corfu-count          7    )
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

(after! corfu
  (corfu-popupinfo-mode -1)              ; 强制禁用
  (set-face-attribute 'corfu-current nil :weight 'normal)
  (set-face-attribute 'corfu-default nil :background (face-background 'corfu-border nil t))
  (set-face-attribute 'corfu-border nil :background (face-background 'org-mode-line-clock nil t))
  (add-to-list 'corfu--frame-parameters '(vertical-scroll-bars . nil))
  (setq corfu-popupinfo-delay nil        ; 禁止延迟触发
        corfu-popupinfo-hide t           ; 隐藏可能残留的弹窗
        corfu-auto-delay          0.1
        corfu-auto-prefix         1
        corfu-right-margin-width  0.3
        corfu-border-width        2
        corfu-auto                t
        corfu-preselect           'first
        corfu-bar-width           0.5
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

(setq-default flymake-no-changes-timeout 30)

(defvar +eglot-java-jdt-cache-dir-name ".eglot-java-jdt-cache"
  "项目根目录下缓存 JDT 反编译/第三方类源码的子目录名。")

(defun +eglot-java--make-path (root-dir &rest path-elements)
  "从 ROOT-DIR 与 PATH-ELEMENTS 拼出路径。"
  (let ((new-path (expand-file-name root-dir)))
    (dolist (p path-elements)
      (setq new-path (concat (file-name-as-directory new-path) p)))
    new-path))

(defun +eglot-java--plist-merge (&rest plists)
  "合并多个 property list，后者覆盖前者。"
  (let ((rtn (copy-sequence (pop plists))))
    (while plists
      (let ((ls (pop plists)))
        (while ls
          (setq rtn (plist-put rtn (pop ls) (pop ls))))))
    rtn))

(defun +eglot-java--jdt-server-p (server)
  "判断 SERVER 是否为 Java JDT language server。"
  (when-let ((languages (eglot--languages server)))
    (or (assoc 'java-mode languages)
        (assoc 'java-ts-mode languages))))

(defun +eglot-java--java-home ()
  (when-let ((home (or (getenv "JAVA_25_HOME")
                       (getenv "JAVA_HOME")
                       (ignore-errors
                         (expand-file-name ".." (file-name-directory
                                                 (file-chase-links (executable-find "javac"))))))))
    (expand-file-name home)))

(defun +eglot-java--maven-user-settings ()
  (let ((maven-home (getenv "MAVEN_HOME")))
    (when maven-home
      (expand-file-name "conf/settings.xml" maven-home))))

(defun +eglot-java-extra-init-options (_server)
  "JDT LS 初始化选项：支持反编译类内容与 Maven 自动下载 sources。"
  (let* ((maven `(:downloadSources t
                   ,@(when-let ((settings (+eglot-java--maven-user-settings)))
                       `(:userSettings ,settings))))
         (java `(:configuration (:maven ,maven)
                 ,@(when-let ((home (+eglot-java--java-home)))
                     `(:home ,home)))))
    `(:extendedClientCapabilities
      (:classFileContentsSupport t)
      :settings
      (:java ,java))))

(defun +eglot-java--merge-settings (base extra)
  "深度合并 JDT `:settings'，保留 BASE 中已有的非 Java 配置。"
  (let ((base-settings (or base '()))
        (extra-settings (or extra '())))
    (+eglot-java--plist-merge
     base-settings
     (list :java
           (+eglot-java--plist-merge
            (plist-get base-settings :java)
            (plist-get extra-settings :java))))))

(defun +eglot-java--ht-to-plist (ht)
  (let (plist)
    (maphash (lambda (k v) (push v plist) (push k plist)) ht)
    (nreverse plist)))

(defun +eglot-java--initialization-options-advice (orig server)
  (let* ((base (funcall orig server))
         (base-plist (if (hash-table-p base) (+eglot-java--ht-to-plist base) base))
         (extra (+eglot-java-extra-init-options server)))
    (if (+eglot-java--jdt-server-p server)
        (+eglot-java--plist-merge
         base-plist
         (list :extendedClientCapabilities
               (plist-get extra :extendedClientCapabilities)
               :settings
               (+eglot-java--merge-settings
                (plist-get base-plist :settings)
                (plist-get extra :settings))))
      base)))

(defun +eglot-java--find-server ()
  (eglot-current-server))

(defun +eglot-java--jdt-cache-dir ()
  (when-let* ((project (or (project-current)
                            (and-let ((server (+eglot-java--find-server)))
                              (eglot--project server))))
              (root (project-root project)))
    (expand-file-name +eglot-java-jdt-cache-dir-name root)))

(defun +eglot-java--jdt-uri-handler (_operation &rest args)
  "处理 Eclipse JDT LS 的 `jdt://' URI，拉取并缓存第三方/反编译类源码。"
  (let* ((uri (car args))
         (cache-dir (or (+eglot-java--jdt-cache-dir)
                        (locate-user-emacs-file +eglot-java-jdt-cache-dir-name)))
         (rel-path
          (save-match-data
            (when (string-match "jdt://contents/\\([^/]+\\)/\\(.*\\)\\.\\(?:class\\|java\\)\\?" uri)
              (format "%s.java"
                      (replace-regexp-in-string "/" "." (match-string 2 uri) t t))))))
    (unless rel-path
      (error "无法解析 JDT URI: %s" uri))
    (let ((source-file (expand-file-name (+eglot-java--make-path cache-dir rel-path))))
      (unless (file-readable-p source-file)
        (let* ((server (+eglot-java--find-server))
               (content (if server
                            (jsonrpc-request server :java/classFileContents (list :uri uri))
                          (user-error "未找到 JDT language server，请先 `M-x eglot'")))
               (metadata-file (format "%s.%s.metadata"
                                      (file-name-directory source-file)
                                      (file-name-base source-file))))
          (make-directory (file-name-directory source-file) t)
          (with-temp-file source-file (insert content))
          (with-temp-file metadata-file (insert uri))))
      source-file)))

(defun +eglot-java--setup-jdt-uri-handler ()
  (unless (assoc "\\`jdt://" file-name-handler-alist)
    (add-to-list 'file-name-handler-alist '("\\`jdt://" . +eglot-java--jdt-uri-handler))))

(defun +eglot-java-ts-mode-for-jdt-decompiled ()
  "对 JDT 反编译缓存中的文件启用 `java-ts-mode'。"
  (when (and buffer-file-name
             (not (derived-mode-p 'java-ts-mode 'java-mode)))
    (let ((file (expand-file-name buffer-file-name))
          (caches
           (delq nil
                 (list (when-let ((dir (+eglot-java--jdt-cache-dir))) dir)
                       (expand-file-name "lsp-java/workspace/.cache/" "~")
                       (when-let* ((project (project-current))
                                   (root (project-root project)))
                         (expand-file-name ".eglot-java" root))))))
      (when (cl-some
             (lambda (cache)
               (let ((cache (file-name-as-directory (expand-file-name cache))))
                 (and (string-prefix-p cache file)
                      (not (string-suffix-p ".metadata" file)))))
             caches)
        (java-ts-mode)))))

(defun +eglot-java--execute-workspace-edit (server command arguments)
  "Eclipse JDT 将 workspace edit 放在 arguments 中返回，需单独处理。"
  (mapc (lambda (edit) (eglot--apply-workspace-edit server edit command))
        arguments))

(defun +eglot-java--workspace-configuration (server)
  (when (+eglot-java--jdt-server-p server)
    (let* ((home (+eglot-java--java-home))
           (maven `(:downloadSources t
                    ,@(when-let ((settings (+eglot-java--maven-user-settings)))
                        `(:userSettings ,settings))))
           (java-config `(:import (:maven (:enabled t) :gradle (:enabled t))
                          :autobuild (:enabled t)
                          :configuration (:maven ,maven)
                          ,@(when home `(:home ,home)))))
      `(:java ,java-config))))

(defun +eglot-java--build-workspace (server)
  (when (+eglot-java--jdt-server-p server)
    (ignore-errors
      (jsonrpc-request server :java/buildWorkspace nil))))

(after! eglot
  (cl-defmethod eglot-execute-command ((server eglot-lsp-server)
                                       (command (eql java.apply.workspaceEdit))
                                       arguments)
    (+eglot-java--execute-workspace-edit server command arguments))
  (advice-add #'eglot-initialization-options :around #'+eglot-java--initialization-options-advice)
  (+eglot-java--setup-jdt-uri-handler)
  (setq eglot-workspace-configuration #'+eglot-java--workspace-configuration)
  (add-hook 'eglot-connect-hook #'+eglot-java--build-workspace)
  (define-key doom-leader-map (kbd "c f") #'eglot-format))

(defun +java-mapper-method-name-at-point ()
  "从 Mapper 接口方法声明附近解析方法名。"
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
  "在 PROJECT-ROOT 的 *.xml 中定位 METHOD-NAME 对应 Mapper。"
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
  "从 Java Mapper 接口光标处解析方法名，在项目 *.xml 中定位对应 SQL。"
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
(defun my-java-mode-setup ()
  (eglot-ensure)
  (focus-mode 1)
  (setq display-line-numbers t))

(add-hook 'java-ts-mode-hook #'my-java-mode-setup)
(add-hook 'java-mode-hook #'my-java-mode-setup)

;; ;; ;; java key setting
(map! :nve "; c"     'comment-line                        )
(map! :ne  "; r"     'string-inflection-java-style-cycle  )
(map! :ne "SPC c I"  #'eglot-find-implementation )
(map! :map global-map "s-n" nil)
(unbind-key "c f" doom-leader-map)
(map! :after eglot
      :map eglot-mode-map
      :n "SPC f b" #'eglot-format-buffer
      :v "SPC c f" #'eglot-format
      :n "; i"     #'eglot-code-action-organize-imports
      :n "SPC t s" #'eglot)

(add-hook 'find-file-hook #'+eglot-java-ts-mode-for-jdt-decompiled)
(after! eglot
    (setq eglot-sync-connect              8
          eldoc-echo-area-use-multiline-p nil))
