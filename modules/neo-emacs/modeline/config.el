;; close the modeline default
;; (add-hook 'buffer-list-update-hook (lambda ()
;;                                      (unless (active-minibuffer-window)
;;                                        (hide-mode-line-mode))))
(use-package! awesome-tray
  :config
  (setq awesome-tray-git-show-status t
        awesome-tray-date-format "%H:%M"ome-tray-file-path-truncate-dirname-levels 10
        awesome-tray-file-path-full-dirname-levels 10))
(defun my-awesome-tray-nil-info () (concat "" ""))
(defun my-awesome-tray-git-info () (concat  "↪Git:" (concat (nth 0 (vc-git-branches)) "")))

(defun my-awesome-tray-buffername-info ()
  (let ((l-name (if (buffer-modified-p) (concat "*" (buffer-name)) (buffer-name))))
    (concat (if (eq (eval buffer-read-only) nil) l-name (concat "% " l-name)) " ▶")))

(defun projectile-project-root-single ()
  (let ((l-level 6)
        (l-list  (delete "" (split-string (projectile-project-root) "/" )))
        (l-lenth (length (delete "" (split-string (projectile-project-root) "/" ))))
        (l-bool  (> (length (delete "" (split-string (projectile-project-root) "/" ))) 6)))
    (concat (if l-bool (string-join (nthcdr l-level l-list) "/")
              (elt l-list (- l-lenth 1))) " ▶")))

(defun my-awesome-db-info ()
  (if (eq major-mode 'sql-mode)
      (concat ejc-connection-name  " ▶")))

(defface awesome-tray-module-db-face
  '((((background light)) :inherit awesome-tray-cyan-face)
    (t :inherit awesome-tray-cyan-face))
  "Battery state face."
  :group 'awesome-tray)
(custom-set-faces `(awesome-tray-module-db-face  ((t (:foreground "#D98880" :weight normal )))))

(custom-set-faces `(awesome-tray-module-date-face      ((t (:foreground "#5DADE2" :weight normal )))))
(custom-set-faces `(awesome-tray-module-file-path-face ((t (:foreground "#3498DB" :weight normal )))))
(custom-set-faces `(awesome-tray-module-battery-face   ((t (:foreground "#2E86C1" :weight normal )))))

(setq awesome-tray-module-alist
      '(
        ("word-count" . (awesome-tray-module-word-count-info awesome-tray-module-word-count-face))
        ("location"   . (my-awesome-db-info       awesome-tray-module-db-face                   ))
        ("battery"    . (my-awesome-tray-git-info awesome-tray-module-battery-face              ))
        ("mode-name"  . (projectile-project-root-single awesome-tray-module-file-path-face      ))
        ("file-path"  . (my-awesome-tray-buffername-info awesome-tray-module-date-face          ))
        ("date"       . (my-awesome-tray-nil-info awesome-tray-module-date-face                 ))
        ("belong"     . (my-awesome-tray-nil-info awesome-tray-module-battery-face              ))))

;; (map! :ne "; v"     'vc-refresh-state                          )
(map! :ne "; ;"     'hide-mode-line-mode                       )
(awesome-tray-mode 1)


(after! doom-modeline
  (doom-modeline-def-segment my-major-mode
    "The major mode, including environment and text-scale info."
    (propertize
     (replace-regexp-in-string
      "/+l"
      ""
      (concat
       (doom-modeline-spc)
       (propertize (format-mode-line
                    (or (and (boundp 'delighted-modes)
                             (cadr (assq major-mode delighted-modes)))
                        mode-name))
                   'help-echo "Major mode\n\
  mouse-1: Display major mode menu\n\
  mouse-2: Show help for major mode\n\
  mouse-3: Toggle minor modes"
                   'mouse-face 'doom-modeline-highlight
                   'local-map mode-line-major-mode-keymap)
       (when (and doom-modeline-env-version doom-modeline-env--version)
         (format "%s%s" (doom-modeline-vspc) doom-modeline-env--version))
       (and (boundp 'text-scale-mode-amount)
            (/= text-scale-mode-amount 0)
            (format
             (if (> text-scale-mode-amount 0)
                 " (%+d)"
               " (%-d)")
             text-scale-mode-amount))
       (doom-modeline-spc)))
     'face (doom-modeline-face 'doom-modeline-buffer-major-mode)))

  (doom-modeline-def-segment my-segment
    "My custom segment "
    (let ((face
           (when (doom-modeline--active)
             (if (eq evil-state 'normal) 'doom-modeline-evil-normal-state
               (if (eq evil-state 'insert) 'doom-modeline-evil-insert-state
                 (if (eq evil-state 'visual) 'doom-modeline-evil-visual-state
                   (if (eq evil-state 'replace) 'doom-modeline-evil-replace-state
                     (if (eq evil-state 'emacs) 'doom-modeline-emacs-visual-state
                       (if (eq evil-state 'motion) 'doom-modeline-motion-visual-state)
                       'doom-modeline-evil-normal-state)))))))
          (charc
           (if (eq evil-state 'normal) "󰬕"
             (if (eq evil-state 'insert) "󰬐"
               (if (eq evil-state 'visual) "󰬝"
                 (if (eq evil-state 'replace) "󰬙"
                   (if (eq evil-state 'emacs) "󰬌"
                     (if (eq evil-state 'motion) "󰬔")
                     "󰬌")))))))
      (concat
       (propertize (concat "" charc " ") 'face face))))
  (doom-modeline-def-segment my-custom-segment
    (my-add-x-to-segment 'doom-modeline--major-mode-segment))
  ;; (display-battery-mode 1)
  ;; (display-time-mode 1)
  (doom-modeline-def-modeline 'main
    '(modals matches buffer-info buffer-position parrot selection-info)
    '(misc-info minor-modes input-method buffer-encoding my-major-mode process vcs battery time my-segment) ))
