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

  (defun my/create-modeline-fontset ()
    (create-fontset-from-fontset-spec
     "-*-JetBrains Mono-normal-*-*-*-17-*-*-*-*-*-fontset-modeline,
     han:-*-方正悠宋+ GBK-normal-*-*-*-19-*-*-*-*-*-*,
     cjk-misc:-*-方正悠宋+ GBK-normal-*-*-*-19-*-*-*-*-*-*"))

  (set-face-attribute 'doom-modeline-buffer-file nil
                      :fontset (my/create-modeline-fontset)
                      :foreground "black"
                      :background "#9d81ba"
                      :weight 'bold)
  (set-face-attribute 'doom-modeline-buffer-modified nil
                      :fontset (my/create-modeline-fontset)
                      :foreground "gold"
                      :background "#9d81ba"
                      :weight 'bold)

  (set-face-attribute 'doom-modeline-evil-normal-state nil
                      :inherit 'doom-modeline
                      :background "#6fb593"
                      :foreground "black"
                      :weight 'bold)
  (defface doom-modeline-evil-normal-alpha-state
    '((t :inherit doom-modeline
       :background "#619c80"
       :foreground "black"
       :weight bold))
    "Face for evil normal state in doom-modeline (alpha variant)."
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-evil-insert-state nil
                      :inherit 'doom-modeline
                      :background "#00bff9"
                      :foreground "black"
                      :weight 'bold)
  (defface doom-modeline-evil-insert-alpha-state
    '((t :inherit doom-modeline
       :background "#02a3d4"
       :foreground "black"
       :weight bold))
    "Face for evil normal state in doom-modeline (alpha variant)."
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-evil-visual-state nil
                      :inherit 'doom-modeline
                      :background "#9d81ba"
                      :foreground "black"
                      :weight 'bold)
  (defface doom-modeline-evil-visual-alpha-state
    '((t :inherit doom-modeline
       :background "#8770a0"
       :foreground "black"
       :weight bold))
    "Face for evil normal state in doom-modeline (alpha variant)."
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-evil-replace-state nil
                      :inherit 'doom-modeline
                      :background "#ef5350"
                      :foreground "black"
                      :weight 'bold)
  (defface doom-modeline-evil-replace-alpha-state
    '((t :inherit doom-modeline
       :background "#ca4b49"
       :foreground "black"
       :weight bold))
    "Face for evil normal state in doom-modeline (alpha variant)."
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-evil-motion-state nil
                      :inherit 'doom-modeline
                      :background "#4876ae"
                      :foreground "black"
                      :weight 'bold)
  (defface doom-modeline-meow-motion-alpha-state
    '((t :inherit doom-modeline
       :background "#395b84"
       :foreground "black"
       :weight bold))
    "Face for evil normal state in doom-modeline (alpha variant)."
    :group 'doom-modeline)

  (fresh/modelineconfig)
  (add-hook '+workspace-new-hook #'fresh/modelineconfig)
  )

(defface doom-modeline-meow-motion-alpha-state
  '((t :inherit doom-modeline
     :background "#395b84"
     :foreground "black"
     :weight bold))
  "Face for evil normal state in doom-modeline (alpha variant)."
  :group 'doom-modeline)

                                        ; available value of separator
;; chamfer, contour, curve, rounded, roundstub, slant, wave, zigzag, and nil.
(defun fresh/modelineconfig ()
  (doom-modeline-def-segment my-segment
    "My custom segment "
    (let ((face
           (if (doom-modeline--active)
               (cond
                ((eq evil-state 'normal)   'doom-modeline-evil-normal-state)
                ((eq evil-state 'insert)   'doom-modeline-evil-insert-state)
                ((eq evil-state 'visual)   'doom-modeline-evil-visual-state)
                ((eq evil-state 'replace)  'doom-modeline-evil-replace-state)
                ((eq evil-state 'motion)   'doom-modeline-evil-motion-state)
                (t                         'doom-modeline-evil-normal-state))
             'doom-modeline-evil-normal-state))
          (charc
           (cond
            ((eq evil-state 'normal)  " NORMAL ")
            ((eq evil-state 'insert)  " INSERT ")
            ((eq evil-state 'visual)  " VISUAL ")
            ((eq evil-state 'replace) " REPLACE ")
            ((eq evil-state 'emacs)   " EMACS ")
            ((eq evil-state 'motion)  " MOTION ")
            (t " EMACS "))))
      (concat
       (propertize (concat "" charc "") 'face face))))
  (doom-modeline-def-segment powerline-evil-right
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (cdr powerline-default-separator-dir))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn
                                        (if (doom-modeline--active)
                                            (cond
                                             ((eq evil-state 'normal)   'doom-modeline-evil-normal-alpha-state)
                                             ((eq evil-state 'insert)   'doom-modeline-evil-insert-alpha-state)
                                             ((eq evil-state 'visual)   'doom-modeline-evil-visual-alpha-state)
                                             ((eq evil-state 'replace)  'doom-modeline-evil-replace-alpha-state)
                                             ((eq evil-state 'motion)   'doom-modeline-evil-motion-alpha-state)
                                             (t                         'doom-modeline-evil-normal-alpha-state))
                                          'doom-modeline-evil-normal-alpha-state)
                                        'mode-line ))))

  (doom-modeline-def-segment powerline-filename-right-1
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (cdr powerline-default-separator-dir ))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn 'mode-line 'doom-modeline-evil-visual-alpha-state ))))

  (doom-modeline-def-segment powerline-filename-right-2
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s" separator (cdr powerline-default-separator-dir )))))
      (propertize " " 'display (funcall separator-fn 'doom-modeline-evil-visual-alpha-state 'mode-line ))))

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
      (propertize " " 'display (funcall separator-fn 'org-code 'doom-modeline-evil-visual-alpha-state )
                  'face (doom-modeline-face 'doom-modeline-evil-visual-state))))

  (doom-modeline-def-segment powerline-separator-left-vcs
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (car powerline-default-separator-dir))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn 'mode-line 'doom-modeline-evil-normal-alpha-state)  )))

  (doom-modeline-def-segment powerline-separator-left-time
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (car powerline-default-separator-dir))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn 'mode-line 'doom-modeline-evil-insert-alpha-state )  )))

  (doom-modeline-def-segment powerline-separator-left-time-db
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (car powerline-default-separator-dir ))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn 'doom-modeline-evil-normal-alpha-state 'mode-line ))))

  ;; (doom-modeline-def-segment powerline-separator-left-git-empty
  ;;   "Insert a Powerline separator into the Doom Modeline."
  ;;   (let* ((separator 'arrow) ;; 获取当前分隔符
  ;;          (separator-fn (intern (format "powerline-%s-%s"
  ;;                                        separator
  ;;                                        (car powerline-default-separator-dir ))))) ;; 获取分隔符函数
  ;;     (propertize " " 'display (funcall separator-fn 'doom-modeline-evil-visual-alpha-state 'mode-line ))))

  (doom-modeline-def-segment powerline-separator-left-git-empty
    "Insert a Powerline separator into the Doom Modeline."
    (propertize " " 'display
        (powerline-arrow-right
                'doom-modeline-evil-visual-alpha-state
                'mode-line)))


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
     'face 'doom-modeline-evil-visual-state))

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

  (doom-modeline-def-segment my-time
    "Display the current time in HH:mm:ss format."
    (propertize (format-time-string " %H:%M ")
                'face 'doom-modeline-evil-insert-state))
  (defun my-buffer-file-name ()
    "Return a short file name for current buffer.
If another buffer has the same file name, include one parent directory
to disambiguate."
    (let* ((filename (buffer-file-name))
           (basename (file-name-nondirectory filename)))
      (if (not filename)
          (buffer-name)
        (if (seq-some (lambda (buf)
                        (let ((other (buffer-file-name buf)))
                          (and other
                               (not (eq buf (current-buffer)))
                               (string= basename (file-name-nondirectory other)))))
                      (buffer-list))
            ;; 文件名重复 → 显示 上级目录/文件名
            (concat (file-name-nondirectory
                     (directory-file-name (file-name-directory filename)))
                    "/" basename)
          ;; 否则只显示文件名
          basename))))

  (doom-modeline-def-segment my-filename
    "Show buffer filename with disambiguation if needed."
    (propertize
     (concat " " (my-buffer-file-name) " ")
     'face (if (buffer-modified-p)
               'doom-modeline-buffer-modified
             'doom-modeline-buffer-file)))
  (defun my-git-branch-with-dirty ()
    "Return git branch name, with * if buffer or repo is modified."
    (if-let* ((file (buffer-file-name))
                (backend (vc-backend file))
                ((eq backend 'Git))
                (branch (vc-git--symbolic-ref file)))
      (let ((state (vc-state file)))
        (concat " " branch (if (eq state 'up-to-date) "" "꙳") " "))
      " nil "))
  (doom-modeline-def-segment my-git-branch
    "Show git branch, with * if modified."
    (when-let ((branch (my-git-branch-with-dirty)))
      (propertize branch 'face 'doom-modeline-evil-normal-state)))

  (doom-modeline-def-segment empty-segment
    (propertize (concat " " "") 'face 'doom-modeline-evil-emacs-state))
  ;; (display-battery-mode 1)
  (display-time-mode 1)
  (doom-modeline-def-modeline 'main
    '(my-segment powerline-evil-right powerline-filename-right-1 my-filename powerline-filename-right-2 wechat-msg-count matches parrot selection-info)
    '(misc-info minor-modes input-method buffer-encoding powerline-separator-left my-major-mode
      powerline-separator-left-git-empty powerline-separator-left-vcs my-git-branch powerline-separator-left-time-db powerline-separator-left-time my-time ))
  (doom-modeline-def-modeline 'vcs
    '(my-segment powerline-evil-right wechat-msg-count matches parrot selection-info)
    '(compilation misc-info battery irc mu4e gnus github debug minor-modes buffer-encoding process empty-segment powerline-separator-left my-major-mode
      powerline-separator-left-git-empty powerline-separator-left-time my-time ))
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

;; (defun my-powerline-segment ()
;;   "Insert a Powerline separator into the mode-line."
;;   (let* ((separator (powerline-current-separator))
;;          (separator-fn (intern (format "powerline-%s-%s" separator (car powerline-default-separator-dir)))))
;;     (propertize " " 'display (funcall separator-fn 'doom-modeline-bar 'mode-line))))
(use-package powerline
  ;; :ensure t
  :config
  (setq powerline-default-separator 'arrow) ;; 分隔符样式
  (setq powerline-default-separator-dir '(right . left)))

(defun my-change-fonts-on-big-font-mode ()
  (if doom-big-font-mode
      (progn
        (custom-set-faces
         '(indent-bars-face                  ((t (:family "Kode Mono" :height 210))))
         '(line-number                       ((t (:family "JetBrains Mono" :weight bold :slant italic :height 210))))
         '(line-number-current-line          ((t (:family "JetBrains Mono" :weight bold :slant italic :foreground "white" :height 210))))
         '(mode-line ((t (:family "IBM Plex Mono" :box nil :height 175))))
         '(mode-line-inactive ((t (:family "IBM Plex Mono" :box nil :height 175))))))
    (progn
      (custom-set-faces
       '(indent-bars-face                  ((t (:family "Kode Mono" :height 170))))
       '(line-number                       ((t (:family "JetBrains Mono" :weight bold :slant italic :height 170))))
       '(line-number-current-line          ((t (:family "JetBrains Mono" :weight bold :slant italic :foreground "white" :height 170))))
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
