;;; typing-agent.el --- Emacs Typing Agent 核心 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Emacs Typing Agent 让外部程序（OpenCode）通过结构化编辑任务控制 Emacs，
;; 用可见的 Evil 按键逐字符修改代码，并保证最终内容经过校验。
;;
;; 本文件只放：配置项、任务数据结构、任务表、状态机常量、日志与 JSON 工具。
;; 具体编辑动作在 `typing-agent-engine.el'，Evil 适配在
;; `typing-agent-evil.el'，HTTP 服务在 `typing-agent-server.el'。
;;
;; 设计原则：
;;   1. Emacs 是唯一的实际编辑执行者；
;;   2. 所有编辑都通过 Evil 的 Normal / Insert 状态完成；
;;   3. 每次任务都有快照、日志、最终校验与任务级撤销边界。

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'json)
(require 'seq)

(defgroup typing-agent nil
  "让外部 Agent 通过可见按键驱动 Emacs 编辑代码。"
  :group 'tools
  :prefix "typing-agent-")

(defconst typing-agent-version "0.1.0"
  "Typing Agent 版本号。")

;;; 错误类型

(define-error 'typing-agent-error "Typing Agent 错误")
(define-error 'typing-agent-state-error "Typing Agent 状态错误" 'typing-agent-error)
(define-error 'typing-agent-locate-error "Typing Agent 定位失败" 'typing-agent-error)
(define-error 'typing-agent-verify-error "Typing Agent 校验失败" 'typing-agent-error)
(define-error 'typing-agent-busy-error "Typing Agent 忙" 'typing-agent-error)
(define-error 'typing-agent-input-error "Typing Agent 输入错误" 'typing-agent-error)

;;; 配置

(defcustom typing-agent-state-dir
  (expand-file-name "~/.local/state/typing-agent/")
  "Typing Agent 的状态目录。
用于存放 token 与任务日志，不写进 Doom 配置仓库。"
  :type 'directory
  :group 'typing-agent)

(defcustom typing-agent-log-file nil
  "任务日志文件（JSON Lines）。
为 nil 时使用 `typing-agent-state-dir' 下的 tasks.jsonl。"
  :type '(choice (const :tag "默认" nil) file)
  :group 'typing-agent)

(defcustom typing-agent-token-file nil
  "HTTP API 的 token 文件。
为 nil 时使用 `typing-agent-state-dir' 下的 token。"
  :type '(choice (const :tag "默认" nil) file)
  :group 'typing-agent)

(defcustom typing-agent-server-host "127.0.0.1"
  "HTTP 服务监听地址。只允许回环地址。"
  :type 'string
  :group 'typing-agent)

(defcustom typing-agent-server-port 8765
  "HTTP 服务监听端口。"
  :type 'integer
  :group 'typing-agent)

(defcustom typing-agent-auto-start t
  "启动 Emacs 后是否自动启动本地 HTTP 服务。
服务只监听回环地址，并且所有请求都要求 token。"
  :type 'boolean
  :group 'typing-agent)

(defcustom typing-agent-log-max-entries 500
  "单个任务在内存里保留的日志条数。"
  :type 'integer
  :group 'typing-agent)

(defcustom typing-agent-allow-dirty-buffer nil
  "目标 buffer 存在未保存修改时，是否仍允许执行任务。
默认拒绝，避免把用户正在编辑的内容混进任务快照。"
  :type 'boolean
  :group 'typing-agent)

(defcustom typing-agent-save-round-trip-check t
  "保存后是否重新读取文件并与 buffer 内容比对。
用于发现保存钩子改写了文件（例如格式化工具）。"
  :type 'boolean
  :group 'typing-agent)

(defcustom typing-agent-undo-max-steps 2000
  "任务级撤销最多按多少次 u。
每次按 u 都会比较 buffer 是否回到任务开始前的快照；超过上限仍不一致就报错，
绝不静默地当作撤销成功。"
  :type 'integer
  :group 'typing-agent)

(defcustom typing-agent-maximize-window t
  "任务开始时是否让目标文件独占当前 frame。
开启后编辑期间只剩一个窗口，代码更大更清楚，适合录制和远程观看。
任务结束不做任何恢复：画面停在最后编辑或查看的 buffer 上。"
  :type 'boolean
  :group 'typing-agent)

;;; 状态枚举

(defconst typing-agent-status-pending 'pending)
(defconst typing-agent-status-running 'running)
(defconst typing-agent-status-paused 'paused)
(defconst typing-agent-status-completed 'completed)
(defconst typing-agent-status-failed 'failed)
(defconst typing-agent-status-cancelled 'cancelled)

(defconst typing-agent-statuses
  (list typing-agent-status-pending
        typing-agent-status-running
        typing-agent-status-paused
        typing-agent-status-completed
        typing-agent-status-failed
        typing-agent-status-cancelled)
  "任务的全部合法状态。")

(defconst typing-agent-terminal-statuses
  (list typing-agent-status-completed
        typing-agent-status-failed
        typing-agent-status-cancelled)
  "任务结束后的状态。")

(defun typing-agent-status-valid-p (status)
  "STATUS 是否是合法任务状态。"
  (memq status typing-agent-statuses))

(defun typing-agent-status-terminal-p (status)
  "STATUS 是否表示任务已经结束。"
  (memq status typing-agent-terminal-statuses))

(defun typing-agent-status-label (status)
  "把状态符号转成 API 输出的字符串。"
  (if (and status (symbolp status))
      (symbol-name status)
    "unknown"))

;;; 任务结构
;;
;; 注意：`cl-defstruct' 必须出现在第一个使用其访问器 `setf' 的函数之前。
;; Emacs 在定义函数时就会展开 `setf'，所以结构体放在文件后部会导致
;; “void-function (setf typing-agent-task-…)”。

(cl-defstruct (typing-agent-task (:constructor typing-agent-task-create)
                                 (:copier nil))
  id
  status
  file
  buffer
  operations
  index
  op-state
  options
  expected
  snapshot
  snapshot-sha
  created-at
  started-at
  finished-at
  logs
  error
  result
  timer
  mode-prepared)

(defvar typing-agent--tasks (make-hash-table :test #'equal)
  "任务表：任务 ID -> `typing-agent-task'。")

(defvar typing-agent--active-task nil
  "当前正在执行或暂停的任务对象；没有时为 nil。")

(defvar typing-agent--task-counter 0
  "本进程内创建的任务计数，用于生成可读 ID。")

;;; 时间与日志

(defun typing-agent--now ()
  "当前本地时间，ISO 8601 格式，带时区偏移。"
  (format-time-string "%Y-%m-%dT%H:%M:%S%z"))

(defun typing-agent--state-dir ()
  "返回并确保状态目录存在。"
  (let ((dir (file-name-as-directory (expand-file-name typing-agent-state-dir))))
    (unless (file-directory-p dir)
      (make-directory dir t))
    dir))

(defun typing-agent-log-file-path ()
  "返回任务日志文件的绝对路径。"
  (expand-file-name
   (or typing-agent-log-file "tasks.jsonl")
   (typing-agent--state-dir)))

(defun typing-agent-token-file-path ()
  "返回 token 文件的绝对路径。"
  (expand-file-name
   (or typing-agent-token-file "token")
   (typing-agent--state-dir)))

(defun typing-agent-token ()
  "读取或创建本地 API token。
token 文件权限为 600，只允许当前用户读取。"
  (let ((file (typing-agent-token-file-path)))
    (or (and (file-readable-p file)
             (let ((token (string-trim
                           (with-temp-buffer
                             (insert-file-contents file)
                             (buffer-string)))))
               (unless (string-empty-p token) token)))
        (let ((token (secure-hash
                      'sha256
                      (format "%s:%s:%s:%s"
                              (system-name) (emacs-pid) (float-time)
                              (random 1000000)))))
          (with-temp-file file
            (insert token "\n"))
          (set-file-modes file #o600)
          token))))

(defun typing-agent--append-log (entry)
  "把 ENTRY（alist）追加到日志文件。日志失败不影响任务。"
  (condition-case nil
      (let ((file (typing-agent-log-file-path)))
        (make-directory (file-name-directory file) t)
        (let ((coding-system-for-write 'utf-8-unix))
          (write-region (concat (json-encode entry) "\n") nil file t 'silent)))
    (error
     nil)))

(defun typing-agent-task-log (task level fmt &rest args)
  "给 TASK 记录一条 LEVEL 级别的日志，FMT/ARGS 为消息格式。
同时写入内存日志和磁盘 JSONL。"
  (let* ((message (apply #'format fmt args))
         (entry (list (cons :time (typing-agent--now))
                      (cons :task (typing-agent-task-id task))
                      (cons :level (symbol-name level))
                      (cons :message message))))
    (push entry (typing-agent-task-logs task))
    (when (> (length (typing-agent-task-logs task)) typing-agent-log-max-entries)
      (setf (typing-agent-task-logs task)
            (seq-take (typing-agent-task-logs task) typing-agent-log-max-entries)))
    (typing-agent--append-log entry)
    message))

(defun typing-agent--new-task-id ()
  "生成任务 ID。"
  (cl-incf typing-agent--task-counter)
  (format "%s-%04d-%04x"
          (format-time-string "%Y%m%d%H%M%S")
          typing-agent--task-counter
          (random 65536)))

(defun typing-agent-task-register (task)
  "把 TASK 放进任务表并返回它。"
  (puthash (typing-agent-task-id task) task typing-agent--tasks)
  task)

(defun typing-agent-task-get (id)
  "按 ID 查找任务；不存在返回 nil。"
  (and (stringp id)
       (gethash id typing-agent--tasks)))

(defun typing-agent-task-current ()
  "返回当前任务：优先活动任务，否则最近创建的任务。"
  (or typing-agent--active-task
      (let (latest)
        (maphash (lambda (_id task)
                   (when (or (null latest)
                             (string< (typing-agent-task-created-at latest)
                                      (typing-agent-task-created-at task)))
                     (setq latest task)))
                 typing-agent--tasks)
        latest)))

(defun typing-agent-task-busy-p ()
  "是否有任务正在执行或暂停。"
  (and typing-agent--active-task
       (memq (typing-agent-task-status typing-agent--active-task)
             (list typing-agent-status-running typing-agent-status-paused))))

(defun typing-agent-task->alist (task &optional with-log)
  "把 TASK 转成 API 输出用的 alist。
WITH-LOG 非 nil 时附带日志（新的在前）。"
  (when task
    (let ((buffer (typing-agent-task-buffer task)))
      (append
       (list (cons :id (typing-agent-task-id task))
             (cons :status (typing-agent-status-label
                            (typing-agent-task-status task)))
             (cons :file (typing-agent-task-file task))
             (cons :buffer (and (buffer-live-p buffer)
                                (buffer-name buffer)))
             (cons :index (typing-agent-task-index task))
             (cons :total (length (typing-agent-task-operations task)))
             (cons :created_at (typing-agent-task-created-at task))
             (cons :started_at (typing-agent-task-started-at task))
             (cons :finished_at (typing-agent-task-finished-at task))
             (cons :error (typing-agent-task-error task))
             (cons :result (typing-agent-task-result task)))
       (when with-log
         (list (cons :log (apply #'typing-agent-json-array
                                 (typing-agent-task-logs task)))))))))

;;; JSON 与 plist 工具

(defun typing-agent-json-parse (string)
  "把 STRING 解析成 plist。JSON 对象键变成关键字。
JSON null 解析为 :null，false 解析为 :false，便于区分缺省值。"
  (json-parse-string string
                     :object-type 'plist
                     :null-object :null
                     :false-object :false))

(defun typing-agent-json-encode (object)
  "把 alist/vector 编码成 JSON 字符串。"
  (json-encode object))

(defun typing-agent-json--plist-p (object)
  "OBJECT 是否是合法的 plist（偶数长度、键全为 keyword）。"
  (and (consp object)
       (proper-list-p object)
       (zerop (logand (length object) 1))
       (cl-loop for (key _value) on object by #'cddr
                always (keywordp key))))

(defun typing-agent-json--alist-p (object)
  "OBJECT 是否是 alist。"
  (and (consp object)
       (proper-list-p object)
       (cl-every (lambda (entry)
                   (and (consp entry)
                        (or (keywordp (car entry))
                            (symbolp (car entry))
                            (stringp (car entry)))))
                 object)))

(defun typing-agent-json-array (&rest items)
  "把 ITEMS 构造成 JSON 数组。
数组必须用 vector 表示：`json-encode' 无法区分“对象列表”和“数组”，
所以内部凡是数组都用 vector 传递。"
  (vconcat items))

(defun typing-agent-json-prepare (object)
  "把 OBJECT 递归转换成 `json-encode' 能正确编码的结构。

约定：JSON 对象用 plist 或 alist 表示；JSON 数组必须用 vector 表示
（见 `typing-agent-json-array'）。因为 `json-encode' 把“对象列表”和
“数组”看成同一种结构，只有显式使用 vector 才能无歧义地区分两者。"
  (cond
   ((null object) nil)
   ;; `typing-agent-json-parse' 把 JSON false/null 读成 `:false'/`:null'，
   ;; 写回时要还原成 `json.el' 认识的特殊值。
   ((eq object :null) nil)
   ((eq object :false) json-false)
   ((vectorp object)
    (vconcat (mapcar #'typing-agent-json-prepare (append object nil))))
   ((typing-agent-json--plist-p object)
    (cl-loop for (key value) on object by #'cddr
             collect (cons key (typing-agent-json-prepare value))))
   ((typing-agent-json--alist-p object)
    (mapcar (lambda (entry)
              (cons (car entry)
                    (typing-agent-json-prepare (cdr entry))))
            object))
   ((listp object)
    (signal 'typing-agent-input-error
            (list (format "JSON 数组必须用 vector 表示，收到列表：%S"
                          object))))
   (t object)))

(defun typing-agent-json-false-p (value)
  "VALUE 是否表示 JSON false。"
  (or (eq value :false) (null value)))

(defun typing-agent-json-boolean (value)
  "把 VALUE 转成 JSON 布尔值。
真值返回 t，假值返回 `:false'（编码为 false，而不是 null）。"
  (if value t :false))

(defun typing-agent-plist-vector->list (value)
  "把 JSON 数组（vector）转成 list；其他值原样返回。"
  (cond ((vectorp value) (append value nil))
        ((listp value) value)
        (t value)))

(defun typing-agent-plist-string (plist key &optional default)
  "从 PLIST 取 KEY，返回字符串。
nil、:null、空字符串视为缺省，返回 DEFAULT。"
  (let ((value (plist-get plist key)))
    (if (or (null value) (eq value :null) (eq value :false)
            (and (stringp value) (string-empty-p value)))
        default
      (format "%s" value))))

(defun typing-agent-plist-integer (plist key &optional default)
  "从 PLIST 取 KEY，返回整数。"
  (let ((value (plist-get plist key)))
    (cond ((integerp value) value)
          ((and (stringp value) (string-match-p "\\`-?[0-9]+\\'" value))
           (string-to-number value))
          (t default))))

(defun typing-agent-plist-number (plist key &optional default)
  "从 PLIST 取 KEY，返回浮点数。"
  (let ((value (plist-get plist key)))
    (cond ((numberp value) (float value))
          ((and (stringp value)
                (string-match-p "\\`-?[0-9]+\\(?:\\.[0-9]+\\)?\\'" value))
           (string-to-number value))
          (t default))))

(defun typing-agent-plist-boolean (plist key &optional default)
  "从 PLIST 取 KEY，返回布尔值。
未提供时返回 DEFAULT；JSON false 返回 nil。"
  (let ((value (plist-get plist key)))
    (cond ((null value) default)
          ((eq value :false) nil)
          ((eq value :null) default)
          ((eq value t) t)
          ((eq value :true) t)
          ((and (stringp value) (member value '("true" "1" "yes"))) t)
          ((and (stringp value) (member value '("false" "0" "no"))) nil)
          (t (and value t)))))

;;; 缓冲区与文件工具

(defvar evil-state)
(defvar evil-mode)
(defvar corfu-auto)

(defun typing-agent-buffer-file-name (buffer)
  "返回 BUFFER 对应的文件路径；没有文件时返回 nil。"
  (buffer-local-value 'buffer-file-name buffer))

(defun typing-agent-buffer-sha256 (buffer)
  "计算 BUFFER 内容的 SHA256（按 UTF-8 编码）。"
  (with-current-buffer buffer
    (secure-hash 'sha256
                 (encode-coding-string
                  (buffer-substring-no-properties (point-min) (point-max))
                  'utf-8))))

(defun typing-agent-file-sha256 (file)
  "计算 FILE 内容的 SHA256。"
  (secure-hash 'sha256 file))

(defun typing-agent-file-content (file)
  "以 UTF-8 读取 FILE 的完整内容。"
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8-unix))
      (insert-file-contents file))
    (buffer-substring-no-properties (point-min) (point-max))))

(defun typing-agent-current-buffer-info ()
  "返回当前 buffer 的状态 alist，供 /buffer 接口使用。"
  (let ((file (buffer-file-name)))
    (list (cons :buffer (buffer-name))
          (cons :file file)
          (cons :major_mode (symbol-name major-mode))
          (cons :point (point))
          (cons :line (line-number-at-pos))
          (cons :column (current-column))
          (cons :size (buffer-size))
          (cons :modified (typing-agent-json-boolean (buffer-modified-p)))
          (cons :evil_state
                (if (bound-and-true-p evil-state)
                    (symbol-name evil-state)
                  "none"))
          (cons :evil_mode
                (typing-agent-json-boolean (bound-and-true-p evil-mode)))
          (cons :sha256 (typing-agent-buffer-sha256 (current-buffer))))))

(provide 'typing-agent)
;;; typing-agent.el ends here
