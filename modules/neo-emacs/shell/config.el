;;
(defun shell/configOnMac()
  (progn
    (setenv "JAVA_HOME"          "~/soft/jdk/zulu8.58.0.13-ca-jdk8.0.312-macosx_aarch64/zulu-8.jdk/Contents/Home/"     )
    (setenv "JAVA_11_ARM_HOME"   "/Users/van/soft/jdk/zulu11.52.13-ca-jdk11.0.13-macosx_aarch64"     )
    (setenv "JAVA_17_HOME"       "~/soft/jdk/jdk-17.0.6.jdk/Contents/Home"     )
    (setenv "JAVA_21_HOME"       "~/soft/jdk/jdk-21.0.6.jdk/Contents/Home"     )
    (setenv "JAVA_25_HOME"       "~/soft/jdk/jdk-25.0.2.jdk/Contents/Home"     )
    (setenv "JAVA_26_HOME"       "~/soft/jdk/jdk-26.jdk/Contents/Home/"        )
    (setenv "MAVEN_HOME"         "~/soft/apache-maven-3.6.1"                   )
    (setenv "DYLD_LIBRARY_PATH"  "/Applications/Emacs.app/"                    ) ;; rime config path
    (setenv "PATH"       (concat "/Applications/Emacs.app/:" (getenv "PATH" )) ) ;; maven exec, fzf , rg
    (setenv "https_proxy"        "http://vpn.local.com:10887"          )
    (setenv "http_proxy"         "http://vpn.local.com:10887"          )
    (add-to-list 'exec-path      "/Applications/Emacs.app/"                    )
    (add-to-list 'exec-path      "~/.config/emacs/bin/.tmp_npm/bin/")
    (setq shell-file-name (executable-find "bash"))
    (setq quickrun-focus-p t)
    (setq quickrun-timeout-seconds nil)
    (setq vterm-kill-buffer-on-exit t)
    (setq-default vterm-shell "/opt/homebrew/bin/fish")
    (setq-default explicit-shell-file-name "/opt/homebrew/bin/fish")
    ;; (setq-default vterm-shell (executable-find "fish"))
    ;; (setq-default explicit-shell-file-name (executable-find "fish"))
    (map! :n  "SPC r r"  'quickrun-shell                                       )
    (map! :ne "SPC v v" 'projectile-run-vterm                                  )))

(add-hook 'eshell-mode-hook (lambda () (interactive) (setq-local mode-line-format nil)))

;; eshell 不是终端模拟器，只认回车符 \r（见 `eshell-handle-control-codes'）。
;; 现在很多 CLI（node 的 ora / log-update、各种构建工具）重画同一行用的是
;; ANSI「清行」(ESC[2K) +「光标回到行首」(ESC[1G)，eshell 只会把它们删掉而
;; 不会覆盖，于是每一帧都叠加，日志就刷成满屏重复的 "building for
;; production..."。这里把光标复位序列还原成 \r（eshell 会就地覆盖），并丢掉
;; 其余终端控制序列；落在一次读取末尾的 \r 先缓存，等下一段文本到达再拼上
;; （eshell 只有在 \r 后面还有内容时才会擦除上一行）。
(defvar-local my/eshell--pending-cr "")

(defun my/eshell-normalize-control-sequences (string)
  "Translate terminal redraw sequences so eshell overwrites in place."
  (when (and string (> (length string) 0))
    (unless (string= my/eshell--pending-cr "")
      (setq string (concat my/eshell--pending-cr string)
            my/eshell--pending-cr ""))
    ;; ESC[<n>G（光标移到第 n 列）-> \r
    (setq string (replace-regexp-in-string "\033\\[[0-9]*G" "\r" string t t))
    ;; 去掉清行/滚屏/光标移动/私有模式等终端序列，保留 SGR 颜色 (\e[...m)
    (setq string (replace-regexp-in-string
                  "\033\\[[0-9;?]*[ABCDEFHIJKSTfhl]" "" string t t))
    (when (string-suffix-p "\r" string)
      (setq my/eshell--pending-cr "\r"
            string (substring string 0 -1)))
    string))

(with-eval-after-load 'eshell
  (add-hook 'eshell-preoutput-filter-functions
            #'my/eshell-normalize-control-sequences)
  (add-hook 'eshell-pre-command-hook
            (lambda () (setq my/eshell--pending-cr ""))))

;; win fzf fg exec Home dir
(defun shell/configOnWin()
  (progn
    (setenv "JAVA_HOME"     "c:/Java/jdk-17/"                     )
    (setenv "JAVA_17_HOME"  "c:/Java/jdk-17/"                     )
    (setenv "MAVEN_HOME"    "c:/Java/apache-maven"                )
    (setenv "https_proxy"   "http://vpn.local.com:10887"          )
    (setenv "http_proxy"    "http://vpn.local.com:10887"          )
    (add-to-list 'exec-path (concat (getenv "MAVEN_HOME") "/bin") ) ;; maven exec
    (map! :n  "SPC r r" 'quickrun-shell                           )
    (map! :ne "SPC v v" 'project-eshell                           )))


(if (eq system-type 'windows-nt)
    (progn (shell/configOnWin))
  (progn (shell/configOnMac)))

(defun my/vterm-with-dir-and-file-name ()
  (interactive)
  (let* ((dir (file-name-nondirectory
               (directory-file-name default-directory)))
         (file (when buffer-file-name
                 (file-name-nondirectory buffer-file-name)))
         (file-part (or file "no-file"))
         (bufname (format "*vterm: %s/%s*" dir file-part))
         (existing (get-buffer bufname)))
    (if existing
        (switch-to-buffer existing)
      (let ((default-directory default-directory))
        (vterm bufname)))))

;; eshell binding
(defun shell/openAndResetCursor ()
  (interactive)
  (progn
    (my/vterm-with-dir-and-file-name)
    (run-with-idle-timer
     0.1 nil 'vterm-reset-cursor-point)))

(defun my/force-hide-vterm-modeline ()
  "强制隐藏 vterm 的 modeline"
  (setq mode-line-format nil)
  (setq mode-line-cache nil))

(add-hook 'vterm-mode-hook #'evil-collection-vterm-escape-stay)
(add-hook 'vterm-mode-hook (lambda () 
  (add-hook 'after-change-major-mode-hook #'my/force-hide-vterm-modeline nil t)))
(add-hook 'buffer-list-update-hook (lambda ()
  (when (and (derived-mode-p 'vterm-mode) (not (eq mode-line-format nil)))
    (my/force-hide-vterm-modeline))))

;; 毛玻璃（lr-macos-glass）会按 `ns-alpha-glyphs' 把"非默认字形背景"整体
;; 半透明化，于是 fish 提示符的色块也被一起透明，看起来发灰。
;; 原生层（ns-opaque-background-faces.patch）对带 `:ns-opaque-background t'
;; 的 face 跳过 alpha。vterm 的每个格子是 C 模块动态生成的匿名 face（带
;; `:background'），elisp 拿不到，所以在 `vterm--insert' 插入前把该属性补上。
;; 只对"有显式背景色"的格子生效，终端默认底色仍随玻璃半透明。
(defun my/vterm-opaque-cell-background (string)
  "给 STRING 上带 `:background' 的 `font-lock-face' 补 `:ns-opaque-background t'。"
  (when (and (stringp string) (> (length string) 0))
    (let ((face (get-text-property 0 'font-lock-face string)))
      (when (and (listp face)
                 (plist-member face :background)
                 (not (plist-member face :ns-opaque-background)))
        (put-text-property 0 (length string) 'font-lock-face
                           (plist-put (copy-sequence face)
                                      :ns-opaque-background t)
                           string))))
  string)

(defun my/vterm-opaque-insert (orig &rest content)
  "围绕 `vterm--insert'：把色块格子标记为不透明，绕过毛玻璃 alpha。"
  (dolist (arg content)
    (my/vterm-opaque-cell-background arg))
  (apply orig content))

(with-eval-after-load 'vterm
  (advice-add 'vterm--insert :around #'my/vterm-opaque-insert))

(advice-add 'set-window-vscroll :after
  (defun me/vterm-toggle-scroll (&rest _)
    (when (eq major-mode 'vterm-mode)
      (if (> (window-end) (buffer-size))
          (when vterm-copy-mode (vterm-copy-mode-done nil))
        (vterm-copy-mode 1)))))

;; Remap C-k and C-j in eshell to use evil-scroll instead of default prompt navigation
;; These bindings will work in evil normal mode in eshell
(defun my-eshell-override-keys ()
  "Override eshell key bindings for evil normal mode."
  (define-key eshell-mode-map (kbd "C-k") nil) ; Remove old binding for eshell-previous-prompt
  (define-key eshell-mode-map (kbd "C-j") nil) ; Remove old binding for eshell-next-prompt
  (evil-define-key 'normal eshell-mode-map (kbd "C-k") #'evil-scroll-up)
  (evil-define-key 'normal eshell-mode-map (kbd "C-j") #'evil-scroll-down))

(with-eval-after-load 'eshell
  (with-eval-after-load 'evil
    (add-hook 'eshell-mode-hook #'my-eshell-override-keys)))

(defun my-vterm-evil-cursor ()
  (when (derived-mode-p 'vterm-mode)
    (setq cursor-type
          (if (evil-insert-state-p) 'bar 'box))))
(add-hook 'post-command-hook #'my-vterm-evil-cursor)

(after! evil-collection
  (defun my/evil-collection-eshell-interrupt-process (&rest _)
    "Interrupt eshell process; keep *eshell-quickrun* editable.

quickrun--eshell-post-hook sets read-only after command finishes, which
breaks eshell-interrupt-process and evil-insert."
    (interactive)
    (let ((inhibit-read-only t))
      (when (string= (buffer-name) "*eshell-quickrun*")
        (when (fboundp 'quickrun--eshell-finish)
          (quickrun--eshell-finish))
        (use-local-map eshell-mode-map))
      (read-only-mode -1)
      (eshell-interrupt-process))
    (evil-normal-state 1))

  (advice-add 'evil-collection-eshell-interrupt-process
              :override #'my/evil-collection-eshell-interrupt-process))
