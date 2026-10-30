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

;; vterm 把每个格子的颜色写成 `font-lock-face' 文本属性（vterm-module.c 里
;; Qface 就是它）。但 Emacs 只在 Font Lock mode 开启时才认这个属性（见
;; Emacs Lisp 手册 "Special Properties"），而 vterm buffer 里
;; `font-lock-mode' 一直是关的（vterm-mode 只设了 `font-lock-defaults'，
;; 用来禁止自动 fontification）。结果就是终端里整个提示符都退回默认前景色。
;; 这里把它同时镜像到 `face'：Font Lock 开或关，颜色都能正常显示。
;;
;; 另外，毛玻璃（lr-macos-glass）会按 `ns-alpha-glyphs' 把"非默认字形背景"
;; 整体半透明化，于是 fish 提示符的色块也被一起透明，看起来发灰。
;; 原生层（ns-opaque-background-faces.patch）对带 `:ns-opaque-background t'
;; 的 face 跳过 alpha。vterm 的每个格子是 C 模块动态生成的匿名 face（带
;; `:background'），elisp 拿不到，所以在 `vterm--insert' 插入前把该属性补上。
;; 只对"有显式背景色"的格子生效，终端默认底色仍随玻璃半透明。
(defun my/vterm-normalize-cell-face (string)
  "把 STRING 的格子 face 镜像到 `face'，并给色块补不透明标记。"
  (when (and (stringp string) (> (length string) 0))
    (let ((face (get-text-property 0 'font-lock-face string))
          (len (length string)))
      (when (listp face)
        (when (and (plist-member face :background)
                   (not (plist-member face :ns-opaque-background)))
          (setq face (plist-put (copy-sequence face)
                                :ns-opaque-background t))
          (put-text-property 0 len 'font-lock-face face string))
        (put-text-property 0 len 'face face string))))
  string)

(defun my/vterm-normalize-insert (orig &rest content)
  "围绕 `vterm--insert'：补齐格子颜色与不透明度。"
  (dolist (arg content)
    (my/vterm-normalize-cell-face arg))
  (apply orig content))

(with-eval-after-load 'vterm
  (advice-add 'vterm--insert :around #'my/vterm-normalize-insert))

;;; vterm：C-k / C-j 翻历史时暂停输出 ----------------------------------------
;; 往上翻历史时，子进程的输出仍会继续插入，把刚翻到的地方不断顶走。这里用
;; 终端流控解决：`C-k'（`evil-scroll-up'）把窗口滚离底部时 `vterm-send-stop'
;; （pty 的 TCOOFF，子进程会阻塞而不会丢输出）；`C-j' 翻回底部、或 `G'
;; （`vterm-reset-cursor-point'）回到缓冲区末尾时再 `vterm-send-start'
;; （TCOON）恢复。判断直接挂在 `evil-scroll-up' / `evil-scroll-down' 这两个
;; 命令上，而不是在 `post-command-hook' 里比对 `this-command'；鼠标滚轮、
;; `scroll-up-command' 之类完全不参与。
(defvar-local my/vterm-output-paused nil
  "非 nil 表示当前 vterm 的输出已被 `vterm-send-stop' 暂停。")

(defvar-local my/vterm--last-scroll-info nil
  "最近一次 C-k / C-j 的判定结果，排查问题时用。")

(defconst my/vterm-escape-commands '(evil-force-normal-state
                                     evil-exit-visual-state
                                     evil-normal-state)
  "按 ESC 时 evil 会执行的命令。
这些命令之后要顺手收起 vterm 的选区和复制提示。")

(defun my/vterm--at-bottom-p ()
  "当前 buffer 的窗口是否已显示到缓冲区末尾。"
  (when-let* ((win (get-buffer-window (current-buffer) t)))
    (>= (window-end win t) (point-max))))

(defun my/vterm--pause-output ()
  "暂停当前 vterm 的输出（已暂停则什么也不做）。"
  (unless my/vterm-output-paused
    (setq my/vterm-output-paused t)
    (vterm-send-stop)
    (message "vterm: 已暂停输出，C-j 或 G 回到底部恢复")))

(defun my/vterm--resume-output ()
  "恢复当前 vterm 的输出（未暂停则什么也不做）。
在 `vterm-copy-mode' 里回到底部时顺手退出 copy-mode，由 vterm 自己
`vterm-send-start'，输出重新显示。"
  (when my/vterm-output-paused
    (setq my/vterm-output-paused nil)
    (if (bound-and-true-p vterm-copy-mode)
        (vterm-copy-mode -1)
      (vterm-send-start))
    (message "vterm: 恢复输出")))

(defun my/vterm--after-scroll-up ()
  "C-k 执行完后的判定：离开底部就暂停输出。"
  (when (derived-mode-p 'vterm-mode)
    (let ((at-bottom (my/vterm--at-bottom-p)))
      (setq my/vterm--last-scroll-info
            (list :command this-command :at-bottom at-bottom
                  :time (current-time)))
      (unless at-bottom
        (my/vterm--pause-output)))))

(defun my/vterm--after-scroll-down ()
  "C-j 执行完后的判定：回到底部就恢复输出。"
  (when (derived-mode-p 'vterm-mode)
    (let ((at-bottom (my/vterm--at-bottom-p)))
      (setq my/vterm--last-scroll-info
            (list :command this-command :at-bottom at-bottom
                  :time (current-time)))
      (when at-bottom
        (my/vterm--resume-output)))))

(defun my/vterm--scroll-up-advice (orig &rest args)
  "按 C-k（`evil-scroll-up'）之后：离开底部就暂停输出。
`evil-scroll-up' 在 buffer 顶部会 signal `beginning-of-buffer'，这里吞掉，
保证判定照常执行。"
  (if (not (derived-mode-p 'vterm-mode))
      (apply orig args)
    (condition-case nil
        (apply orig args)
      (beginning-of-buffer nil))
    (my/vterm--after-scroll-up)))

(defun my/vterm--scroll-down-advice (orig &rest args)
  "按 C-j（`evil-scroll-down'）之后：回到底部就恢复输出。
`evil-scroll-down' 在 buffer 末尾会 signal `end-of-buffer'（这正是按 C-j
回到底部的情形），吞掉它，判定照常执行。"
  (if (not (derived-mode-p 'vterm-mode))
      (apply orig args)
    (condition-case nil
        (apply orig args)
      (end-of-buffer nil))
    (my/vterm--after-scroll-down)))

(with-eval-after-load 'evil
  (advice-add 'evil-scroll-up :around #'my/vterm--scroll-up-advice)
  (advice-add 'evil-scroll-down :around #'my/vterm--scroll-down-advice))

(defun my/vterm--follow-output ()
  "在 vterm 里处理 G 与 ESC。
G（`vterm-reset-cursor-point'）回到缓冲区末尾时恢复输出；ESC 时取消
选区并清掉“刚复制”的提示。C-k / C-j 见上面的 advice。"
  (when (derived-mode-p 'vterm-mode)
    (cond
     ;; ESC：取消仍活动的选区，并清掉“刚复制”的提示。
     ;; 放在 copy-mode 判断之前，copy-mode 里按 ESC 也要生效。
     ((memq this-command my/vterm-escape-commands)
      (deactivate-mark t)
      (my/vterm-clear-copied-region))
     ;; G：直接回到底部，恢复输出。
     ((and my/vterm-output-paused
           (eq this-command 'vterm-reset-cursor-point))
      (my/vterm--resume-output)))))

(defun my/vterm--setup-follow-output ()
  "在当前 vterm buffer 中启用输出跟随/暂停。
`my/vterm-output-paused' 由 `defvar-local' 自动初始化为 nil，重载配置时
不会把正在暂停的 buffer 当成已恢复。"
  (add-hook 'post-command-hook #'my/vterm--follow-output nil t))

(add-hook 'vterm-mode-hook #'my/vterm--setup-follow-output)

;; 配置重载前已经开着的 vterm 不会重跑 mode hook，这里补一次。
(dolist (buf (buffer-list))
  (with-current-buffer buf
    (when (derived-mode-p 'vterm-mode)
      (my/vterm--setup-follow-output))))

;;; vterm：保留“刚复制过哪一段”的提示 --------------------------------------
;; vterm 里每次按键都会 `deactivate-mark'（见 `vterm-send-key'），选区高亮随即
;; 消失，但 kill-ring / 剪贴板里的内容其实还在。这里复制后额外画一块 overlay，
;; 直到下一次复制或手动 `my/vterm-clear-copied-region' 才清除，方便核对。
(defface my/vterm-copied-region
  '((t :inherit region :extend t))
  "vterm 中最近一次复制区域的提示底色。")

;; 毛玻璃（lr-macos-glass）按 `ns-alpha-glyphs' 把选区/高亮等字形底色整体
;; 半透明化；原生层会跳过带 `:ns-opaque-background t' 的 face，让提示底色
;; 保持清晰。未打该补丁的构建会在这里报错，忽略即可。
(ignore-errors
  (set-face-attribute 'my/vterm-copied-region nil :ns-opaque-background t))

(defvar-local my/vterm--copied-overlay nil
  "标记最近一次 vterm 复制区域的 overlay。")

(defun my/vterm-clear-copied-region ()
  "清除 vterm 中最近一次复制的提示底色。"
  (interactive)
  (when (overlayp my/vterm--copied-overlay)
    (delete-overlay my/vterm--copied-overlay))
  (setq my/vterm--copied-overlay nil))

(defun my/vterm--highlight-copied-region (beg end)
  "用 overlay 标出 vterm 中刚复制的 BEG..END。"
  (when (and (derived-mode-p 'vterm-mode)
             (integer-or-marker-p beg)
             (integer-or-marker-p end)
             (< beg end))
    (my/vterm-clear-copied-region)
    (let ((ov (make-overlay beg end)))
      (overlay-put ov 'face 'my/vterm-copied-region)
      (overlay-put ov 'priority 1000)
      (overlay-put ov 'evaporate t)
      (setq my/vterm--copied-overlay ov))))

(defun my/vterm--copy-region-advice (orig beg end &optional region)
  "`kill-ring-save' 之后标出复制区域（含 `vterm-copy-mode-done' 的复制）。"
  (if (derived-mode-p 'vterm-mode)
      (let* ((use-region (and region (use-region-p)))
             (start (if use-region (region-beginning) beg))
             (stop  (if use-region (region-end) end)))
        (prog1 (funcall orig beg end region)
          (my/vterm--highlight-copied-region start stop)))
    (funcall orig beg end region)))

(advice-add 'kill-ring-save :around #'my/vterm--copy-region-advice)

;; 鼠标拖选（`select-active-regions' 已经把它放进剪贴板）之后直接敲键时，
;; mark 会被 `vterm-send-key' 里的 `deactivate-mark' 取消；在取消前把刚才的
;; 选区记下来，照样保留提示底色。
(defun my/vterm--remember-region-before-deactivate ()
  "在 vterm 中选区被取消时，保留刚才选中范围的提示底色。"
  (when (and (derived-mode-p 'vterm-mode)
             (mark t))
    (let ((beg (min (point) (mark t)))
          (end (max (point) (mark t))))
      (when (< beg end)
        (my/vterm--highlight-copied-region beg end)))))

(add-hook 'deactivate-mark-hook #'my/vterm--remember-region-before-deactivate)

;; 开始新选区时先清掉上一次“刚复制”的提示，避免两块底色叠在一起。
(defun my/vterm--clear-copied-region-on-activate ()
  "在 vterm 中开始新选区时清除上一次的复制提示。"
  (when (derived-mode-p 'vterm-mode)
    (my/vterm-clear-copied-region)))

(add-hook 'activate-mark-hook #'my/vterm--clear-copied-region-on-activate)

(defun my/vterm--evil-yank-advice (orig beg end &rest args)
  "evil 的 yank 之后标出复制区域。"
  (prog1 (apply orig beg end args)
    (my/vterm--highlight-copied-region beg end)))

(with-eval-after-load 'evil
  (advice-add 'evil-yank :around #'my/vterm--evil-yank-advice))

;; vterm-copy-mode 里 `use-local-map' 会把 vterm-mode-map 摘掉，若此时还在
;; insert state，按 j/k 会变成往只读缓冲区里自插入（报错并顺手清掉选区）。
;; 进入 copy mode 时统一切到 normal state，j/k 才是“移动/扩展选区”。
(defun my/vterm--copy-mode-changed ()
  "同步 `vterm-copy-mode' 与 `my/vterm-output-paused'。
vterm 进入 copy-mode 时会 `vterm-send-stop'，退出时会 `vterm-send-start'，
这里跟着记录，免得两套暂停状态互相打脸。"
  (when (derived-mode-p 'vterm-mode)
    (setq my/vterm-output-paused (and vterm-copy-mode t))
    (when (and vterm-copy-mode
               (bound-and-true-p evil-mode))
      (evil-normal-state))))

(with-eval-after-load 'vterm
  (add-hook 'vterm-copy-mode-hook #'my/vterm--copy-mode-changed))

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
