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
  "基于光标位置提取类名和行号，并跳转到项目中的 Java 文件。
在 `java-mode' / `java-ts-mode' 下解析 Mapper 方法名并调用
`+java-jump-to-mapper-xml'：唯一匹配直接打开 XML；多匹配时 minibuffer 选择。"
  (interactive)
  (if (derived-mode-p 'java-mode 'java-ts-mode)
      (progn
        (unless (fboundp '+java-mapper-method-name-at-point)
          (user-error "+java-mapper-method-name-at-point 未定义，请确保 neo-emacs/java 已加载"))
        (unless (fboundp '+java-jump-to-mapper-xml)
          (user-error "+java-jump-to-mapper-xml 未定义，请确保 neo-emacs/java 已加载"))
        (let* ((java-file (buffer-file-name))
               (project-root
                (or (locate-dominating-file java-file "pom.xml")
                    (locate-dominating-file java-file "build.gradle")
                    (locate-dominating-file java-file "build.gradle.kts")))
               (method-name (+java-mapper-method-name-at-point)))
          (unless java-file
            (user-error "当前缓冲区未关联文件"))
          (unless project-root
            (user-error "未找到项目根目录（pom.xml / build.gradle）"))
          (unless (and method-name (> (length method-name) 0))
            (user-error "未能解析 Mapper 方法名，请将光标放在方法声明或参数列表附近"))
          (+java-jump-to-mapper-xml (expand-file-name project-root) method-name)))
    (let* ((line-start (line-beginning-position))
         (line-end (line-end-position))
         (current-line (buffer-substring-no-properties line-start line-end))
         (point-in-line (- (point) line-start))
         (line-java-class nil)
         (line-java-number nil)
         (class-token (thing-at-point 'symbol t))
         ;; 光标词可能包含 ":101" 或 ".java"，这里统一清洗后再提取类名。
         (normalized-token
          (and class-token
               (replace-regexp-in-string
                ":[0-9]+\\'" ""
                (replace-regexp-in-string "\\.java\\'" "" class-token))))
         (class-name (and normalized-token
                          (car (last (split-string normalized-token "[/.]" t)))))
         (cursor-pos (point))
         (text-after-cursor (buffer-substring-no-properties cursor-pos line-end))
         (line-number
          (when (string-match ":\\s-*\\([0-9]+\\)" text-after-cursor)
            (string-to-number (match-string 1 text-after-cursor)))))
    ;; 最高优先级：整行显式匹配 "Xxx.java:74"，光标在任何位置都生效。
    (when (string-match "\\([A-Z][[:alnum:]_$]*\\)\\.java\\s-*:\\s-*\\([0-9]+\\)" current-line)
      (setq line-java-class (match-string 1 current-line))
      (setq line-java-number (string-to-number (match-string 2 current-line)))
      (setq class-name line-java-class)
      (setq line-number line-java-number))

    ;; 兜底：当光标词不是有效类名时，优先尝试从光标后的 "Xxx.java" 提取。
    (unless (and class-name (string-match-p "[A-Z]" class-name))
      (let ((line-after-cursor (substring current-line point-in-line)))
        (when (string-match "\\([A-Z][[:alnum:]_$]*\\)\\.java\\(?:\\s-*:\\s-*\\([0-9]+\\)\\)?" line-after-cursor)
          (setq class-name (match-string 1 line-after-cursor))
          (unless line-number
            (let ((num-str (match-string 2 line-after-cursor)))
              (when (and num-str (not (string-empty-p num-str)))
                (setq line-number (string-to-number num-str))))))))
    ;; 再兜底：整行范围查找，兼容类似 [com.xxx.UapQuery] 的格式。
    (unless (and class-name (string-match-p "[A-Z]" class-name))
      (when (string-match "\\(?:[[:alnum:]_$]+\\.\\)*\\([A-Z][[:alnum:]_$]*\\)\\(?:\\.java\\)?\\(?:\\s-*:\\s-*\\([0-9]+\\)\\)?" current-line)
        (setq class-name (match-string 1 current-line))
        (unless line-number
          (let ((num-str (match-string 2 current-line)))
            (when (and num-str (not (string-empty-p num-str)))
              (setq line-number (string-to-number num-str)))))))
    (if (and class-name (not (string-empty-p class-name)))
        (let* ((project-root (projectile-project-root))
               (all-project-files (projectile-current-project-files))
               (search-term (concat class-name ".java"))
               (matching-files
                (cl-remove-if-not
                 (lambda (f)
                   (or
                    (string= (file-name-nondirectory f) search-term)
                    (string-match
                     (concat ".*" (regexp-quote class-name) ".*\\.java$")
                     (file-name-nondirectory f))))
                 all-project-files)))
          (if matching-files
              (cond
               ((= (length matching-files) 1)
                (find-file (expand-file-name (car matching-files) project-root))
                (when line-number
                  (goto-char (point-min))
                  (forward-line (1- line-number)))
                (message "Jumped to %s%s"
                         search-term
                         (if line-number
                             (format " at line %d" line-number)
                           "")))
               ((> (length matching-files) 1)
                (let ((selected-file (completing-read "Select file from matches: " matching-files)))
                  (find-file (expand-file-name selected-file project-root))
                  (when line-number
                    (goto-char (point-min))
                    (forward-line (1- line-number)))
                  (message "Jumped to %s%s"
                           (file-name-nondirectory selected-file)
                           (if line-number
                               (format " at line %d" line-number)
                             "")))))
            (message "No matches found for '%s'" search-term)))
      (message "No class symbol found at point.")))))
