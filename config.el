;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
(setq rg-exec-path                   "/opt/homebrew/bin/rg"                      ;; rg   exec path
      node-bin-dir                   "~/soft/node-v16.14.0/bin"                  ;; node home
      user-private-dir               "~/org/org-roam/emacs/command/doom/config/" ;; user private dir
      display-line-numbers-type      nil)                                         ;; show line number 'relative

(add-to-list 'exec-path          "/Users/van/.m2/go/bin"          )
(add-to-list 'exec-path          "/opt/homebrew/bin//sbcl"        )
(add-to-list 'load-path          doom-user-dir                    )
(add-to-list 'load-path          user-private-dir                 )
(add-to-list 'load-path          (concat doom-user-dir "neoemacs"))   ;; default setting

(setq default-frame-alist                        '((top . 88) (left . 450) (height . 32) (width . 122))
      undo-tree-history-directory-alist          '(("." . "~/.emacs.d/undo"))
      dired-dwim-target                          t
      neo-window-width                           45
      neo-window-fixed-size                      nil
      frame-resize-pixelwise                     nil
      evil-emacs-state-tag                       "E"
      evil-insert-state-tag                      "INSERT"
      evil-motion-state-tag                      "MOTION"
      evil-normal-state-tag                      "NORMAL"
      evil-operator-state-tag                    "OPERATOR"
      evil-visual-state-tag                      "VISUAL"
      evil-replace-state-tag                     "REPLACE"
      evil-want-Y-yank-to-eol                    t
      read-process-output-max                    (* 1024 1024))

(setq package-archives '(( "gnu"    . "http://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/"   )
                         ( "org-cn" . "http://mirrors.tuna.tsinghua.edu.cn/elpa/org/"   )
                         ( "melpa"  . "http://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/" )))
(package-initialize)

;; almost package
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
(map! :nv "; x"     'amx                                       )
(map! :nve "; g"    'evil-last-non-blank                       )
(map! :nve "; a"    'evil-first-non-blank                      )
(map! :ne "m"       'evil-avy-goto-char                        )
(map! :ne "f"       'evil-avy-goto-char                        )
(map! :ne "C-j"     'evil-scroll-down                          )
(map! :ne "C-k"     'evil-scroll-up                            )
(map! :n "L"        'evil-join                                 )
(map! :ne "SPC f w" 'ace-window                                )
(map! :nve "; e"    'er/expand-region                          )
(map! :ne "M-j"     'drag-stuff-down                           )
(map! :ne "M-k"     'drag-stuff-up                             )
(map! :ne "; w"     'save-buffer                               )
(map! :ne "; b"     'switch-to-buffer                          )
(map! :ne "; d"     'zygospore-toggle-delete-other-windows     )
(map! :ve "; d"     'zygospore-toggle-delete-other-windows     )
(map! :ne "; q"     'quit-window                               )
(map! :ve "; q"     'quit-window                               )
(map! :ne "; f"     'neotree-find                              )
(map! :ne "; h"     'neotree-toggle                            )
(map! :ne "; o"     'neotree-projectile-action                 )
(map! :ne "SPC e r" 'neotree-goto-resources-dir                )
(map! :nv "s-1"     '+workspace/switch-to-0                    )
(map! :nv "s-2"     '+workspace/switch-to-1                    )
(map! :nv "s-3"     '+workspace/switch-to-2                    )
(map! :nv "s-4"     '+workspace/switch-to-3                    )
(map! :nv "s-5"     '+workspace/switch-to-4                    )
(map! :n "SPC t n"  '+workspace/new                            )
(map! :n "K"        '+workspace/switch-right                   )
(map! :n "J"        '+workspace/switch-left                    )

;; 断词设置，设置以后断词更长
(global-set-key (kbd "<RET>") 'evil-ret                        )
(global-set-key (kbd "C-."  ) 'next-buffer                     )
(global-set-key (kbd "C-,"  ) 'previous-buffer                 )
(general-def 'insert "C-h"    'delete-backward-char            )

(load-theme   'doom-one t          ) ;; set theme
