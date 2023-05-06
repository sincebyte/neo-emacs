;;; neoemacs/modeline/config.el -*- lexical-binding: t; -*-
(add-to-list 'load-path          (concat doom-user-dir "neoemacs"))   ;; default setting
(setq
      doom-modeline-height                       10
      doom-modeline-bar-width                    2
      doom-modeline-modal-icon                   nil
      doom-modeline-icon                         nil
      doom-modeline-major-mode-icon              nil
      doom-modeline-buffer-encoding              t
      doom-modeline-lsp                          nil
      doom-modeline-modal                        t
      doom-modeline-vcs-max-length               200
      doom-modeline-buffer-file-name-style       'buffer-name
      doom-modeline-continuous-word-count-modes '(java-mode)
      doom-modeline-enable-word-count            4
)

(use-package! awesome-tray
  :config
  (setq awesome-tray-git-show-status t
        awesome-tray-date-format "%H:%M"
        awesome-tray-file-path-truncate-dirname-levels 10
        awesome-tray-file-path-full-dirname-levels 10))
(defun my-awesome-tray-nil-info () (concat "" ""))
(defun projectile-project-root-single ()
    (if (> (length (delete "" (split-string (projectile-project-root) "/" ))) 3)
        (string-join (nthcdr 3 (delete "" (split-string (projectile-project-root) "/" ))) "/")
            (elt (delete "" (split-string (projectile-project-root) "/" ))
            (- (length (delete "" (split-string (projectile-project-root) "/" ))) 1))))
(setq awesome-tray-module-alist
  '(
    ("file-path" . (projectile-project-root-single awesome-tray-module-file-path-face))
    ("date" . (awesome-tray-module-date-info awesome-tray-module-date-face))
    ("battery"   . (my-awesome-tray-nil-info awesome-tray-module-battery-face))
    ("mode-name" . (my-awesome-tray-nil-info awesome-tray-module-battery-face))
    ("location"  . (my-awesome-tray-nil-info awesome-tray-module-battery-face))
    ("belong"    . (my-awesome-tray-nil-info awesome-tray-module-battery-face))))

;; (map! :ne "; v"     'vc-refresh-state                          )
(map! :ne "; ;"     'hide-mode-line-mode                       )

(awesome-tray-enable)
