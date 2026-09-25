;;; Ensure Common Lisp extensions and sequence library are available
(require 'cl-lib)
(require 'seq)

(server-start)
(setq custom-file null-device)
;; 按屏幕分辨率自动匹配窗口位置与大小 (像素单位)
;; macOS 上 Emacs 报告的是逻辑分辨率(即系统"Looks like"值):
;;   1K = 1920x1080, 2K = 2560x1440, 4K = 3840x2160
;; 记录方法: emacsclient -e '(list (frame-parameter nil (quote left)) (frame-parameter nil (quote top)) (frame-pixel-width) (frame-pixel-height))'
;; 注意: 不要用 frame-resize-pixelwise, macOS 上开启后帧缩放会卡死
(defun my/detect-display-class ()
  "根据当前主屏逻辑分辨率返回类别: 1k / 2k / 4k / other."
  (let ((width (display-pixel-width))
        (height (display-pixel-height)))
    (cond ((and (>= width 3800) (>= height 2100)) '4k)
          ((and (>= width 2500) (>= height 1400)) '2k)
          ((and (>= width 1900) (>= height 1050)) '1k)
          (t 'other))))

(defvar my/window-geometry-table
  '(    (1k :left 172 :top 89 :width 1322 :height 806)
    (2k nil)   ; TODO 2K 显示器实测后填写
    (4k nil))  ; TODO 4K 显示器实测后填写
  "不同分辨率下的窗口几何参数(像素).
  :left/:top 为窗口左上角坐标, :width/:height 为内容区尺寸.
  条目为 nil 时回退为最大化窗口.")

(defun my/apply-window-geometry ()
  "探测当前屏幕分辨率, 自动应用匹配的窗口位置与大小."
  (when (display-graphic-p)
    (let* ((class (my/detect-display-class))
           (plist (cdr (assq class my/window-geometry-table)))
           (width (and plist (plist-get plist :width)))
           (height (and plist (plist-get plist :height))))
      (if (and width height)
          (progn
            (set-frame-position nil (plist-get plist :left) (plist-get plist :top))
            (set-frame-size nil width height t))
        (add-to-list 'default-frame-alist '(fullscreen . maximized))))))
(add-hook 'window-setup-hook #'my/apply-window-geometry)
(setq ns-use-proxy-icon nil)           ; 禁用代理图标
(setq frame-title-format '("")         ; 清空标题格式
      icon-title-format '(""))         ; 最小化时同样清空
;; full screen
;; (when (display-graphic-p)
;;   (add-hook 'window-setup-hook #'toggle-frame-fullscreen))
;; 普通字体设置
(if (eq system-type 'windows-nt)
    (progn (set-selection-coding-system 'utf-8)
           (setq doom-font (font-spec :family "Kode Mono" :size 24)
                 cjk-font "汉仪新人文宋W"
                 cjk-font-size 26))
  (progn (set-selection-coding-system 'utf-16le-dos)
         ;; (setq doom-font (font-spec :family "Kode Mono" :size 16 )
         (setq doom-font (font-spec :family "JetBrains Mono" :size 17 )
               cjk-font "方正悠宋+ GBK" 
               cjk-font-size 20)))

;; 设置大字体和可变字体
(setq doom-big-font (font-spec :family "JetBrains Mono" :size 20 )
      doom-variable-pitch-font (font-spec :family "JetBrains Mono"))
(defun my/setup-big-cjk-fonts ()
  "Setup CJK fonts for Doom Big Font Mode."
  (if (bound-and-true-p doom-big-font-mode) 
  (dolist (charset '(kana han symbol cjk-misc bopomofo))
    (set-fontset-font t charset (font-spec :family "方正悠宋+ GBK" :size 24 )))
  (dolist (charset '(kana han symbol cjk-misc bopomofo))
    (set-fontset-font t charset (font-spec :family "方正悠宋+ GBK" :size 20 )))))
(add-hook 'doom-big-font-mode-hook #'my/setup-big-cjk-fonts)

;; Set the padding between lines
;; (defvar line-padding 0.8)
;; (defun add-line-padding ()
;;   "Add extra padding between lines"

;;   ; remove padding overlays if they already exist
;;   (let ((overlays (overlays-at (point-min))))
;;     (while overlays
;;       (let ((overlay (car overlays)))
;;         (if (overlay-get overlay 'is-padding-overlay)
;;             (delete-overlay overlay)))
;;       (setq overlays (cdr overlays))))

;;   ; add a new padding overlay
;;   (let ((padding-overlay (make-overlay (point-min) (point-max))))
;;     (overlay-put padding-overlay 'is-padding-overlay t)
;;     (overlay-put padding-overlay 'line-spacing (* .1 line-padding))
;;     (overlay-put padding-overlay 'line-height (+ 1 (* .1 line-padding))))
;;   (setq mark-active nil))

;; (add-hook 'buffer-list-update-hook 'add-line-padding)
;;

;; 设置不同模式下的字体
(defun my-set-font-for-mode ()
  (if (bound-and-true-p doom-big-font-mode)
    ;; 大号字
    (cond
     ((derived-mode-p 'python-mode)
      (setq-local face-remapping-alist '((default (:family "Fira Code" :height 210) default))))
     ((derived-mode-p 'company-mode)
      (setq-local face-remapping-alist '((default (:family "Fira Code" :height 210) default))))
     ((derived-mode-p 'java-ts-mode)
      (setq-local face-remapping-alist '((default (:family "Noto Sans Mono" :height 210) default))))
     ((derived-mode-p 'sparkweather-mode)
      (setq-local face-remapping-alist '((default (:family "SF Mono" :height 210) default))))
     ((derived-mode-p 'vterm-mode)
      (setq-local face-remapping-alist '((default (:family "Kode Mono" :height 210) default)))))
    ;; 小号字
    (cond
     ((derived-mode-p 'python-mode)
      (setq-local face-remapping-alist '((default (:family "Fira Code" :height 170) default))))
     ((derived-mode-p 'company-mode)
      (setq-local face-remapping-alist '((default (:family "Fira Code" :height 170) default))))
     ((derived-mode-p 'java-ts-mode)
      (setq-local face-remapping-alist '((default (:family "Noto Sans Mono" :height 170) default))))
     ((derived-mode-p 'sparkweather-mode)
      (setq-local face-remapping-alist '((default (:family "SF Mono" :height 160) default))))
     ((derived-mode-p 'vterm-mode)
      (setq-local face-remapping-alist '((default (:family "Kode Mono" :height 160) default)))))))

(add-hook 'after-change-major-mode-hook #'my-set-font-for-mode)

(defun my/fix-line-number-face ()
  (set-face-attribute 'line-number nil :family "JetBrains Mono" :weight 'normal :slant 'italic )
  (let* ((hl-bg (face-attribute 'hl-line :background nil t))
         (bg (if (memq hl-bg '(unspecified nil))
                 (or (face-attribute 'default :background nil t) "#222225")
               hl-bg)))
    (set-face-attribute 'line-number-current-line nil
                        :family "JetBrains Mono" :weight 'normal :slant 'italic
                        :background bg)))
(add-hook 'display-line-numbers-mode-hook #'my/fix-line-number-face)

;; 设置 minibuffer 中的字体
(defun my-set-font-for-minibuffer ()
  (if (bound-and-true-p doom-big-font-mode)
      (setq-local face-remapping-alist '((default (:family "M PLUS Code Latin 50" :height 210) default)))
    (setq-local face-remapping-alist '((default (:family "M PLUS Code Latin 50" :height 170) default))))
  (redraw-frame (selected-frame)))
(add-hook 'minibuffer-setup-hook #'my-set-font-for-minibuffer)

;; (progn (set-selection-coding-system 'utf-16le-dos)
;;        (setq doom-font (font-spec :family "Kode Mono" :size 20 )
;;              cjk-font "仓耳今楷01-9128"
;;              cjk-font-size 24)))

(defun init-cjk-fonts()
  (when (display-graphic-p) (eq (framep (selected-frame)) 'x)
        (dolist (charset '(kana han cjk-misc bopomofo))
          (set-fontset-font (frame-parameter nil 'font)
                            charset (font-spec :family cjk-font :size cjk-font-size)))))
(add-hook 'doom-init-ui-hook 'init-cjk-fonts)

;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-unicode-font' -- for unicode glyphs
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;; (load-theme 'kaolin t)
;; (color-theme-sanityinc-tomorrow-night)
;; (setq doom-theme 'kaolin-bubblegum)
;; (setq doom-theme 'sanityinc-tomorrow-eighties)
;; (setq doom-theme 'doom-winter-is-coming-dark-blue)
;; (after! doom-themes
;;   (load-theme 'doom-winter-is-coming-dark-blue t))

(add-hook 'doom-load-theme-hook
          (lambda ()
            (set-face-attribute 'help-key-binding nil :box nil)))

(load-theme 'kaolin-dark t)
(after! avy (set-face-attribute 'avy-lead-face nil
                    :foreground "#000000"
                    :weight 'bold)
            (set-face-attribute 'avy-lead-face-0 nil
                    :foreground "#000000"
                    :weight 'bold)
            (set-face-attribute 'avy-lead-face-1 nil
                    :foreground "#000000"
                    :weight 'bold))


;; (setq initial-frame-alist '((height . 50)))
;; (add-to-list 'initial-frame-alist '(top . 10))
;; (add-to-list 'initial-frame-alist '(left . 10))

;; (set-frame-size (selected-frame) (cons 60 (/ (window-inside-pixel-edges)(selected-frame))) nil)
;; (setq initial-frame-alist '((top . 0) (left . 0) (width . 100) (height . maximized)))

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type nil)


;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

(setq package-archives '(( "gnu"    . "http://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/"   )
                         ( "org-cn" . "http://mirrors.tuna.tsinghua.edu.cn/elpa/org/"   )
                         ( "melpa"  . "http://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/" )))

(map! :nv  "; x"      'execute-extended-command              )
(map! :nve "; g"      'evil-last-non-blank                   )
(map! :nve "; a"      'evil-first-non-blank                  )
(map! :ne  "f"        'evil-avy-goto-char                    )
(map! :ne  "C-j"      'evil-scroll-down                      )
(map! :ne  "C-k"      'evil-scroll-up                        )
(map! :n   "L"        'evil-join                             )
(map! :ne  "SPC f w"  'ace-window                            )
(map! :nve "; e"      'er/expand-region                      )
(map! :ne  "M-j"      'drag-stuff-down                       )
(map! :ne  "M-k"      'drag-stuff-up                         )
(map! :ne  "; w"      'save-buffer                           )
(map! :ne  "; b"      'switch-to-buffer                      )
(map! :ne "; d"       'zygospore-toggle-delete-other-windows )
(map! :ne  "; q"      'ace-window       )
(map! :ne  "; f"      'dirvish                               )
(map! :map dirvish-mode-map :ne "; f" #'+dired/quit-all      )
(map! :n   "SPC t n"  '+workspace/new                        )
(map! :n   "SPC f n"  'copy-buffer-file-name                 )
(map! :v   "SPC f n"  'copy-buffer-file-name                 )
(map! :n   "SPC f g"  'copy-file-to-clipboard                )
;; (map! :nv  "SPC d"    'aidermacs-transient-menu              )

(map! :n   "K"        '+workspace/switch-right               )
(map! :n   "J"        '+workspace/switch-left                )
(map! :vn  "g l"      'ialign                                )
(map! :ie  "C-h"     #'backward-delete-char-untabify         )
(general-def          'insert "C-h"    'delete-backward-char )
(keyboard-translate ?\C-h ?\C-?                              )

(map! :after evil
      :map evil-insert-state-map
      "TAB" nil)
(map! :after evil
      :map evil-normal-state-map
      "K" nil)
(map! :after evil
      :map evil-normal-state-map
      "K" '+workspace/switch-right)
(map! :after evil
      :map evil-insert-state-map
      "TAB" #'yas-expand)

(setq
 kill-do-not-save-duplicates                t  ;不向kill-ring中加入重复内容
 save-interprogram-paste-before-kill        t  ;将系统剪切板的内容放一份到kill-ring中，
 user-private-dir                           "~/org/org-roam/emacs/command/doom/config/" ;; load your privacy config
 ;; user-private-dir                           "~/.doom.d/neoemacs/" ;; load your privacy config
 )

(setq byte-compile-warnings '(cl-functions)
      warning-minimum-level :error
      warning-suppress-types '((obsolete) (cl-functions))
      display-time-default-load-average nil
      emacs-module-root "/Applications/Emacs.app/Contents/Resources/include")
(with-eval-after-load 'ejc-sql
  (add-to-list 'warning-suppress-types '(obsolete)))
(with-eval-after-load 'npm-mode
  (add-to-list 'warning-suppress-types '(cl-functions)))

;; (setq +format-on-save-disabled-modes (add-to-list '+format-on-save-disabled-modes 'web-mode))
;; (transwin-toggle)

(use-package ultra-scroll
  :defer 5
  :load-path "~/.doom.d/neoemacs/ultra-scroll/"
  :init
  (setq scroll-conservatively 101 ; important!
        scroll-margin 0)
  :config
  (ultra-scroll-mode 1))

(add-to-list 'load-path          user-private-dir )
(add-to-list 'load-path          "~/.doom.d/"     )
(use-package! db-work                             )
(load "keymap.el")

(map! :after dired
      :map dired-mode-map
      :ne "J" nil)
(map! :after dired
      :map dired-mode-map
      :ne "J" #'+workspace/switch-left)

;; (setq transient-show-during-minibuffer-read t)
(let ((lfile (concat doom-local-dir "straight/repos/transient/lisp/transient.el")))
  (if (file-exists-p lfile)
      (load lfile)))

(after! evil
  (defun +evil-normal-in-eshell-on-window-change (_win)
    "当切换到 eshell 窗口时，自动进入 evil normal 状态。"
    (when (derived-mode-p 'eshell-mode)
      (delete-other-windows)
      (evil-normal-state)))
  (add-hook 'window-selection-change-functions
            #'+evil-normal-in-eshell-on-window-change))

(require 'acp)
(require 'agent-shell)

(use-package! redis)
(use-package! msgpack)
(use-package! tramp-rpc)
(setq tramp-rpc-deploy-git-build-policy 'release)
(setq tramp-rpc-deploy-local-cache-directory "~/.doom.d/neoemacs/tramp-rpc-binaries")


;; (add-to-list 'load-path "/Users/van/.doom.d/neoemacs/animation.el/")
;; (require 'text-glow)
;; (text-glow-mode 1)
;; (metal-loader-load "/Users/van/.doom.d/neoemacs/animation.el/glitch-effect.metallib")
(add-to-list 'load-path "/path/to/clutch")
(require 'clutch)

(when (eq system-type 'darwin)
  (defun my/refocus-emacs ()
    (ignore-errors
      (ns-do-applescript "tell application \"Emacs\" to activate")
      (select-frame-set-input-focus (selected-frame))))
  (add-hook 'window-setup-hook
            (lambda ()
              (run-with-idle-timer 0.5 nil #'my/refocus-emacs)
              (run-with-idle-timer 1.5 nil #'my/refocus-emacs)
              (run-with-idle-timer 3.0 nil #'my/refocus-emacs)))
  (add-hook 'after-make-frame-functions
            (lambda (frame)
              (run-with-idle-timer 0.2 nil
                (lambda () (select-frame-set-input-focus frame))))))

;; macOS Liquid Glass (原生 NSGlassEffectView 玻璃/模糊背景) —— 已启用
;; 整体不透明度约 70%（预设 macos-glass-regular 的 :alpha=0.70），即约 30% 透视。
;; 玻璃材质：clear（比 regular 更清透、模糊更轻）。
;; modeline/hl-line/选区保持实色（ns-alpha-elements 刻意排除 ns-alpha-glyphs），Powerline 零色差。
;; 想临时关掉：M-x salih/toggle-glass。
;; 依赖: emacs-plus@31 编译时应用 frame-transparency + ns-glass-effect 补丁
;;   ~/.config/emacs-plus/build.yml
;;   ~/.config/emacs-plus/ns-glass-effect.patch
;; 源码: https://github.com/larrasket/emacs-liquid-glass
;; 用法: M-x salih/set-glass-style / salih/toggle-glass / salih/set-glass
(add-to-list 'load-path "~/.doom.d/lisp")
(require 'lr-macos-glass)

;; 覆盖 doom+ 默认实现: yank 路径时不用 ~ 缩写, 保持绝对路径
(defun my/yank-buffer-path-full (&optional root)
  "Copy the current buffer's absolute path to the kill ring."
  (interactive)
  (if-let* ((filename (or (buffer-file-name (buffer-base-buffer))
                          (bound-and-true-p list-buffers-directory))))
      (let ((path (if root
                      (file-relative-name filename root)
                    filename)))
        (kill-new path)
        (if (string= path (car kill-ring))
            (message "Copied path: %s" path)
          (user-error "Couldn't copy filename in current buffer")))
    (error "Couldn't find filename in current buffer")))

(advice-add '+default/yank-buffer-path :override #'my/yank-buffer-path-full)

;;; TRAMP / 退出行为：只对“有未保存改动的远程 buffer”逐个询问，绝不卡住
;; 退出一共有两处会访问远程：
;;  A. Doom 把 `recentf-cleanup' 挂在 `kill-emacs-hook' 上（doom-emacs.el），而默认的
;;     `recentf-keep-default-predicate' 会对“连接已建立”的远程文件调用 `access-file'。
;;  B. `diff-hl-mode' / `flycheck-mode' 会在空闲计时器/钩子里通过 vc 在远程执行
;;     git 等命令（日志里的 process.run 超时即来自此）。退出流程弹窗时这些计时器
;;     仍会触发，导致卡死。
;; 下面先堵 A（让 recentf 保留远程条目但绝不探测），再在退出前拆掉 B。
;; 退出行为：没有改动的远程 buffer 不询问、直接随退出关闭；有未保存改动的远程
;; buffer 才逐个弹菜单，让用户选择 保存 / 不保存并关闭 / 取消退出。不使用任何检测/
;; 确认定时器；只在退出期间把连接超时压到 5s，让不可达连接尽快失败而不是等 60s。
(defun my/recentf-keep (file)
  "本地文件检查可读性；远程文件直接保留，绝不发起 I/O。"
  (if (file-remote-p file) t (file-readable-p file)))

(after! recentf
  (setq recentf-keep '(my/recentf-keep))
  ;; 无论谁调用 `recentf-cleanup'（含 TRAMP 的清理钩子），都强制不探测远程文件：
  ;; 否则默认谓词会对“连接已建立”的远程路径调用 `access-file'，VPN 断后逐个超时。
  (defun my/recentf-cleanup-keep-remote (orig &rest args)
    (let ((recentf-keep '(my/recentf-keep)))
      (apply orig args)))
  (advice-add 'recentf-cleanup :around #'my/recentf-cleanup-keep-remote))

;; TRAMP 在清理连接时（tramp-recentf-cleanup / tramp-recentf-cleanup-all）会把
;; 对应的远程条目从 recentf 里删掉，并打印一长串 "File ... removed from the recentf
;; list"。这既是退出时刷屏的来源，也会把你明确想保留的远程路径删掉。置为 no-op，
;; 让 recentf 只记录路径、远程条目永久保留。
(with-eval-after-load 'tramp-integration
  (advice-add 'tramp-recentf-cleanup :override #'ignore)
  (advice-add 'tramp-recentf-cleanup-all :override #'ignore))

;; 关掉所有会在空闲计时器/钩子里通过 TRAMP 跑远程命令的次要模式
(defun my/disable-remote-touching-modes ()
  "关闭会在退出流程中触发远程访问的全局与本地次要模式。"
  (dolist (mode '(global-diff-hl-mode global-flycheck-mode))
    (when (and (boundp mode) (symbol-value mode))
      (ignore-errors (funcall mode -1))))
  (dolist (buffer (buffer-list))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (when (and buffer-file-name (file-remote-p buffer-file-name))
          (dolist (mode '(diff-hl-mode flycheck-mode auto-revert-mode))
            (when (and (boundp mode) (symbol-value mode))
              (ignore-errors (funcall mode -1)))))))))

(defun my/remote-modified-buffers ()
  "返回所有已修改的远程 (TRAMP) 文件 buffer。"
  (seq-filter
   (lambda (buffer)
     (let ((file (buffer-file-name buffer)))
       (and file
            (file-remote-p file)
            (buffer-modified-p buffer))))
   (buffer-list)))

(defun my/confirm-remote-buffers-before-exit ()
  "退出前逐个询问已修改的远程 buffer，由用户决定保存/不保存/取消退出。
没有改动的远程 buffer 不会被询问，直接随退出关闭。全程无任何定时器/超时。"
  (dolist (buffer (my/remote-modified-buffers))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (let ((file buffer-file-name))
          (pcase (car (read-multiple-choice
                       (format "远程文件已修改：%s" file)
                       '((?s "save"    "保存该文件")
                         (?n "no-save" "放弃修改并关闭该文件")
                         (?c "cancel"  "取消退出 Emacs"))))
            (?s
             (condition-case err
                 (progn
                   (save-buffer)
                   (message "已保存：%s" file))
               (error
                (message "保存失败：%s（%s）" file err)
                (if (yes-or-no-p
                     (format "保存 %s 失败，放弃修改并继续退出？ " file))
                    (set-buffer-modified-p nil)
                  (user-error "退出已取消")))))
            (?n (set-buffer-modified-p nil))
            (?c (user-error "退出已取消"))))))))

(defun my/save-buffers-kill-emacs-a (orig &rest args)
  "退出前先拆掉远程访问，再走标准退出流程；若退出被取消则恢复。"
  (let ((diff-hl-was (and (boundp 'global-diff-hl-mode)
                          (symbol-value 'global-diff-hl-mode)))
        (flycheck-was (and (boundp 'global-flycheck-mode)
                           (symbol-value 'global-flycheck-mode)))
        (tramp-verbose 0)
        ;; 退出时把连接超时压到 5s：VPN 已断时不再等默认 60s 才失败（可自行调整）
        (tramp-connection-timeout 5)
        (remote-file-name-inhibit-cache t)
        ;; 退出期间禁用 VC，避免保存/关闭远程文件时再触发 vc 的远程 git 调用
        (vc-handled-backends nil))
    (unwind-protect
        (progn
          (my/disable-remote-touching-modes)
          (my/confirm-remote-buffers-before-exit)
          ;; `non-essential' 让 TRAMP 在退出期间不再为远程操作阻塞/重连
          (let ((non-essential t))
            (apply orig args)))
      ;; 只有退出被取消（没有真正 kill-emacs）时才会执行到这里
      (when diff-hl-was (ignore-errors (global-diff-hl-mode 1)))
      (when flycheck-was (ignore-errors (global-flycheck-mode 1))))))
(advice-add 'save-buffers-kill-emacs :around #'my/save-buffers-kill-emacs-a)

;; 兜底：即使从其它路径直接 kill-emacs，也先关掉远程相关模式
(add-hook 'kill-emacs-hook #'my/disable-remote-touching-modes -95)
