(setq consult-project-function (lambda (_) (locate-dominating-file "." ".git")))

(map! :ne "SPC z"   'consult-find       )
(map! :ne "SPC v c" 'consult-ripgrep    )
(map! :ie "C-i"     'consult-yank-pop   )

(setq dirvish-hide-details t
      dirvish-hide-cursor t
      dirvish-default-layout '(0 0.4 0.6))
(dirvish-override-dired-mode)

;; disable short-cut, C-; need chage file here
;; ~/.emacs.d/modules/completion/vertico/config.el

(map! :after dired
      :map dired-mode-map
      :ne "J" nil)
(map! :after dired
      :map dired-mode-map
      :ne "J" #'+workspace/switch-left)
(map! :after dired
      :map dired-mode-map
      :ne "c" nil)
(map! :after dired
      :map dired-mode-map
      :ne "c" #'dired-create-empty-file)

(map! :after magit
      :map magit-mode-map
      :ne "K" nil)
(map! :after magit
      :map magit-mode-map
      :ne "K" #'+workspace/switch-right)
(map! :after magit
      :map magit-mode-map
      :ne "J" nil)
(map! :after magit
      :map magit-mode-map
      :ne "J" #'+workspace/switch-left)

(setq bookmark-default-file "~/org/org-roam/bookmarks")
