;;; typing-agent-validator.el --- 修改结果校验 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 任务成功与否只由最终内容决定，而不是“按键都发送成功”。
;;
;; 支持两类校验：
;;   1. Buffer 校验：在保存前检查 buffer 内容；
;;   2. 文件校验：保存后重新读取磁盘文件，确认保存钩子没有改写内容。
;;
;; expected 的 JSON 形式：
;;   {
;;     "contains":     ["必须出现的文本", ...],
;;     "not_contains": ["不允许出现的文本", ...],
;;     "regexp":       ["必须匹配的正则", ...],
;;     "content":      "完整内容（可选，适合小文件）",
;;     "sha256":       "文件内容哈希（可选）",
;;     "line_count":   12
;;   }

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'typing-agent)

(defun typing-agent-validator-normalize (expected)
  "把 JSON 解析出来的 EXPECTED 规范成 alist。
返回 nil 表示没有校验项。"
  (when expected
    (list (cons :contains
                (typing-agent-plist-vector->list
                 (plist-get expected :contains)))
          (cons :not_contains
                (typing-agent-plist-vector->list
                 (plist-get expected :not_contains)))
          (cons :regexp
                (typing-agent-plist-vector->list
                 (plist-get expected :regexp)))
          (cons :content (typing-agent-plist-string expected :content))
          (cons :sha256
                (let ((value (typing-agent-plist-string expected :sha256)))
                  (and value (downcase value))))
          (cons :line_count
                (typing-agent-plist-integer expected :line_count)))))

(defun typing-agent-validator-active-p (expected)
  "EXPECTED 是否包含至少一个校验项。"
  (let ((normalized (typing-agent-validator-normalize expected)))
    (and normalized
         (seq-some #'cdr normalized))))

(defun typing-agent-validator--content-of (source)
  "返回 SOURCE 的内容：buffer 或文件名。"
  (cond
   ((bufferp source)
    (with-current-buffer source
      (buffer-substring-no-properties (point-min) (point-max))))
   ((stringp source)
    (typing-agent-file-content source))
   (t
    (signal 'typing-agent-input-error
            (list (format "无法校验 %S" source))))))

(defun typing-agent-validator--sha-of (source)
  "返回 SOURCE（buffer 或文件）内容的 SHA256。"
  (cond
   ((bufferp source)
    (typing-agent-buffer-sha256 source))
   ((stringp source)
    (typing-agent-file-sha256 source))
   (t
    (signal 'typing-agent-input-error
            (list (format "无法计算 %S 的哈希" source))))))

(defun typing-agent-validator--fail (label fmt &rest args)
  "抛出校验失败错误，LABEL 为校验项。"
  (signal 'typing-agent-verify-error
          (list (format "%s: %s" label (apply #'format fmt args)))))

(defun typing-agent-validator--line-count (content)
  "返回 CONTENT 的行数。
以换行结尾的内容不多算一行，与编辑器里的行号一致。"
  (if (string-empty-p content)
      0
    (let ((n (length (split-string content "\n"))))
      (if (string-suffix-p "\n" content) (1- n) n))))

(defun typing-agent-validator-check (source expected &optional phase)
  "校验 SOURCE（buffer 或文件名）是否符合 EXPECTED。
PHASE 用于错误信息（\"保存前\" / \"保存后\"）。
返回检查项数量；失败抛出 `typing-agent-verify-error'。"
  (let* ((normalized (typing-agent-validator-normalize expected))
         (label (or phase "校验"))
         (checks 0))
    (when normalized
      (let ((content (typing-agent-validator--content-of source))
            (contains (alist-get :contains normalized))
            (not-contains (alist-get :not_contains normalized))
            (regexps (alist-get :regexp normalized))
            (expected-content (alist-get :content normalized))
            (expected-sha (alist-get :sha256 normalized))
            (expected-lines (alist-get :line_count normalized)))
        ;; 完整内容
        (when expected-content
          (cl-incf checks)
          (unless (string= content expected-content)
            (typing-agent-validator--fail
             label "完整内容不一致（期望 %d 字符，实际 %d 字符）"
             (length expected-content) (length content))))
        ;; 必须包含
        (dolist (needle contains)
          (when (and (stringp needle) (not (string-empty-p needle)))
            (cl-incf checks)
            (unless (string-match-p (regexp-quote needle) content)
              (typing-agent-validator--fail
               label "缺少必须出现的文本：%s"
               (substring needle 0 (min 80 (length needle)))))))
        ;; 不允许包含
        (dolist (needle not-contains)
          (when (and (stringp needle) (not (string-empty-p needle)))
            (cl-incf checks)
            (when (string-match-p (regexp-quote needle) content)
              (typing-agent-validator--fail
               label "出现了不允许保留的文本：%s"
               (substring needle 0 (min 80 (length needle)))))))
        ;; 正则
        (dolist (regexp regexps)
          (when (and (stringp regexp) (not (string-empty-p regexp)))
            (cl-incf checks)
            (unless (string-match-p regexp content)
              (typing-agent-validator--fail
               label "没有匹配正则：%s" regexp))))
        ;; 行数
        (when expected-lines
          (cl-incf checks)
          (let ((actual (typing-agent-validator--line-count content)))
            (unless (= actual expected-lines)
              (typing-agent-validator--fail
               label "行数不一致（期望 %d，实际 %d）"
               expected-lines actual))))
        ;; 哈希
        (when expected-sha
          (cl-incf checks)
          (let ((actual (typing-agent-validator--sha-of source)))
            (unless (string= (downcase actual) expected-sha)
              (typing-agent-validator--fail
               label "SHA256 不一致（期望 %s，实际 %s）"
               expected-sha actual))))))
    checks))

(defun typing-agent-validator-check-buffer (buffer expected)
  "在保存前校验 BUFFER。"
  (typing-agent-validator-check buffer expected "保存前校验"))

(defun typing-agent-validator-check-file (file expected)
  "保存后校验磁盘文件 FILE。"
  (typing-agent-validator-check file expected "保存后校验"))

(provide 'typing-agent-validator)
;;; typing-agent-validator.el ends here
