;;; neoemacs/modelinexp/config.el -*- lexical-binding: t; -*-
;;(use-package doom-modeline
;;  :init
;;  (setq doom-modeline-height 20))

(setq
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

(with-eval-after-load 'which-key
  (set-face-attribute 'which-key-key-face nil :family "IBM Plex Mono")
  (set-face-attribute 'which-key-command-description-face nil :family "IBM Plex Mono")
  (set-face-attribute 'which-key-separator-face nil :family "IBM Plex Mono"))

(with-eval-after-load 'doom-modeline
  (defface powerline-evil-normal-state   '((t (:background "nil"   :weight bold))) "")
  (defface powerline-evil-insert-state   '((t (:background "nil"   :weight bold))) "")
  (defface powerline-evil-replace-state  '((t (:background "nil"   :weight bold))) "")
  (defface powerline-evil-motion-state   '((t (:background "nil"   :weight bold))) "")
  (defface powerline-evil-visual-state   '((t (:background "nil"   :weight bold))) "")
  (defface powerline-evil-emacs-state    '((t (:background "nil"   :weight bold))) "")
  (custom-set-faces '(doom-modeline-panel ((t (:background unspecified :foreground "#da8548" :weight bold :height 150)))))

  (let ((org-level-1f (face-attribute 'outline-1 :foreground))
        (highlight-foreground (face-attribute 'org-date-selected :foreground))
        (highlight-background (face-attribute 'org-date-selected :background)))
    (custom-set-faces  '(indent-bars-face                  ((t (:family "Kode Mono" ))))
                       '(line-number                       ((t (:family "JetBrains Mono" :weight bold :slant italic))))
                       `(line-number-current-line          ((t (:family "JetBrains Mono" :weight bold :slant italic :foreground ,org-level-1f ))))
                       `(org-block-begin-line              ((t (:family "IBM Plex Mono" :box nil :foreground ,org-level-1f :weight bold))))
                       `(org-block-end-line                ((t (:family "IBM Plex Mono" :box nil :foreground ,org-level-1f :weight bold))))
                       `(org-modern-indent-bracket-line    ((t (:family "Kode Mono"     :box nil :foreground ,org-level-1f))))
                       `(+workspace-tab-selected-face      ((t (:family "IBM Plex Mono" :box nil :foreground "black" :background ,highlight-foreground :weight bold))))
                       '(+workspace-tab-face               ((t (:family "IBM Plex Mono" :box nil :weight bold))))
                       '(mode-line                         ((t (:family "IBM Plex Mono" :box nil :height 150 :underline nil))))  ;; 去掉 modeline 的边框
                       '(mode-line-inactive                ((t (:family "IBM Plex Mono" :box nil :height 150 :underline nil)))))) ;; 去掉非活动 modeline 的边框
  (set-face-attribute 'doom-modeline-time nil
                      :foreground (face-attribute 'org-level-2 :foreground nil t)
                      :background (face-attribute 'doom-modeline-evil-insert-state :foreground nil t)
                      :weight 'bold)
  (set-face-attribute 'doom-modeline-buffer-file nil
                      :foreground (face-attribute 'org-level-3 :foreground nil t)
                      :weight 'bold)
  (set-face-attribute 'doom-modeline-evil-normal-state nil
                      :background (face-attribute 'doom-modeline-evil-normal-state :foreground nil t)
                      :foreground "black"
                      :weight 'bold)
  (set-face-attribute 'doom-modeline-evil-insert-state nil
                      :background (face-attribute 'doom-modeline-evil-insert-state :foreground nil t)
                      :foreground "black"
                      :weight 'bold)
  (set-face-attribute 'doom-modeline-evil-visual-state nil
                      :background (face-attribute 'doom-modeline-evil-visual-state :foreground nil t)
                      :foreground "black"
                      :weight 'bold)
  (set-face-attribute 'doom-modeline-evil-replace-state nil
                      :background (face-attribute 'doom-modeline-evil-replace-state :foreground nil t)
                      :foreground "black"
                      :weight 'bold)
  (set-face-attribute 'doom-modeline-evil-motion-state nil
                      :background (face-attribute 'doom-modeline-evil-motion-state :foreground nil t)
                      :foreground "black"
                      :weight 'bold)

  (set-face-attribute 'powerline-evil-normal-state nil
                      :background (face-attribute 'doom-modeline-evil-normal-state :background nil t)
                      :weight 'bold)
  (set-face-attribute 'powerline-evil-insert-state nil
                      :background (face-attribute 'doom-modeline-evil-insert-state :background nil t)
                      :weight 'bold)
  (set-face-attribute 'powerline-evil-visual-state nil
                      :background (face-attribute 'doom-modeline-evil-visual-state :background nil t)
                      :weight 'bold)
  (set-face-attribute 'powerline-evil-replace-state nil
                      :background (face-attribute 'doom-modeline-evil-replace-state :background nil t)
                      :weight 'bold)
  (set-face-attribute 'powerline-evil-motion-state nil
                      :background (face-attribute 'doom-modeline-evil-motion-state :background nil t)
                      :weight 'bold)

  )
(after! doom-modeline
  (fresh/modelineconfig)
  (add-hook '+workspace-new-hook #'fresh/modelineconfig))
(after! dashboard
  (fresh/modelineconfig))
                                        ; available value of separator
                                        ;  alternate, arrow, arrow-fade, bar, box, brace, butt,
;; chamfer, contour, curve, rounded, roundstub, slant, wave, zigzag, and nil.
(defun fresh/modelineconfig ()
  (doom-modeline-def-segment powerline-separator-right
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (cdr powerline-default-separator-dir ))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn 'mode-line 'doom-modeline-evil-emacs-state ))))

  (doom-modeline-def-segment powerline-separator-right-vert
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (cdr powerline-default-separator-dir ))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn 'doom-modeline-evil-emacs-state 'mode-line ))))

  (doom-modeline-def-segment powerline-separator-left
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (car powerline-default-separator-dir))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn 'doom-modeline-evil-operator-state 'org-code)  )))
  (doom-modeline-def-segment powerline-separator-left-vcs
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (car powerline-default-separator-dir))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn 'org-code 'doom-modeline-evil-operator-state)  )))

  (doom-modeline-def-segment powerline-separator-left-time
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (car powerline-default-separator-dir))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn 'doom-modeline-evil-operator-state 'doom-modeline-meow-motion-state )  )))

  (doom-modeline-def-segment powerline-evil-right
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (cdr powerline-default-separator-dir))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn (when (doom-modeline--active)
                                                       (if (eq evil-state 'normal) 'powerline-evil-normal-state
                                                         (if (eq evil-state 'insert) 'powerline-evil-insert-state
                                                           (if (eq evil-state 'visual) 'powerline-evil-visual-state
                                                             (if (eq evil-state 'replace) 'powerline-evil-replace-state
                                                               (if (eq evil-state 'motion) 'powerline-evil-motion-state)
                                                               'powerline-evil-normal-state))))) 'doom-modeline-evil-operator-state )  )))

  (doom-modeline-def-segment powerline-evil-left
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (car powerline-default-separator-dir))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn 'doom-modeline-evil-emacs-state  (when (doom-modeline--active)
                                                                                        (if (eq evil-state 'normal) 'powerline-evil-normal-state
                                                                                          (if (eq evil-state 'insert) 'powerline-evil-insert-state
                                                                                            (if (eq evil-state 'visual) 'powerline-evil-visual-state
                                                                                              (if (eq evil-state 'replace) 'powerline-evil-replace-state
                                                                                                (if (eq evil-state 'motion) 'powerline-evil-motion-state)
                                                                                                'powerline-evil-normal-state))))) )  )))

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
     'face (doom-modeline-face 'org-block-end-line)))
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
           (if (eq evil-state 'normal) (if (display-graphic-p)           " NORMAL "  " NORMAL "  )
             (if (eq evil-state 'insert) (if (display-graphic-p)         " INSERT "  " INSERT "  )
               (if (eq evil-state 'visual) (if (display-graphic-p)       " VISUAL "  " VISUAL "  )
                 (if (eq evil-state 'replace) (if (display-graphic-p)    " REPLACE " " REPLACE " )
                   (if (eq evil-state 'emacs) (if (display-graphic-p)    " EMACS "   " EMACS "   )
                     (if (eq evil-state 'motion) (if (display-graphic-p) " MOTION "  " MOTION "  ))
                     "▇")))))))
      (concat
       (propertize (concat "" charc "") 'face face))))
  (doom-modeline-def-segment my-custom-segment
    (my-add-x-to-segment 'doom-modeline--major-mode-segment))
  (doom-modeline-def-segment wechat-msg-count
    "A custom segment that reads content from a local file."
    (propertize (concat "" (get-message-count)) 'face 'doom-modeline-evil-emacs-state))
  (doom-modeline-def-segment eyeMonitor-count
    "A custom segment that reads content from a local file."
    (let ((count (get-eyeMonitor-count)))  ; 定义局部变量 count
      (cond
       ((<= count 20) (propertize (concat "󰫃" "") 'face 'org-level-6) )
       ((<= count 40) (propertize (concat "󰫄" "") 'face 'org-level-4) )
       ((<= count 60) (propertize (concat "󰫅" "") 'face 'org-level-1) )
       ((<= count 80) (propertize (concat "󰫆" "") 'face 'org-level-5) )
       ((<= count 99) (propertize (concat "󰫇" "") 'face 'nerd-icons-lred) )
       ((= count 100) (propertize (concat "󰫈" "") 'face 'error) )
       (t (propertize (concat "󰫃" "") 'face 'diary)))))

  (doom-modeline-def-segment hr-count
    "A custom segment that reads content from a local file."
    (let ((count (get-hr-count)))  ; 定义局部变量 count
      (concat
       (propertize " 󰐰 " 'face 'error)  ;; 图标的颜色
       (propertize (number-to-string count) 'face 'org-todo)  ;; 数字的颜色
       (propertize " " 'face 'org-table))))
  (doom-modeline-def-segment my-time
    "Display the current time in HH:mm:ss format."
    (propertize (format-time-string " %H:%M ")
                'face 'doom-modeline-meow-motion-state))

  (doom-modeline-def-segment empty-segment
    (propertize (concat " " "") 'face 'doom-modeline-evil-emacs-state))
  ;; (display-battery-mode 1)
  (display-time-mode 1)
  (doom-modeline-def-modeline 'main
    '(my-segment powerline-evil-right empty-segment eyeMonitor-count wechat-msg-count buffer-info matches parrot selection-info)
    '(misc-info minor-modes input-method buffer-encoding powerline-separator-left
      my-major-mode powerline-separator-left-vcs vcs powerline-separator-left-time my-time ))
  (doom-modeline-def-modeline 'vcs
    '(my-segment powerline-evil-right empty-segment eyeMonitor-count wechat-msg-count matches buffer-info remote-host parrot selection-info)
    '(compilation misc-info battery irc mu4e gnus github debug minor-modes buffer-encoding major-mode process powerline-separator-left-time my-time ))
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
             ((string= content "1") " 󰆄")
             ((string= content "2") " 󰆄")
             ((string= content "3") " 󰆄")
             ((string= content "4") " 󰆄")
             ((string= content "5") " 󰆄")
             ((string= content "6") " 󰆄")
             ((string= content "7") " 󰆄")
             ((string= content "8") " 󰆄")
             ((string= content "9") " 󰆄")
             (t " 󰆄"))))
      "File not found")))

(defun get-hr-count ()
  "Read the content of a specific file and return it as a string."
  (let ((file-path "~/.hr"))
    (if (file-exists-p file-path)
        (with-temp-buffer
          (insert-file-contents file-path)
          (string-to-number (string-trim (buffer-string)))) 46)))

(defun get-eyeMonitor-count ()
  "Read the content of a specific file and return it as a number."
  (let ((file-path "~/.eyeMonitor"))
    (if (file-exists-p file-path)
        (with-temp-buffer
          (insert-file-contents file-path)  ; 读取文件内容到缓冲区
          (let ((content (string-trim (buffer-string))))  ; 去除两端空白
            (if (string-empty-p content)  ; 如果内容为空，返回 0
                0
              (string-to-number content))))  ; 转换为数字
      0)))  ; 如果文件不存在，返回 0

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
  ;; :ensure t
  :config
  (setq powerline-default-separator 'arrow) ;; 分隔符样式
  (setq powerline-default-separator-dir '(right . left)))

(defun my-change-fonts-on-big-font-mode ()
  (if doom-big-font-mode
      (progn
        (custom-set-faces
         '(mode-line ((t (:family "IBM Plex Mono" :box nil :height 175))))
         '(mode-line-inactive ((t (:family "IBM Plex Mono" :box nil :height 175))))))
    (progn
      (custom-set-faces
       '(mode-line ((t (:family "IBM Plex Mono" :box nil :height 150))))
       '(mode-line-inactive ((t (:family "IBM Plex Mono" :box nil :height 150))))))
    (setq powerline-scale (if doom-big-font-mode 1.5 1))
    (powerline-reset)))
(defun my-update-powerline-scale ()
  "Adjust powerline scale based on doom-big-font-mode."
  (setq powerline-scale (if doom-big-font-mode 1.5 1))
  (powerline-reset))

(add-hook 'doom-big-font-mode-hook 'my-change-fonts-on-big-font-mode)
(add-hook 'doom-big-font-mode-hook 'my-update-powerline-scale)


;; (add-hook 'doom-big-font-mode-hook #'reset-to-default-font)

(add-hook 'doom-modeline-mode-hook
          (lambda ()
            (setq doom-modeline-spc "")    ; 替换普通分隔符
            (setq doom-modeline-wspc ""))) ; 替换宽空格

(run-with-timer 0 1 'force-mode-line-update)
                                        ;(doom-modeline-refresh-bars)
(add-hook 'after-init-hook
          (lambda ()
            (setq-local line-spacing nil)))
