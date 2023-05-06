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
        awesome-tray-date-format "%H:%M"ome-tray-file-path-truncate-dirname-levels 10
        awesome-tray-file-path-full-dirname-levels 10))
(defun my-awesome-tray-nil-info () (concat "" ""))
(defun my-awesome-tray-git-info () (nth 0 (vc-git-branches)))

(defun my-awesome-tray-buffername-info ()
    (let ((l-name (if (buffer-modified-p) (concat "*" (buffer-name)) (buffer-name))))
         (if (eq (eval buffer-read-only) nil) l-name (concat "% " l-name))))

(defun projectile-project-root-single ()
  (let ((l-level 6)
        (l-list  (delete "" (split-string (projectile-project-root) "/" )))
        (l-lenth (length (delete "" (split-string (projectile-project-root) "/" ))))
        (l-bool  (> (length (delete "" (split-string (projectile-project-root) "/" ))) 6)))
        (if l-bool (string-join (nthcdr l-level l-list) "/")
                   (elt l-list (- l-lenth 1)))))

(setq awesome-tray-module-alist
  '(
    ("date"      . (my-awesome-tray-nil-info awesome-tray-module-date-face))
    ("battery"   . (my-awesome-tray-git-info awesome-tray-module-battery-face))
    ("mode-name" . (projectile-project-root-single awesome-tray-module-file-path-face))
    ("file-path" . (my-awesome-tray-buffername-info awesome-tray-module-date-face))
    ("location"  . (my-awesome-tray-nil-info awesome-tray-module-battery-face))
    ("belong"    . (my-awesome-tray-nil-info awesome-tray-module-battery-face))))

;; (map! :ne "; v"     'vc-refresh-state                          )
(map! :ne "; ;"     'hide-mode-line-mode                       )

(awesome-tray-enable)
