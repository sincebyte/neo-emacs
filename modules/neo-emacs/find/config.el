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
  "从当前光标所在行提取类名和行号，使用改进的文件搜索方法跳转到指定行。"
  (interactive)
  (let ((line (thing-at-point 'line t)))  ;; 获取当前光标所在行
    (when line
      ;; 尝试匹配多种格式：类名#行号、类名:行号、Class.java:行号等等，以及日志格式
      (let ((patterns '("\\(?:[0-9-]+ [0-9:.]+ \\[[^]]+\\] [A-Z]+ +\\)?\\([A-Za-z_][A-Za-z0-9_.]*\\):\\([0-9]+\\)" ; 日志格式: 2026-03-29 11:16:24.665 [http-nio-8080-exec-8] INFO com.skytech.domain.uav.service.MqttGatewayPublish:53 
                        "\\([A-Za-z_][A-Za-z0-9_.]*\\)[#:.:]\\([0-9]+\\)"     ; Class#123, Class:123, Class.123
                        "\\([A-Za-z_][A-Za-z0-9_]*\\.java\\):\\([0-9]+\\)"   ; Class.java:123
                        "\\([A-Za-z_][A-Za-z0-9_]*\\.py\\):\\([0-9]+\\)"     ; Class.py:123
                        "\\([A-Za-z_][A-Za-z0-9_]*\\.js\\):\\([0-9]+\\)"     ; Class.js:123
                        "\\([A-Za-z_][A-Za-z0-9_]*\\.ts\\):\\([0-9]+\\)"     ; Class.ts:123
                        "\\([A-Za-z_][A-Za-z0-9_]*\\.c\\):\\([0-9]+\\)"      ; Class.c:123
                        "\\([A-Za-z_][A-Za-z0-9_]*\\.cpp\\):\\([0-9]+\\)"    ; Class.cpp:123
                        "\\([A-Za-z_][A-Za-z0-9_]*\\.h\\):\\([0-9]+\\)"      ; Class.h:123
                        "\\([A-Za-z_][A-Za-z0-9_]*\\.hpp\\):\\([0-9]+\\)"    ; Class.hpp:123
                        "\\([A-Za-z_][A-Za-z0-9_]*\\.cc\\):\\([0-9]+\\)"     ; Class.cc:123
                        "\\([^ \t\n\r\f\v:]+\\):\\([0-9]+\\)"                ; 任意路径:行号
                        )))
        (catch 'found
          (dolist (pattern patterns)
            (when (string-match pattern line)
              (let* ((file-name-or-class (match-string 1 line))
                     (line-number (string-to-number (match-string 2 line)))
                     ;; 如果匹配的是完整路径，则直接使用文件名部分
                     (search-term (if (string-match "[/\\]" file-name-or-class)
                                      (file-name-nondirectory file-name-or-class)
                                    file-name-or-class))
                     ;; 如果是Java包风格的类名（含点号），尝试转换为文件路径
                     (file-search-term (if (string-match "\\." file-name-or-class)
                                           (concat (replace-regexp-in-string "\\." "/" file-name-or-class) ".java")
                                         search-term)))
                (message "Attempting to find: %s at line: %d" search-term line-number)
                ;; 替换 projectile-find-file 调用，因为该函数不接受参数预填搜索框
                (let* ((project-root (projectile-project-root))
                       (all-project-files (projectile-current-project-files))
                       ;; 直接使用文件名搜索
                       (matching-files (cl-remove-if-not 
                                       (lambda (f) 
                                         (or 
                                          (string= (file-name-nondirectory f) search-term) ; 完全匹配文件名
                                          (string-match (concat ".*" (regexp-quote search-term) ".*") (file-name-nondirectory f)) ; 部分匹配
                                          (string-match (concat "/" (regexp-quote search-term) "$") f)   ; 路径末尾匹配
                                          (string-match (concat "\\\\" (regexp-quote search-term) "$") f) ; Windows路径匹配
                                          ;; 如果是Java包格式，也检查转换后的路径
                                          (let ((converted-path (replace-regexp-in-string "\\." "/" search-term)))
                                            (or 
                                             (string-match (regexp-quote converted-path) f)
                                             (string-match (concat "/" (regexp-quote converted-path) "\\.java$") f)))))
                                       all-project-files)))
                  ;; 打印搜索结果
                  (if matching-files
                      (progn
                        (message "Found %d matching files for '%s':" (length matching-files) search-term)
                        (dolist (file matching-files)
                          (message "  - %s" file)))
                    (message "No matches found for '%s'" search-term))
                  
                  (cond
                   ;; 如果找到了确切匹配的文件
                   ((= (length matching-files) 1)
                    (find-file (expand-file-name (car matching-files) project-root))
                    (goto-line line-number)
                    (throw 'found t))
                   ;; 如果找到多个匹配文件，让用户选择
                   ((> (length matching-files) 1)
                    (let ((selected-file (completing-read "Select file from matches: " matching-files)))
                      (find-file (expand-file-name selected-file project-root))
                      (goto-line line-number)
                      (throw 'found t)))
                   ;; 如果失败，尝试使用更具体的搜索
                   (t
                    (message "Attempting alternatives for: %s" search-term)
                    (let* ((project-files (projectile-current-project-files))
                           (more-specific-matching-files (cl-remove-if-not 
                                                         (lambda (f) 
                                                           (or 
                                                            (string= (file-name-base f) (file-name-base search-term)) ; 基本名称匹配
                                                            (string-match (concat ".*" (regexp-quote search-term) ".*") (file-name-nondirectory f)) ; 部分匹配
                                                            (string= (file-name-nondirectory f) search-term) ; 完全匹配
                                                            ;; 也检查是否包含转换后的路径匹配
                                                            (string-match (concat ".*" (replace-regexp-in-string "\\." "/" (regexp-quote search-term)) ".*") f))) ; 路径匹配
                                                         project-files)))
                      (cond
                       ;; 如果找到了确切匹配的文件
                       ((= (length more-specific-matching-files) 1)
                        (find-file (car more-specific-matching-files))
                        (goto-line line-number)
                        (throw 'found t))
                       ;; 如果找到多个匹配文件，让用户选择
                       ((> (length more-specific-matching-files) 1)
                        (let ((selected-file (completing-read "Select file: " more-specific-matching-files)))
                          (find-file selected-file)
                          (goto-line line-number)
                          (throw 'found t)))
                       ;; 找不到匹配文件
                       (t
                        (message "Could not find file matching: %s in project" search-term)))))))))))))))
