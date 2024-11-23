(setq
 ;; doom-modeline-height                       30
 evil-emacs-state-tag                       (if (display-graphic-p) "󰬌" "▇▇▇")
 evil-insert-state-tag                      (if (display-graphic-p) "󰬐" "▇▇▇")
 evil-motion-state-tag                      (if (display-graphic-p) "󰬔" "▇▇▇")
 ;; evil-normal-state-tag                      (if (display-graphic-p) "󰬕" "▇▇▇")
 evil-operator-state-tag                    (if (display-graphic-p) "󰬖" "▇▇▇")
 evil-visual-state-tag                      (if (display-graphic-p) "󰬝" "▇▇▇")
 evil-replace-state-tag                     (if (display-graphic-p) "󰬙" "▇▇▇")
 doom-modeline-modal-icon                   nil
 doom-modeline-icon                         nil
 doom-modeline-time-icon                    nil
 doom-modeline-lsp-icon                     nil
 doom-modeline-major-mode-icon              nil
 doom-modeline-buffer-encoding              t
 doom-modeline-lsp                          nil
 doom-modeline-modal                        t
 doom-modeline-vcs-max-length               200
 doom-modeline-buffer-file-name-style       'buffer-name
 doom-modeline-continuous-word-count-modes  '(java-mode)
 doom-modeline-enable-word-count            t  )
;; (custom-set-faces
;;  '(doom-modeline-evil-normal-state
;;    ((t (:background "blue" :foreground "white" :weight bold))))
;;  '(evil-insert-state-tag
;;    ((t (:background "red" :foreground "white" :weight bold))))
;;  '(evil-visual-state-tag
;;    ((t (:background "orange" :foreground "black" :weight bold))))
;;  '(evil-replace-state-tag
;;    ((t (:background "purple" :foreground "white" :weight bold))))
;;  '(evil-motion-state-tag
;;    ((t (:background "cyan" :foreground "black" :weight bold)))))

(after! doom-modeline
  (fresh/modelineconfig)
  (add-hook '+workspace-new-hook #'fresh/modelineconfig))
(after! dashboard
  (fresh/modelineconfig))
(defface doom-modeline-evil-normal-state-vert
  '((t ( :foreground "#98be65" : "#98be65")))
  "Face for bracket line in org-modern-indent."
  :group 'faces)
(defun fresh/modelineconfig ()
  (doom-modeline-def-segment powerline-separator-right
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (cdr powerline-default-separator-dir ))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn 'mode-line 'doom-modeline-evil-normal-state ))))

  (doom-modeline-def-segment powerline-separator-right-vert
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (cdr powerline-default-separator-dir ))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn 'doom-modeline-evil-normal-state 'mode-line ))))

  (doom-modeline-def-segment powerline-separator-left

    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (car powerline-default-separator-dir))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn 'doom-modeline-evil-normal-state 'mode-line)  )))

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
           (if (eq evil-state 'normal) (if (display-graphic-p)           " NORMAL "  "▇▇▇")
             (if (eq evil-state 'insert) (if (display-graphic-p)         " INSERT "  "▇▇▇")
               (if (eq evil-state 'visual) (if (display-graphic-p)       " VISUAL "  "▇▇▇")
                 (if (eq evil-state 'replace) (if (display-graphic-p)    " REPLACE " "▇▇▇")
                   (if (eq evil-state 'emacs) (if (display-graphic-p)    " EMACS "   "▇▇▇")
                     (if (eq evil-state 'motion) (if (display-graphic-p) " MOTION "  "▇▇▇"))
                     "▇")))))))
      (concat
       (propertize (concat "" charc "") 'face face))))
  (doom-modeline-def-segment my-custom-segment
    (my-add-x-to-segment 'doom-modeline--major-mode-segment))
  (doom-modeline-def-segment wechat-msg-count
    "A custom segment that reads content from a local file."
    (propertize (concat "" (get-message-count)) 'face 'doom-modeline-evil-insert-state))

  (doom-modeline-def-segment empty-segment
    (propertize (concat " " "") 'face 'doom-modeline-evil-insert-state))
  ;; (display-battery-mode 1)
  (display-time-mode 1)
  (doom-modeline-def-modeline 'main
    '(my-segment powerline-separator-right powerline-separator-left matches powerline-separator-right powerline-separator-left buffer-info empty-segment
      powerline-separator-right powerline-separator-left buffer-position powerline-separator-right powerline-separator-right-vert parrot selection-info)
    '(misc-info minor-modes wechat-msg-count input-method buffer-encoding powerline-separator-right powerline-separator-left
      my-major-mode powerline-separator-right powerline-separator-left vcs powerline-separator-right powerline-separator-left
      time powerline-separator-right powerline-separator-left my-segment))
  (doom-modeline-def-modeline 'vcs
    '(" 󰬎"  matches buffer-info remote-host buffer-position parrot selection-info)
    '(compilation misc-info battery irc mu4e gnus github debug minor-modes buffer-encoding major-mode process time "󰬎 "))
  (doom-modeline-def-modeline 'dashboard
    '(modals buffer-default-directory-simple remote-host)
    '(my-segment)))


(defun get-message-count ()
  "Read the content of a specific file and return it as a string."
  (let ((file-path "~/.message"))
    (if (file-exists-p file-path)
        (with-temp-buffer
          (insert-file-contents file-path)
          (let ((content (string-trim (buffer-string))))
            (cond
             ((string= content "")  "")
             ((string= content "0") "")
             ((string= content "1") "󰆄")
             ((string= content "2") "󰆄")
             ((string= content "3") "󰆄")
             ((string= content "4") "󰆄")
             ((string= content "5") "󰆄")
             ((string= content "6") "󰆄")
             ((string= content "7") "󰆄")
             ((string= content "8") "󰆄")
             ((string= content "9") "󰆄")
             (t "󰆄"))))
      "File not found")))

(defun run-applescript ()
  (interactive "fSelect AppleScript file: ")
  (let ((output-buffer "*AppleScript Output*"))
    (shell-command "osascript /Users/van/Desktop/获取微信消息数量.scpt" output-buffer)
    (display-buffer output-buffer)))

(defun my-powerline-segment ()
  "Insert a Powerline separator into the mode-line."
  (let* ((separator (powerline-current-separator))
         (separator-fn (intern (format "powerline-%s-%s" separator (car powerline-default-separator-dir)))))
    (propertize " " 'display (funcall separator-fn 'doom-modeline-bar 'mode-line))))
(use-package powerline
  :ensure t
  :config
  (setq powerline-default-separator 'arrow) ;; 分隔符样式
  (setq powerline-default-separator-dir '(right . left)))
