(setq consult-project-function (lambda (_) (locate-dominating-file "." ".git")))

(map! :ne "SPC z"   'consult-find       )
(map! :ne "SPC v c" 'consult-ripgrep    )
(map! :ie "C-i"     'consult-yank-pop   )

(use-package dirvish
  :init
  (dirvish-override-dired-mode)
  :config
  (setq dirvish-hide-details t
        dirvish-use-header-line 'global
        dirvish-hide-cursor t
        delete-by-moving-to-trash t
        dirvish-default-layout '(0 0.2 0.8)
        dirvish-attributes
        '(nerd-icons file-size subtree-state vc-state)
        dirvish-header-line-format
        '(:left (path) :right (free-space)))
  )

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
