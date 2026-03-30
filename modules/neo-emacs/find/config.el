;; (setq consult-project-function (lambda (_) (locate-dominating-file "." ".git")))
;; (setq projectile-project-root-files '(".git"))


(map! :ne "SPC z"   'consult-find       )
(map! :ne "SPC v c" 'consult-ripgrep    )
(map! :ie "C-i"     'consult-yank-pop   )
(map! :ne "SPC f j" 'jump-to-class-at-point)  ; 快速跳转到光标处的类和行号

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
      :n "J" nil
      "J" nil)
(map! :after dired
      :map dired-mode-map
      :n "J" #'+workspace/switch-left)
(after! dired
  (map! :map dired-mode-map
        :n "c" nil
        "c" nil))
(after! dired
  (map! :map dired-mode-map
        :n "c" #'dired-create-empty-file))
(map! :after dired
      :map dired-mode-map
      :ne "h" #'dired-up-directory)
(map! :after dired
      :map dired-mode-map
      :ne "l" #'dired-find-file)
(map! :after magit
      :map magit-mode-map
      :ne "K" nil)
(map! :after evil
      :map evil-normal-state-map
      :ne "K" nil)
(map! :after magit
      :map magit-mode-map
      :ne "K" #'+workspace/switch-right)
(map! :after evil
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


(defun jump-to-class-at-point ()
  "从当前光标位置提取类名和行号，跳转到指定行。"
  (interactive)
  (let* ((current-symbol (thing-at-point 'symbol t))
         (raw-class-name (when current-symbol
                          (replace-regexp-in-string "[^A-Za-z0-9_.]" "" current-symbol)))
         class-name
         ;; 在当前行查找光标后的第一个数字
         (line-rest (buffer-substring-no-properties (point) (line-end-position)))
         (line-number (when (string-match "[0-9]+" line-rest)
                        (string-to-number (match-string 0 line-rest)))))
    
    ;; 如果原始类名包含点号（包.类格式），只取最后一个点号后的部分作为类名
    (when raw-class-name
      (setq class-name 
            (if (string-match "\\." raw-class-name)
                (car (last (split-string raw-class-name "\\.")))  ; 取最后一个点号后的部分
              raw-class-name)))
    
    (if (and class-name line-number)
        (let* ((project-root (projectile-project-root))
               (all-project-files (projectile-current-project-files))
               ;; 搜索项只使用类名，不需要转换为路径
               (search-term (concat class-name ".java"))
               (matching-files (cl-remove-if-not 
                               (lambda (f) 
                                 (or 
                                  (string= (file-name-nondirectory f) search-term) ; 完全匹配文件名
                                  (string-match (concat ".*" (regexp-quote class-name) ".*\\.java$") (file-name-nondirectory f)))) ; 部分匹配
                               all-project-files)))
          (if matching-files
              (progn
                (message "Found %d matching files for '%s'" (length matching-files) search-term)
                (cond
                 ;; 如果找到了确切匹配的文件
                 ((= (length matching-files) 1)
                  (find-file (expand-file-name (car matching-files) project-root))
                  (goto-line line-number)
                  (message "Jumped to %s at line %d" search-term line-number))
                 ;; 如果找到多个匹配文件，让用户选择
                 ((> (length matching-files) 1)
                  (let ((selected-file (completing-read "Select file from matches: " matching-files)))
                    (find-file (expand-file-name selected-file project-root))
                    (goto-line line-number)))))
            (message "No matches found for '%s'" search-term)))
      (message "Cannot find class name and line number at cursor position. Found: class=%s, line=%s" class-name line-number))))