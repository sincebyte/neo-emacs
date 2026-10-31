;;; typing-agent-diff.el --- Unified Diff 解析与任务转换 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 把 OpenCode 生成的 Unified Diff 转换成 Typing Agent 的结构化操作。
;; 不依赖行号定位：优先使用 diff 自带的上下文文本做唯一匹配。
;;
;; 处理策略（按 hunk 内连续的变更段拆分）：
;;   - 纯新增：定位前一个上下文行，用 Evil 的 o/O 开新行，再逐字符输入；
;;   - 纯删除：用 replace_region 把原文整段（含行尾换行）替换成空串；
;;   - 修改：用 replace_region 把原文段替换成目标段。
;;
;; 每个变更段都保留原始缩进；换行由 `o'/`O' 和行尾换行共同决定。
;; 不支持：新建文件、删除文件、二进制 diff。遇到时明确报错。

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'typing-agent)

(define-error 'typing-agent-diff-error "Typing Agent Diff 错误" 'typing-agent-error)

;;; 解析

(defun typing-agent-diff--strip-prefix (path)
  "去掉 diff 路径前缀 a/ 或 b/。"
  (let ((path (string-trim path)))
    (cond
     ((string-prefix-p "a/" path) (substring path 2))
     ((string-prefix-p "b/" path) (substring path 2))
     (t path))))

(defun typing-agent-diff--parse-hunk-header (line)
  "解析 @@ 行，返回 (OLD-START OLD-LINES NEW-START NEW-LINES)。"
  (unless (string-match
           "\\`@@ -\\([0-9]+\\)\\(?:,\\([0-9]+\\)\\)? +\\+\\([0-9]+\\)\\(?:,\\([0-9]+\\)\\)? +@@" line)
    (signal 'typing-agent-diff-error
            (list (format "无法解析 hunk 头: %s" line))))
  (let ((old-start (string-to-number (match-string 1 line)))
        (old-lines (if (match-string 2 line)
                       (string-to-number (match-string 2 line))
                     1))
        (new-start (string-to-number (match-string 3 line)))
        (new-lines (if (match-string 4 line)
                       (string-to-number (match-string 4 line))
                     1)))
    (list old-start old-lines new-start new-lines)))

(defun typing-agent-diff-parse (text)
  "解析 Unified Diff TEXT，返回文件补丁列表。
每个补丁是 plist：
  (:old_path ... :new_path ... :hunks (...))
每个 hunk 是 plist：
  (:old_start :old_lines :new_start :new_lines :lines (...))
每行是 plist：(:kind \" \"|\"-\"|\"+\" :text ... :no_newline bool)。"
  (unless (and (stringp text) (not (string-empty-p text)))
    (signal 'typing-agent-diff-error (list "Diff 内容为空")))
  (let* ((normalized (replace-regexp-in-string "\r\n" "\n" text))
         ;; split-string 会在结尾换行后多产生一个空串，去掉这个伪行，
         ;; 否则它会被当成一条空的上下文行。
         (lines (split-string normalized "\n"))
         (lines (if (and (string-suffix-p "\n" normalized)
                         (string-empty-p (car (last lines))))
                    (butlast lines)
                  lines))
         (count (length lines))
         (index 0)
         (files nil)
         (current-file nil)
         (current-hunk nil)
         (old-path nil))
    (cl-flet ((finish-hunk ()
                (when current-hunk
                  (setf (plist-get current-hunk :lines)
                        (nreverse (plist-get current-hunk :lines)))
                  (push current-hunk (plist-get current-file :hunks))
                  (setq current-hunk nil))))
      (while (< index count)
        (let ((line (nth index lines)))
          (cond
           ;; diff --git a/x b/x：只用于边界，实际路径以后面的 ---/+++ 为准。
           ((string-prefix-p "diff --git " line)
            (finish-hunk)
            (when current-file
              (push current-file files)
              (setq current-file nil)))
           ((string-prefix-p "--- " line)
            (finish-hunk)
            (when current-file
              (push current-file files))
            (setq old-path (typing-agent-diff--strip-prefix
                            (substring line 4)))
            (setq current-file
                  (list :old_path old-path :new_path nil :hunks nil)))
           ((string-prefix-p "+++ " line)
            (unless current-file
              (signal 'typing-agent-diff-error
                      (list "遇到 +++ 但没有对应的 --- 行")))
            (setf (plist-get current-file :new_path)
                  (typing-agent-diff--strip-prefix (substring line 4))))
           ((string-prefix-p "@@ " line)
            (unless (and current-file (plist-get current-file :new_path))
              (signal 'typing-agent-diff-error
                      (list "遇到 hunk 头但缺少文件头")))
            (finish-hunk)
            (let ((header (typing-agent-diff--parse-hunk-header line)))
              (setq current-hunk
                    (list :old_start (nth 0 header)
                          :old_lines (nth 1 header)
                          :new_start (nth 2 header)
                          :new_lines (nth 3 header)
                          :lines nil))))
           ((string-prefix-p "\\" line)
            (when-let* ((prev (car (plist-get current-hunk :lines))))
              (setf (plist-get prev :no_newline) t)))
           ((and current-hunk
                 (or (string-prefix-p "+" line)
                     (string-prefix-p "-" line)
                     (string-prefix-p " " line)
                     (string-empty-p line)))
            (let* ((kind (cond ((string-prefix-p "+" line) "+")
                               ((string-prefix-p "-" line) "-")
                               (t " ")))
                   (text (if (string-empty-p line) "" (substring line 1))))
              (push (list :kind kind :text text :no_newline nil)
                    (plist-get current-hunk :lines))))
           ;; index / new file mode / 其他元数据行忽略
           (t nil)))
        (cl-incf index))
      (finish-hunk)
      (when current-file
        (push current-file files)))
    (setq files (nreverse files))
    (unless files
      (signal 'typing-agent-diff-error (list "Diff 中没有找到文件补丁")))
    (dolist (file files)
      (setf (plist-get file :hunks)
            (nreverse (plist-get file :hunks)))
      (unless (plist-get file :new_path)
        (signal 'typing-agent-diff-error
                (list (format "文件补丁缺少 +++ 行: %s"
                              (or (plist-get file :old_path) "?")))))
      (when (member (plist-get file :new_path) '("/dev/null" "dev/null"))
        (signal 'typing-agent-diff-error
                (list "第一版不支持删除文件")))
      (when (member (plist-get file :old_path) '("/dev/null" "dev/null"))
        (signal 'typing-agent-diff-error
                (list "第一版不支持新建文件"))))
    files))

;;; 变更段

(defun typing-agent-diff--line-text (line)
  "返回 diff 行 LINE 去掉前缀后的文本。"
  (plist-get line :text))

(defun typing-agent-diff--segments (hunk)
  "把 HUNK 拆成连续变更段。
返回 plist 列表：
  (:removed (...) :added (...) :anchor \"上一个上下文行\" :after \"下一个上下文行\")"
  (let ((segments nil)
        (current nil)
        (last-context nil))
    (cl-labels ((finish (after)
                  (when current
                    (push (list :removed (nreverse (plist-get current :removed))
                                :added (nreverse (plist-get current :added))
                                :anchor (plist-get current :anchor)
                                :after after)
                          segments)
                    (setq current nil))))
      (dolist (line (plist-get hunk :lines))
        (let ((kind (plist-get line :kind)))
          (cond
           ((equal kind " ")
            (finish (plist-get line :text))
            (setq last-context (plist-get line :text)))
           ((member kind '("+" "-"))
            (unless current
              (setq current
                    (list :removed nil :added nil
                          :anchor last-context :after nil)))
            (if (equal kind "+")
                (push line (plist-get current :added))
              (push line (plist-get current :removed)))))))
      (finish nil))
    (nreverse segments)))

(defun typing-agent-diff--block-text (lines)
  "把 diff 行列表 LINES 拼成文本，按每行的 `:no_newline' 决定行尾。"
  (mapconcat (lambda (line)
               (concat (plist-get line :text)
                       (if (plist-get line :no_newline) "" "\n")))
             lines ""))

(defun typing-agent-diff--added-block-text (lines)
  "把新增行拼成 `type_text' 文本。
最后一行之后的换行由 Evil 的 o/O 负责，因此去掉末尾一个换行。"
  (let ((text (typing-agent-diff--block-text lines)))
    (if (string-suffix-p "\n" text)
        (substring text 0 -1)
      text)))

;;; 段 -> 操作

(defun typing-agent-diff--ops-for-segment (segment hunk)
  "把单个变更段 SEGMENT 转换成操作列表。
HUNK 用于没有上下文行时以行号兜底。"
  (let* ((removed (plist-get segment :removed))
         (added (plist-get segment :added))
         (anchor (plist-get segment :anchor))
         (after (plist-get segment :after))
         (old-text (typing-agent-diff--block-text removed))
         (new-text (typing-agent-diff--block-text added)))
    (cond
     ;; 纯删除
     ((and removed (null added))
      (list (list :type "replace_region"
                  :search old-text
                  :replace "")))
     ;; 修改
     ((and removed added)
      (list (list :type "replace_region"
                  :search old-text
                  :replace new-text)))
     ;; 纯新增
     (added
      (let ((added-text (typing-agent-diff--added-block-text added)))
        (cond
         ;; 在上下文行后开新行
         ((and anchor (not (string-empty-p anchor)))
          (list (list :type "search_text" :text anchor)
                (list :type "move_cursor" :position "line_end")
                (list :type "enter_insert" :command "o")
                (list :type "type_text" :text added-text)
                (list :type "exit_insert")))
         ;; 在下一个上下文行之前开新行
         ((and after (not (string-empty-p after)))
          (list (list :type "search_text" :text after)
                (list :type "enter_insert" :command "O")
                (list :type "type_text" :text added-text)
                (list :type "exit_insert")))
         ;; 整块文件/没有上下文：用行号辅助，仍然通过 Evil 输入
         (t
          (list (list :type "goto_line"
                      :line (max 1 (plist-get hunk :old_start)))
                (list :type "enter_insert" :command "o")
                (list :type "type_text" :text added-text)
                (list :type "exit_insert"))))))
     (t
      (signal 'typing-agent-diff-error
              (list "变更段既没有新增也没有删除"))))))

;;; Diff -> 任务

(defun typing-agent-diff->operations (file-patch)
  "把一个文件补丁 FILE-PATCH 转换成操作列表。"
  (let ((operations nil))
    (dolist (hunk (plist-get file-patch :hunks))
      (dolist (segment (typing-agent-diff--segments hunk))
        (setq operations
              (append operations
                      (typing-agent-diff--ops-for-segment segment hunk)))))
    (when (null operations)
      (signal 'typing-agent-diff-error
              (list (format "文件 %s 的 diff 没有产生任何操作"
                            (plist-get file-patch :new_path)))))
    (append operations
            (list (list :type "save_buffer")))))

(defun typing-agent-diff->specs (text &optional options)
  "把 Unified Diff TEXT 转换成任务 spec 列表。
OPTIONS 是额外合并进每个任务 options 的 alist。
每个 spec 可直接 POST /task：(:file ... :operations ... :options ...)。"
  (let ((files (typing-agent-diff-parse text))
        (specs nil))
    (dolist (file files)
      (let ((path (plist-get file :new_path)))
        (push (list :file path
                    ;; 数组用 vector 表示，保证 JSON 编码结果确定。
                    :operations (vconcat
                                 (typing-agent-diff->operations file))
                    :options options)
              specs)))
    (nreverse specs)))

(provide 'typing-agent-diff)
;;; typing-agent-diff.el ends here
