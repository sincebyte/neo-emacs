;;
(defun shell/configOnMac()
  (progn
    (setenv "JAVA_HOME"          "~/soft/jdk/zulu8.58.0.13-ca-jdk8.0.312-macosx_aarch64/zulu-8.jdk/Contents/Home/"     )
    (setenv "JAVA_11_ARM_HOME"   "/Users/van/soft/jdk/zulu11.52.13-ca-jdk11.0.13-macosx_aarch64"     )
    (setenv "JAVA_17_HOME"       "~/soft/jdk/jdk-17.0.6.jdk/Contents/Home"     )
    (setenv "JAVA_21_HOME"       "~/soft/jdk/jdk-21.0.6.jdk/Contents/Home"     )
    (setenv "JAVA_25_HOME"       "~/soft/jdk/jdk-25.0.2.jdk/Contents/Home"     )
    (setenv "JAVA_26_HOME"       "~/soft/jdk/jdk-26.jdk/Contents/Home/"        )
    (setenv "MAVEN_HOME"         "~/soft/apache-maven-3.6.1"                   )
    (setenv "DYLD_LIBRARY_PATH"  "/Applications/Emacs.app/"                    ) ;; rime config path
    (setenv "PATH"       (concat "/Applications/Emacs.app/:" (getenv "PATH" )) ) ;; maven exec, fzf , rg
    (setenv "https_proxy"        "http://vpn.local.com:10887"          )
    (setenv "http_proxy"         "http://vpn.local.com:10887"          )
    (add-to-list 'exec-path      "/Applications/Emacs.app/"                    )
    (add-to-list 'exec-path      "~/.config/emacs/bin/.tmp_npm/bin/")
    (setq shell-file-name (executable-find "bash"))
    (setq quickrun-focus-p t)
    (setq quickrun-timeout-seconds nil)
    (setq vterm-kill-buffer-on-exit t)
    (setq-default vterm-shell "/opt/homebrew/bin/fish")
    (setq-default explicit-shell-file-name "/opt/homebrew/bin/fish")
    ;; (setq-default vterm-shell (executable-find "fish"))
    ;; (setq-default explicit-shell-file-name (executable-find "fish"))
    (map! :n  "SPC r r"  'quickrun-shell                                       )
    (map! :ne "SPC v v" 'projectile-run-vterm                                  )))

(add-hook 'eshell-mode-hook (lambda () (interactive) (setq-local mode-line-format nil)))

;; win fzf fg exec Home dir
(defun shell/configOnWin()
  (progn
    (setenv "JAVA_HOME"     "c:/Java/jdk-17/"                     )
    (setenv "JAVA_17_HOME"  "c:/Java/jdk-17/"                     )
    (setenv "MAVEN_HOME"    "c:/Java/apache-maven"                )
    (setenv "https_proxy"   "http://vpn.local.com:10887"          )
    (setenv "http_proxy"    "http://vpn.local.com:10887"          )
    (add-to-list 'exec-path (concat (getenv "MAVEN_HOME") "/bin") ) ;; maven exec
    (map! :n  "SPC r r" 'quickrun-shell                           )
    (map! :ne "SPC v v" 'project-eshell                           )))


(if (eq system-type 'windows-nt)
    (progn (shell/configOnWin))
  (progn (shell/configOnMac)))

(defun my/vterm-with-dir-and-file-name ()
  (interactive)
  (let* ((dir (file-name-nondirectory
               (directory-file-name default-directory)))
         (file (when buffer-file-name
                 (file-name-nondirectory buffer-file-name)))
         (file-part (or file "no-file"))
         (bufname (format "*vterm: %s/%s*" dir file-part))
         (existing (get-buffer bufname)))
    (if existing
        (switch-to-buffer existing)
      (let ((default-directory default-directory))
        (vterm bufname)))))

;; eshell binding
(defun shell/openAndResetCursor ()
  (interactive)
  (progn
    (my/vterm-with-dir-and-file-name)
    (run-with-idle-timer
     0.1 nil 'vterm-reset-cursor-point)))

(defun my/force-hide-vterm-modeline ()
  "强制隐藏 vterm 的 modeline"
  (setq mode-line-format nil)
  (setq mode-line-cache nil))

(add-hook 'vterm-mode-hook #'evil-collection-vterm-escape-stay)
(add-hook 'vterm-mode-hook (lambda () 
  (add-hook 'after-change-major-mode-hook #'my/force-hide-vterm-modeline nil t)))
(add-hook 'buffer-list-update-hook (lambda ()
  (when (and (derived-mode-p 'vterm-mode) (not (eq mode-line-format nil)))
    (my/force-hide-vterm-modeline))))

(advice-add 'set-window-vscroll :after
  (defun me/vterm-toggle-scroll (&rest _)
    (when (eq major-mode 'vterm-mode)
      (if (> (window-end) (buffer-size))
          (when vterm-copy-mode (vterm-copy-mode-done nil))
        (vterm-copy-mode 1)))))

;; Remap C-k and C-j in eshell to use evil-scroll instead of default prompt navigation
;; These bindings will work in evil normal mode in eshell
(defun my-eshell-override-keys ()
  "Override eshell key bindings for evil normal mode."
  (define-key eshell-mode-map (kbd "C-k") nil) ; Remove old binding for eshell-previous-prompt
  (define-key eshell-mode-map (kbd "C-j") nil) ; Remove old binding for eshell-next-prompt
  (evil-define-key 'normal eshell-mode-map (kbd "C-k") #'evil-scroll-up)
  (evil-define-key 'normal eshell-mode-map (kbd "C-j") #'evil-scroll-down))

(with-eval-after-load 'eshell
  (with-eval-after-load 'evil
    (add-hook 'eshell-mode-hook #'my-eshell-override-keys)))

(defun my-vterm-evil-cursor ()
  (when (derived-mode-p 'vterm-mode)
    (setq cursor-type
          (if (evil-insert-state-p) 'bar 'box))))
(add-hook 'post-command-hook #'my-vterm-evil-cursor)

(after! quickrun
  (defun my/quickrun-eshell-keep-editable ()
    "quickrun-shell 结束后保持 eshell buffer 可编辑，保留 q 返回源窗口。"
    (when (derived-mode-p 'eshell-mode)
      (read-only-mode -1)
      (use-local-map eshell-mode-map)
      ;; 使用 quickrun 的退出函数，或者自定义
      (local-set-key (kbd "q") 
                     (lambda ()
                       (interactive)
                       (kill-buffer (current-buffer))
                       (quickrun--eshell-window-restore-original-window)))))

  (advice-add 'quickrun--eshell-post-hook :after #'my/quickrun-eshell-keep-editable))

(after! quickrun
  (defun my/quickrun-eshell-keep-editable ()
    (when (derived-mode-p 'eshell-mode)
      (read-only-mode -1)
      (use-local-map eshell-mode-map)
      (evil-insert-state)  ; 进入 insert mode
      (local-set-key (kbd "q") #'quickrun--eshell-window-restore)))

  (advice-add 'quickrun--eshell-post-hook :after #'my/quickrun-eshell-keep-editable))
