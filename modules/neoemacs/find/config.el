;;; neoemacs/find/config.el -*- lexical-binding: t; -*-
(setq fd-exec-path                   "/opt/homebrew/bin/fd"
      rg-exec-path                   "/opt/homebrew/bin/rg")
;; use project root
(setq counsel-fzf-dir-function (lambda ()
  (let ((d (locate-dominating-file default-directory ".git")))
    (if (or (null d)
      (equal (expand-file-name d)
        (expand-file-name "~/")))
  default-directory d)))
      counsel-fzf-cmd (concat fd-exec-path " -c never --hidden --follow %s ."))


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

(map! :ne "SPC z"   'counsel-fzf                               )
(map! :ne "SPC v c" 'counsel-rg                                )
(map! :ie "C-i"     'counsel-yank-pop                          )

(map! :after dired
      :map dired-mode-map
      :ne "J" nil)
(map! :after dired
      :map dired-mode-map
      :ne "J" #'+workspace/switch-left)

(after! tramp (setq tramp-verbose 0))
