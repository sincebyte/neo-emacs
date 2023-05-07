;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
(setq rg-exec-path                   "/opt/homebrew/bin/rg"                                   ;; rg   exec path
      fd-exec-path                   "/opt/homebrew/bin/fd"                                   ;; fd   exec path
      counsel-fzf-cmd                (concat fd-exec-path " -c never --hidden --follow %s .") ;; fd   paramter
      node-bin-dir                   "~/soft/node-v16.14.0/bin"                               ;; node home
      user-private-dir               "~/org/org-roam/emacs/command/doom/config/"              ;; user private dir
      display-line-numbers-type      nil                                                      ;; show line number 'relative
      emacs-module-root              "/Applications/Emacs.app/Contents/Resources/include"     ;; emcas exec path
)
;; default core setting
;; (add-to-list 'exec-path          rg-exec-path                     )
;; (add-to-list 'exec-path          node-bin-dir                     )
(add-to-list 'exec-path          "/Users/van/.m2/go/bin"          )
(add-to-list 'load-path          doom-user-dir                    )
(add-to-list 'load-path          user-private-dir                 )
(add-to-list 'load-path          (concat doom-user-dir "neoemacs"))   ;; default setting

(setq default-frame-alist                        '((top . 88) (left . 450) (height . 32) (width . 122))
      undo-tree-history-directory-alist          '(("." . "~/.emacs.d/undo"))
      dired-dwim-target                          t
      neo-window-width                           45
      neo-window-fixed-size                      nil
      treemacs--width-is-locked                  nil
      frame-resize-pixelwise                     nil
      evil-emacs-state-tag                       "E"
      evil-insert-state-tag                      "INSERT"
      evil-motion-state-tag                      "MOTION"
      evil-normal-state-tag                      "NORMAL"
      evil-operator-state-tag                    "OPERATOR"
      evil-visual-state-tag                      "VISUAL"
      evil-replace-state-tag                     "REPLACE"
      evil-want-Y-yank-to-eol                    t
      vterm-kill-buffer-on-exit                  t
      read-process-output-max                    (* 1024 1024))

(setq package-archives '(( "gnu"    . "http://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/"   )
                         ( "org-cn" . "http://mirrors.tuna.tsinghua.edu.cn/elpa/org/"   )
                         ( "melpa"  . "http://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/" )))
(package-initialize)

;; almost package
;; (require      'disable-mouse      )
(use-package! init-font                   )
(use-package! init-benchmarking           )
(use-package! db-work                     )
(use-package! magit               :defer t)
(use-package! yaml-mode           :defer t)
(use-package! expand-region       :defer t)
(use-package! restclient-jq       :defer t)
(use-package! jq-mode             :defer t)
(use-package! zygospore           :defer t)
(use-package! conf-evil-clipboard :defer t)
(use-package! string-inflection   :defer t)
(use-package! general             :defer t)

;; almost key set
(map! :nve "; g"    'evil-last-non-blank                       )
(map! :nve "; a"    'evil-first-non-blank                      )
(map! :ne "m"       'evil-avy-goto-char                        )
(map! :ne "f"       'evil-avy-goto-char                        )
(map! :ne "C-j"     'evil-scroll-down                          )
(map! :ne "C-k"     'evil-scroll-up                            )
(map! :ne "SPC z"   'counsel-fzf                               )
(map! :ne "SPC v c" 'counsel-rg                                )
(map! :ne "SPC f w" 'ace-window                                )
(map! :ne "SPC v v" 'projectile-run-vterm                      )
(map! :ne "SPC v o" 'vterm-send-stop                           )
(map! :ne "SPC v s" 'vterm-send-start                          )
(map! :ne "M-j"     'drag-stuff-down                           )
(map! :ne "M-k"     'drag-stuff-up                             )
(map! :ne "; w"     'save-buffer                               )
(map! :ne "; b"     'switch-to-buffer                          )
(map! :ne "; d"     'zygospore-toggle-delete-other-windows     )
(map! :ve "; d"     'zygospore-toggle-delete-other-windows     )
(map! :ne "; f"     'neotree-find                              )
(map! :ne "; h"     'neotree-toggle                            )
(map! :ne "; o"     'neotree-projectile-action                 )
(map! :ne "SPC e r" 'neotree-goto-resources-dir                )
(map! :ne "; j"     '+workspace/swap-left                      )
;; (map! :n "SPC e p"  'goto-result-detail-prev                   )
;; (map! :n "SPC e n"  'goto-result-detail-next                   )
;; (map! :n "SPC e e"  'goto-result-detail                        )
(map! :ne "; q"     'quit-window                               )
(map! :ve "; q"     'quit-window                               )
(map! :nve "; e"    'er/expand-region                          )
(map! :nv "; x"     'amx                                       )
(map! :nv "s-1"     '+workspace/switch-to-0                    )
(map! :nv "s-2"     '+workspace/switch-to-1                    )
(map! :nv "s-3"     '+workspace/switch-to-2                    )
(map! :nv "s-4"     '+workspace/switch-to-3                    )
(map! :nv "s-5"     '+workspace/switch-to-4                    )
(map! :n "K"        '+workspace/switch-left                    )
(map! :n "L"        '+workspace/switch-right                   )
(map! :nve "; c"    'comment-line                              )
(map! :n "C-."      'next-buffer                               )
(map! :ie "C-i"     'counsel-yank-pop                          )
(map! :n "SPC t n"  '+workspace/new                            )
(map! :n "SPC r r"  'quickrun-shell                            )

;; 断词设置，设置以后断词更长
(global-set-key (kbd "<RET>") 'evil-ret                        )
(global-set-key (kbd "C-."  ) 'next-buffer                     )
(global-set-key (kbd "C-,"  ) 'previous-buffer                 )
(general-def 'insert "C-h"    'delete-backward-char            )
(general-def 'insert vterm-mode-map "C-h" 'vterm-send-C-h      )
(keyboard-translate ?\C-h ?\C-?)

;; use project root
(setq counsel-fzf-dir-function
(lambda ()
  (let ((d (locate-dominating-file default-directory ".git")))
    (if (or (null d)
      (equal (expand-file-name d)
        (expand-file-name "~/")))
  default-directory d))))

;; environment variable controls the indentation. The value is 4 spaces
(setenv "XMLLINT_INDENT" "    ")
(use-package xml-format
  :demand t
  :defer t
  :after nxml-mode)

(use-package recentf
  ;; :ensure nil
  ;; lazy load recentf
  :defer t
  :init
  (add-hook 'after-init-hook #'recentf-mode)
  (setq recentf-max-saved-items 200)
  :config
  (add-to-list 'recentf-exclude (expand-file-name package-user-dir))
  (add-to-list 'recentf-exclude "\\.emacs\\.d/\\.local/etc/workspaces/autosave"))

(use-package bookmark+
  :defer t
  :after bookmark
  :init (setq-default bookmark-save-flag 1)
        (setq bookmark-default-file (concat org-roam-directory "/emacs/command/doom/config/bookmark")))

(use-package shrface
  :defer t
  :config
  (shrface-basic)
  (shrface-trial)
  (shrface-default-keybindings) ; setup default keybindings
  (setq shrface-href-versatile t))

(use-package eww
  :defer t
  :init
  (add-hook 'eww-after-render-hook #'shrface-mode)
  :config
  (require 'shrface))

;; insert one space char between chinese and english automatically. I like 中文 more.
(add-to-list 'load-path (concat doom-user-dir "neoemacs/wraplish"))
(require 'wraplish)
(dolist (hook (list 'org-mode-hook))
  (add-hook hook #'(lambda () (wraplish-mode 1))))

;; for transparent and blur background
(require 'ns-auto-titlebar)
(when (eq system-type 'darwin) (ns-auto-titlebar-mode))
(add-to-list 'default-frame-alist '(nc-transparent-titlebar . t))
(add-to-list 'default-frame-alist '(nc-appearance . dark))
(setq ns-use-proxy-icon nil)
(setq frame-title-format nil)

;; (set-face-background 'default "mac:windowBackgroundColor")
(set-face-background 'default "#2A2E37")
(dolist (f (face-list)) (set-face-stipple f "alpha:85%"))
;; (setq face-remapping-alist (append face-remapping-alist '((default my/default-blurred))))
;; (defface my/default-blurred
;;    '((t :inherit 'default :stipple "alpha:99%"))
;;    "Like 'default but blurred."
;;    :group 'my)
