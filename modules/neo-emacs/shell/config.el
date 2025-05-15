;;
(defun shell/configOnMac()
  (progn
    (setenv "JAVA_HOME"          "~/soft/jdk/zulu8.58.0.13-ca-jdk8.0.312-macosx_aarch64/zulu-8.jdk/Contents/Home/"     )
    (setenv "JAVA_17_HOME"       "~/soft/jdk/jdk-17.0.6.jdk/Contents/Home"     )
    (setenv "MAVEN_HOME"         "~/soft/apache-maven-3.6.1"                   )
    (setenv "DYLD_LIBRARY_PATH"  "/Applications/Emacs.app/"                    ) ;; rime config path
    (setenv "PATH"       (concat "/Applications/Emacs.app/:" (getenv "PATH" )) ) ;; maven exec, fzf , rg
    (add-to-list 'exec-path      "/Applications/Emacs.app/"                    )
    (setq shell-file-name (executable-find "bash"))
    (setq-default vterm-shell "/opt/homebrew/bin/fish")
    (setq-default explicit-shell-file-name "/opt/homebrew/bin/fish")
    ;; (setq-default vterm-shell (executable-find "fish"))
    ;; (setq-default explicit-shell-file-name (executable-find "fish"))
    (map! :n  "SPC r r"  'quickrun-shell                                       )
    (map! :ne "SPC v v" 'projectile-run-vterm                                  )))

;; win fzf fg exec Home dir
(defun shell/configOnWin()
  (progn
    (setenv "JAVA_HOME"     "c:/Java/jdk-17/"                     )
    (setenv "JAVA_17_HOME"  "c:/Java/jdk-17/"                     )
    (setenv "MAVEN_HOME"    "c:/Java/apache-maven"                )
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
    (vterm)  ;; 启动 vterm
    (run-with-idle-timer
     0.1 nil 'vterm-reset-cursor-point)))
