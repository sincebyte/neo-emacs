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
;; (setq doom-font (font-spec :family "等距更纱黑体 Slab SC" :size 18.0))
(if (eq system-type 'windows-nt)
    (progn (set-selection-coding-system 'utf-8)
           (setq doom-font (font-spec :family "Kode Mono" :size 24)
                 cjk-font "汉仪新人文宋W"
                 cjk-font-size 26))
  (progn (set-selection-coding-system 'utf-16le-dos)
         (setq doom-font (font-spec :family "Kode Mono" :size 16 )
               cjk-font "HYXinRenWenSongW"
               cjk-font-size 20)))

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
;; (load-file "~/.emacs.d/themes/masked-theme-source-code.el")
;; (load-theme 'color-theme-sanityinc-tomorrow-night t)
;; (load-theme 'kaolin t)
;; (color-theme-sanityinc-tomorrow-night)
(setq doom-theme 'doom-tomorrow-night)



(add-to-list 'default-frame-alist '(width.700))
(add-to-list 'default-frame-alist '(height.303))

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
(map! :ne  "; f"      'dired-jump                            )
(map! :ne  "; o"      'neotree-projectile-action             )
(map! :n   "SPC t n"  '+workspace/new                        )
(map! :n   "K"        '+workspace/switch-right               )
(map! :n   "J"        '+workspace/switch-left                )
(map! :n   "s-k"      '+workspace/swap-right                 )
(map! :n   "s-j"      '+workspace/swap-left                  )
(map! :vn  "g l"      'align-regexp                          )
(map! :ie  "C-h"     #'backward-delete-char-untabify         )
(general-def          'insert "C-h"    'delete-backward-char )
(keyboard-translate ?\C-h ?\C-?                              )


(setq
 kill-do-not-save-duplicates                t  ;不向kill-ring中加入重复内容
 save-interprogram-paste-before-kill        t  ;将系统剪切板的内容放一份到kill-ring中，
 user-private-dir                           "~/org/org-roam/emacs/command/doom/config/" ;; load your privacy config
 ;; user-private-dir                           "~/.doom.d/neoemacs/" ;; load your privacy config
 )

(setq byte-compile-warnings '(cl-functions)
      display-time-default-load-average nil
      emacs-module-root "/Applications/Emacs.app/Contents/Resources/include")

(setq +format-on-save-disabled-modes (add-to-list '+format-on-save-disabled-modes 'web-mode))

(add-to-list 'load-path          user-private-dir )
(use-package! db-work                             )    ;; load by local, privacy config account or pwd here
(setq tramp-default-method "ssh")
(setq tramp-verbose 10)
