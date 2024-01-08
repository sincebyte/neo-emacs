(setq
 doom-modeline-height                       1
 evil-emacs-state-tag                       "󰬌"
 evil-insert-state-tag                      "󰬐"
 evil-motion-state-tag                      "󰬔"
 evil-normal-state-tag                      "󰬕"
 evil-operator-state-tag                    "󰬖"
 evil-visual-state-tag                      "󰬝"
 evil-replace-state-tag                     "󰬙"
 doom-modeline-modal-icon                   nil
 doom-modeline-icon                         nil
 doom-modeline-major-mode-icon              nil
 doom-modeline-buffer-encoding              t
 doom-modeline-lsp                          nil
 doom-modeline-modal                        t
 doom-modeline-vcs-max-length               200
 doom-modeline-buffer-file-name-style       'buffer-name
 doom-modeline-continuous-word-count-modes  '(java-mode)
 doom-modeline-enable-word-count            t  )

(after! doom-modeline
  (fresh/modelineconfig)
  (add-hook '+workspace-new-hook #'fresh/modelineconfig))
(after! dashboard
  (fresh/modelineconfig))

(defun fresh/modelineconfig ()
  (doom-modeline-def-segment my-major-mode
    "The major mode, including environment and text-scale info."
    (propertize
     (replace-regexp-in-string
      "/+\\(l\\|d\\)"
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
    '(misc-info minor-modes input-method buffer-encoding my-major-mode process vcs my-segment))
  (doom-modeline-def-modeline 'vcs
    '(" 󰬎"  matches buffer-info remote-host buffer-position parrot selection-info)
    '(compilation misc-info battery irc mu4e gnus github debug minor-modes buffer-encoding major-mode process time "󰬎 "))
  (doom-modeline-def-modeline 'dashboard
    '(modals buffer-default-directory-simple remote-host)
    '(my-segment)))
