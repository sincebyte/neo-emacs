;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; emacs header line title setting
;; (setq-default default-frame-alist '((undecorated . t)))
(add-to-list 'default-frame-alist '(ns-transparent-titlebar . nil))

;; (add-to-list 'default-frame-alist '(ns-appearance . light))
(setq-default frame-title-format nil)
(setq ns-use-proxy-icon nil)


;; max width and height but not fullscreen
(add-to-list 'default-frame-alist '(fullscreen . maximized))
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
  (dolist (charset '(kana han symbol cjk-misc bopomofo))
    (set-fontset-font t charset (font-spec :family "方正悠宋+ GBK" :size 24 ))))
(add-hook 'doom-big-font-mode-hook #'my/setup-big-cjk-fonts)

;; 设置不同模式下的字体
(defun my-set-font-for-mode ()
  (cond
   ((derived-mode-p 'dired-mode)
    (setq-local face-remapping-alist '((default (:family "M PLUS Code Latin 50" :height 180) default))))
   ((derived-mode-p 'vterm-mode)
    (setq-local face-remapping-alist '((default (:family "Kode Mono" :height 160) default))))
   ))

(add-hook 'after-change-major-mode-hook #'my-set-font-for-mode)

;; 设置 minibuffer 中的字体
(defun my-set-font-for-minibuffer ()
  (setq-local face-remapping-alist '((default (:family "M PLUS Code Latin 50" :height 170) default)))
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
;; (setq doom-theme 'sanityinc-tomorrow-night)
;; (after! doom-themes
;;   (load-theme 'doom-nano-dark t))

;; (load-theme 'doom-wilmersdorf t)


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
(map! :ne  "; o"      'neotree-projectile-action             )
(map! :n   "SPC t n"  '+workspace/new                        )
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

(setq +format-on-save-disabled-modes (add-to-list '+format-on-save-disabled-modes 'web-mode))
(transwin-toggle)

(use-package ultra-scroll
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
(setq transient-show-during-minibuffer-read t)
