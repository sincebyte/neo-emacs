(setq consult-project-function (lambda (_) (locate-dominating-file "." ".git")))
(setq projectile-project-root-files '(".git"))


(map! :ne "SPC z"   'consult-find       )
(map! :ne "SPC v c" 'consult-ripgrep    )
(map! :ie "C-i"     'consult-yank-pop   )

(use-package dirvish
  ;; :init
  ;; (dirvish-override-dired-mode)
  :config
  (setq dirvish-hide-details t
        dirvish-use-header-line nil
        dirvish-use-mode-line t
        ;; dirvish-header-line-height 10
        ;; dirvish-mode-line-height 6
        dirvish-hide-cursor t
        delete-by-moving-to-trash t
        dirvish-default-layout '(0 0.4 0.6)
        dirvish-attributes
        '(nerd-icons file-size vc-state git-msg)
        dirvish-header-line-format
        '(:left (path) :right (free-space))))
(add-hook 'dirvish-find-entry-hook
          (lambda (&rest _) (setq-local truncate-lines t)))

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
(map! :after dired
      :map dired-mode-map
      :ne "h" #'dired-up-directory)
(map! :after dired
      :map dired-mode-map
      :ne "l" #'dired-find-file)

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
(setq consult-ripgrep-default-directory (projectile-project-root))

(projectile-add-known-project "~/ZY/workspace/minex-work/")

(add-hook 'dired-mode-hook
          (lambda ()
            (buffer-face-set
             '(:family "M PLUS Code Latin 50" :height 140))))
