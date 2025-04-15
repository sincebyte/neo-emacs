;; (setq consult-project-function (lambda (_) (locate-dominating-file "." ".git")))
;; (setq projectile-project-root-files '(".git"))


(map! :ne "SPC z"   'consult-find       )
(map! :ne "SPC v c" 'consult-ripgrep    )
(map! :ie "C-i"     'consult-yank-pop   )

;; (use-package dirvish
;;   ;; :init
;;   ;; (dirvish-override-dired-mode)
;;   :config
;;   (setq dirvish-hide-details t
;;         dirvish-use-header-line nil
;;         dirvish-use-mode-line t
;;         ;; dirvish-header-line-height 10
;;         ;; dirvish-mode-line-height 6
;;         dirvish-hide-cursor t
;;         delete-by-moving-to-trash t
;;         dirvish-default-layout '(0 0.4 0.6)
;;         dirvish-attributes
;;         '(nerd-icons file-size vc-state git-msg)
;;         dirvish-header-line-format
;;         '(:left (path) :right (free-space))))
;; (add-hook 'dirvish-find-entry-hook
;;           (lambda (&rest _) (setq-local truncate-lines t)))

(map! :after dired
      :map dired-mode-map
      :ne "J" nil)
(map! :after dired
      :map dired-mode-map
      :ne "J" #'+workspace/switch-left)
(map! :after dired
      :map dired-mode-map
      :ne "c" nil)
(map! :after dired
      :map dired-mode-map
      :ne "c" #'dired-create-empty-file)
(map! :after dired
      :map dired-mode-map
      :ne "h" #'dired-up-directory)
(map! :after dired
      :map dired-mode-map
      :ne "l" #'dired-find-file)

(map! :after magit
      :map magit-mode-map
      :ne "K" nil)
(map! :after magit
      :map magit-mode-map
      :ne "K" #'+workspace/switch-right)
(map! :after magit
      :map magit-mode-map
      :ne "J" nil)
(map! :after magit
      :map magit-mode-map
      :ne "J" #'+workspace/switch-left)

(setq bookmark-default-file "~/org/org-roam/bookmarks")
(setq consult-ripgrep-default-directory (projectile-project-root))

;; (defun my-project-root-from-git-rev-parse (_dir)
;;   (let ((root (shell-command-to-string (format "git -C %s rev-parse --show-toplevel" _dir))))
;;     (if (and root (not (string-empty-p root)))
;;         (file-name-as-directory (string-trim root))  ;; 返回根目录路径
;;       nil)))
(defun my-project-root-from-git-rev-parse (_dir)
  (if (file-remote-p _dir)  ;; 检查路径是否是 Tramp 路径
      (progn
        nil) ;; 返回默认设置，或你可以指定其他值
    (let ((root (shell-command-to-string (format "git -C %s rev-parse --show-toplevel" _dir))))
      (if (and root (not (string-empty-p root)))
          (file-name-as-directory (string-trim root))
        nil))))


(setq projectile-project-root-functions
      '(my-project-root-from-git-rev-parse
        projectile-root-local
        projectile-root-marked
        projectile-root-bottom-up
        projectile-root-top-down
        projectile-root-top-down-recurring))


(add-hook 'dired-mode-hook
          (lambda ()
            (buffer-face-set
             '(:family "M PLUS Code Latin 50" :height 140))))

(defun jump-to-java-error ()
  "从当前日志行中提取文件名和行号，跳转到对应的 Java 文件和行号。"
  (interactive)
  (let ((line (thing-at-point 'line t)))  ;; 获取当前光标所在行
    (when (and line (string-match "\\.?\\([a-zA-Z]+[0-9]?\\).java:\\([0-9]+\\)" line))  ;; 确保有冒号
      (let* ((file-name (match-string 1 line))  ;; 捕获文件名
             (line-number (string-to-number (match-string 2 line))))  ;; 捕获行号
        (message  file-name )
        (let* ((files (projectile-current-project-files)))  ;; 获取当前项目的文件列表
          (projectile-find-file-dwim file-name)
          ;; (find-file (completing-read "Choose file: " (projectile-current-project-files) nil nil file-name))
          (goto-line line-number)))           ;; 跳转到指定行
      )))
