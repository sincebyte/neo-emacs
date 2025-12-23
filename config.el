;; max width and height but not fullscreen
(add-to-list 'default-frame-alist '(fullscreen . maximized))
(setq ns-use-proxy-icon nil)           ; 禁用代理图标
(setq frame-title-format nil)          ; 清空标题格式
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

(load-theme 'kaolin-dark t)


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
(map! :ne  "; d"      'delete-other-windows                  )
(map! :ne  "; q"      'quit-window                           )
(map! :ve  "; q"      'quit-window                           )
(map! :ne  "; f"      'dirvish                               )
(map! :map dirvish-mode-map :ne "; f" #'+dired/quit-all      )
(map! :n   "SPC t n"  '+workspace/new                        )
(map! :nv  "SPC d"    'aidermacs-transient-menu              )
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

;; sparkweaher day
(setq calendar-latitude 30.6
      calendar-longitude 104.1)

; quickrun plug
(after! evil
  (defun +evil-normal-in-eshell-on-window-change (_win)
    "当切换到 eshell 窗口时，自动进入 evil normal 状态。"
    (when (derived-mode-p 'eshell-mode)
      (delete-other-windows)
      (evil-normal-state)))
  (add-hook 'window-selection-change-functions
            #'+evil-normal-in-eshell-on-window-change))

;; (use-package aider
;;   :config
;;   (setq aider-args '("--model" "deepseek/deepseek-chat"))
;;   (require 'aider-doom))
(use-package aidermacs
  ;; :bind (("SPC d" . aidermacs-transient-menu))
  :config
  (setq aidermacs-auto-commits nil)
  (setq aidermacs-subtree-only nil)
  (setq aidermacs-extra-args (list "--chat-language" "zh-cn"))
  (setq aidermacs-exit-kills-buffer t)
  (setopt aidermacs-vterm-use-theme-colors t)
  (setq aidermacs-global-read-only-files '("~/CONVENTIONS.md"))
  ;; 设置 face-remapping-alist 来覆盖
  ;; 隐藏 aidermacs 聊天 buffer 的 modeline 并设置滚动边距
  (defun my/hide-modeline-in-aidermacs ()
    "Hide modeline in aidermacs chat buffers and set scroll margin."
    ;; 使用定时器延迟执行，确保 buffer 已完全创建
    (run-with-timer 0.1 nil
                    (lambda ()
                      (when (buffer-live-p (current-buffer))
                       (setq-local face-remapping-alist
                                   (append face-remapping-alist
                                           '((aidermacs-command-text . font-lock-escape-face))))
                        (hide-mode-line-mode t)
                        ;; 设置滚动边距，保留底部8行空白
                        (setq-local scroll-margin 8)
                        ;; 确保滚动时保持光标在可见区域内
                        (setq-local scroll-conservatively 101)
                        ;; 设置最大滚动步长
                        (setq-local scroll-step 1)
                        ;; 确保窗口滚动时光标位置合适
                        (setq-local scroll-preserve-screen-position t)))))
  (add-hook 'aidermacs-before-run-backend-hook #'my/hide-modeline-in-aidermacs)
  :custom
  ; See the Configuration section below
  (aidermacs-default-chat-mode 'architect)
  (aidermacs-default-model "deepseek/deepseek-chat"))
