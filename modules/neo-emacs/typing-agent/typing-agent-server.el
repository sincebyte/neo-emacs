;;; typing-agent-server.el --- 本地 HTTP API -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 一个零依赖的本地 HTTP/1.1 服务，只监听 127.0.0.1。
;; 每个请求都要求 Bearer Token，token 保存在状态目录（权限 600）。
;;
;; 接口：
;;   GET  /status                  Emacs / buffer / 活动任务状态
;;   GET  /tasks                   最近任务列表
;;   GET  /buffer                  当前 buffer 状态
;;   GET  /task/:id                任务详情
;;   POST /open                    打开文件
;;   POST /goto                    跳转行/位置
;;   POST /search                  搜索文本
;;   POST /task                    提交编辑任务
;;   POST /pause | /resume | /stop 任务控制
;;   POST /undo                    撤销当前任务
;;   POST /save                    保存当前 buffer
;;   POST /diff                    Unified Diff -> 任务 spec（不执行）
;;   POST /recording               录制模式 start/stop
;;
;; 请求体为 JSON，响应为 JSON。任务提交立即返回任务 ID。

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'json)
(require 'typing-agent)
(require 'typing-agent-engine)
(require 'typing-agent-diff)
(require 'typing-agent-recording)

(defcustom typing-agent-server-request-timeout 20
  "单个 HTTP 连接的最长存活时间（秒）。"
  :type 'integer
  :group 'typing-agent)

(defcustom typing-agent-server-max-body-size 2097152
  "请求体最大字节数（默认 2 MiB）。"
  :type 'integer
  :group 'typing-agent)

(defcustom typing-agent-server-verbose nil
  "是否把每个 HTTP 请求写入日志。"
  :type 'boolean
  :group 'typing-agent)

(defvar typing-agent-server--process nil
  "正在监听的 server process。")

(defvar typing-agent-server--started-at nil
  "服务启动时间（`float-time'）。")

;;; 工具

(defun typing-agent-server-running-p ()
  "HTTP 服务是否正在运行。
注意 `process-live-p' 返回的是状态列表的尾部（例如 (listen connect stop)），
这里统一规范成 t/nil，避免被 JSON 编码成数组。"
  (and typing-agent-server--process
       (process-live-p typing-agent-server--process)
       t))

(defun typing-agent-server-url ()
  "返回服务地址。"
  (format "http://%s:%d" typing-agent-server-host typing-agent-server-port))

(defun typing-agent-server--log (fmt &rest args)
  "记录服务日志。"
  (when typing-agent-server-verbose
    (typing-agent--append-log
     (list (cons :time (typing-agent--now))
           (cons :scope "server")
           (cons :message (apply #'format fmt args))))))

(defun typing-agent-server--json (object)
  "把 OBJECT 编码成 UTF-8 JSON 字符串。"
  (let ((json-encoding-pretty-print nil))
    (json-encode (typing-agent-json-prepare object))))

(defun typing-agent-server--error-status (err)
  "把 ERR 映射为 HTTP 状态码。"
  (pcase (car err)
    ('typing-agent-input-error 400)
    ('typing-agent-locate-error 422)
    ('typing-agent-verify-error 422)
    ('typing-agent-diff-error 422)
    ('typing-agent-busy-error 409)
    ('typing-agent-state-error 409)
    (_ 500)))

(defun typing-agent-server--error-body (err)
  "把 ERR 转成响应体。"
  (list (cons :ok :false)
        (cons :type (symbol-name (car err)))
        (cons :error (error-message-string err))))

;;; HTTP 解析

(defun typing-agent-server--header (headers name)
  "从 HEADERS alist 取 NAME（小写）。"
  (cdr (assoc name headers)))

(defun typing-agent-server--parse-headers (lines)
  "把 header 行解析成 alist，key 小写。"
  (let (headers)
    (dolist (line lines)
      (when (string-match "\\`\\([^:]+\\):[ \t]*\\(.*\\)\\'" line)
        (push (cons (downcase (string-trim (match-string 1 line)))
                    (string-trim (match-string 2 line)))
              headers)))
    (nreverse headers)))

(defun typing-agent-server--authorized-p (headers)
  "检查 HEADERS 中的 token 是否有效。"
  (let* ((auth (or (typing-agent-server--header headers "authorization")
                   (typing-agent-server--header headers "x-typing-agent-token")))
         (provided (cond
                    ((null auth) nil)
                    ((string-prefix-p "Bearer " auth)
                     (string-trim (substring auth 7)))
                    (t (string-trim auth)))))
    (and provided
         (stringp provided)
         (not (string-empty-p provided))
         (string= provided (typing-agent-token)))))

(defun typing-agent-server--read-request (data)
  "从 DATA 解析一个 HTTP 请求。
返回 (METHOD PATH HEADERS BODY REST) 或 nil（数据还不完整）。"
  (let ((sep (or (string-match "\r\n\r\n" data)
                 (string-match "\n\n" data))))
    (when sep
      (let* ((head-end sep)
             (head (substring data 0 head-end))
             (separator-length (if (eq (aref data sep) ?\r) 4 2))
             (rest (substring data (+ sep separator-length)))
             (lines (split-string (replace-regexp-in-string "\r\n" "\n" head)
                                  "\n"))
             (request-line (car lines))
             (headers (typing-agent-server--parse-headers (cdr lines))))
        (when (string-match
               "\\`\\([A-Za-z]+\\) +\\([^ ]+\\) +HTTP/[0-9.]+\\(.*\\)\\'"
               request-line)
          (let* ((method (upcase (match-string 1 request-line)))
                 (path (match-string 2 request-line))
                 (path (car (split-string path "?")))
                 (content-length
                  (let ((value (typing-agent-server--header
                                headers "content-length")))
                    (if (and value
                             (string-match-p "\\`[0-9]+\\'" value))
                        (string-to-number value)
                      0))))
            (when (or (not (typing-agent-server--header
                            headers "transfer-encoding"))
                      (not (string-match-p
                            "chunked"
                            (downcase (typing-agent-server--header
                                       headers "transfer-encoding")))))
              (when (> content-length typing-agent-server-max-body-size)
                (signal 'typing-agent-input-error
                        (list "请求体超过大小限制")))
              (when (>= (length rest) content-length)
                (let ((body (substring rest 0 content-length))
                      (remaining (substring rest content-length)))
                  (list method path headers
                        (decode-coding-string body 'utf-8)
                        remaining))))))))))

(defun typing-agent-server--send (proc status body)
  "向 PROC 发送 STATUS 和 BODY（alist），然后关闭连接。"
  (when (process-live-p proc)
    (let* ((json (typing-agent-server--json body))
           (encoded (encode-coding-string json 'utf-8))
           (reason (pcase status
                     (200 "OK") (202 "Accepted")
                     (400 "Bad Request") (401 "Unauthorized")
                     (404 "Not Found") (405 "Method Not Allowed")
                     (409 "Conflict") (411 "Length Required")
                     (422 "Unprocessable Entity")
                     (500 "Internal Server Error")
                     (501 "Not Implemented")
                     (_ "OK")))
           (head (format
                  "HTTP/1.1 %d %s\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n"
                  status reason (string-bytes encoded))))
      (process-send-string proc (concat (encode-coding-string head 'utf-8)
                                        encoded))
      (delete-process proc))))

(defun typing-agent-server--filter (proc chunk)
  "接收 CHUNK 并尝试处理完整 HTTP 请求。"
  (unless (process-get proc :handled)
    (unless (process-get proc :timeout)
      (process-put proc :timeout t)
      (run-at-time typing-agent-server-request-timeout nil
                   (lambda (client)
                     (when (and (process-live-p client)
                                (not (process-get client :handled)))
                       (delete-process client)))
                   proc))
    (let* ((data (concat (or (process-get proc :data) "") chunk))
           (request nil))
      (process-put proc :data data)
      (condition-case err
          (setq request (typing-agent-server--read-request data))
        (error
         (process-put proc :handled t)
         (typing-agent-server--send proc 400
                                    (typing-agent-server--error-body err))
         (setq request 'error)))
      (when (and request (not (eq request 'error)))
        (process-put proc :handled t)
        (pcase-let* ((`(,method ,path ,headers ,body ,_rest) request))
          (cond
           ((not (typing-agent-server--authorized-p headers))
            (typing-agent-server--send
             proc 401
             (list (cons :ok :false)
                   (cons :type "unauthorized")
                   (cons :error "缺少或错误的 token"))))
           (t
            (condition-case err
                (let ((result (typing-agent-server--dispatch
                               method path body)))
                  (typing-agent-server--send proc (car result) (cdr result)))
              (error
               (typing-agent-server--send
                proc
                (typing-agent-server--error-status err)
                (typing-agent-server--error-body err)))))))))))

;;; 路由

(defun typing-agent-server--json-body (body)
  "把请求体 BODY 解析成 plist；空体返回 nil。"
  (when (and body (not (string-empty-p (string-trim body))))
    (condition-case err
        (typing-agent-json-parse body)
      (error
       (signal 'typing-agent-input-error
               (list (format "请求体不是合法 JSON: %s"
                             (error-message-string err))))))))

(defun typing-agent-server--task-by-body (body)
  "解析 BODY 中的 id 并返回任务；没有 id 时返回当前任务。"
  (let* ((parsed (typing-agent-server--json-body body))
         (id (typing-agent-plist-string parsed :id)))
    (if id
        (or (typing-agent-task-get id)
            (signal 'typing-agent-input-error
                    (list (format "任务不存在: %s" id))))
      (or (typing-agent-task-current)
          (signal 'typing-agent-input-error (list "没有可操作的任务"))))))

(defun typing-agent-server--current-buffer ()
  "返回用户当前可见的 buffer。
HTTP 请求在进程过滤器里执行，`current-buffer\' 可能是进程 buffer，
因此所有“当前 buffer”语义都显式取选中窗口的 buffer。"
  (window-buffer (selected-window)))

(defun typing-agent-server--dispatch (method path body)
  "处理一个请求，返回 (STATUS . BODY)。"
  (typing-agent-server--log "%s %s" method path)
  (cond
   ;; 状态
   ((and (string= method "GET") (string= path "/status"))
    (cons 200
          (list (cons :ok t)
                (cons :version typing-agent-version)
                (cons :emacs_version emacs-version)
                (cons :server
                      (list (cons :running
                              (typing-agent-json-boolean
                               (typing-agent-server-running-p)))
                            (cons :url (typing-agent-server-url))
                            (cons :host typing-agent-server-host)
                            (cons :port typing-agent-server-port)
                            (cons :uptime (and typing-agent-server--started-at
                                               (- (float-time)
                                                  typing-agent-server--started-at)))
                            (cons :token_file (typing-agent-token-file-path))))
                (cons :buffer
                      (with-current-buffer (typing-agent-server--current-buffer)
                        (typing-agent-current-buffer-info)))
                (cons :active_task
                      (typing-agent-task->alist typing-agent--active-task))
                (cons :task_count (hash-table-count typing-agent--tasks)))))

   ;; 当前 buffer
   ((and (string= method "GET") (string= path "/buffer"))
    (cons 200
          (append (list (cons :ok t))
                  (with-current-buffer (typing-agent-server--current-buffer)
                    (typing-agent-current-buffer-info)))))

   ;; 任务列表
   ((and (string= method "GET") (string= path "/tasks"))
    (let (tasks)
      (maphash (lambda (_id task)
                 (push (typing-agent-task->alist task) tasks))
               typing-agent--tasks)
      (setq tasks
            (seq-take
             (sort tasks
                   (lambda (a b)
                     (string>
                      (or (alist-get :created_at a) "")
                      (or (alist-get :created_at b) ""))))
             50))
      (cons 200 (list (cons :ok t) (cons :tasks (vconcat tasks))))))

   ;; 单个任务
   ((and (string= method "GET")
         (string-prefix-p "/task/" path))
    (let* ((id (substring path (length "/task/")))
           (task (typing-agent-task-get id)))
      (unless task
        (signal 'typing-agent-input-error
                (list (format "任务不存在: %s" id))))
      (cons 200
            (append (list (cons :ok t))
                    (typing-agent-task->alist task t)))))

   ;; 打开文件
   ((and (string= method "POST") (string= path "/open"))
    (let* ((parsed (typing-agent-server--json-body body))
           (file (typing-agent-plist-string parsed :file))
           (line (typing-agent-plist-integer parsed :line)))
      (unless file
        (signal 'typing-agent-input-error (list "缺少 file")))
      (with-current-buffer (typing-agent-engine-open file line)
        (cons 200 (append (list (cons :ok t))
                          (typing-agent-current-buffer-info))))))

   ;; 跳转
   ((and (string= method "POST") (string= path "/goto"))
    (let* ((parsed (typing-agent-server--json-body body))
           (line (typing-agent-plist-integer parsed :line))
           (position (typing-agent-plist-string parsed :position)))
      (with-current-buffer (typing-agent-server--current-buffer)
        (cond
         (line (typing-agent-engine-goto line))
         (position (typing-agent-evil-move-cursor position
                                                  (typing-agent-plist-integer
                                                   parsed :count)))
         (t (signal 'typing-agent-input-error
                    (list "需要 line 或 position"))))
        (cons 200
              (append (list (cons :ok t))
                      (typing-agent-current-buffer-info))))))

   ;; 搜索
   ((and (string= method "POST") (string= path "/search"))
    (let* ((parsed (typing-agent-server--json-body body))
           (text (typing-agent-plist-string parsed :text)))
      (unless text
        (signal 'typing-agent-input-error (list "缺少 text")))
      (with-current-buffer (typing-agent-server--current-buffer)
        (typing-agent-engine-search
         text
         (typing-agent-plist-integer parsed :occurrence)
         (typing-agent-plist-boolean parsed :unique t))
        (cons 200
              (append (list (cons :ok t))
                      (typing-agent-current-buffer-info))))))

   ;; 提交任务
   ((and (string= method "POST") (string= path "/task"))
    (let* ((parsed (typing-agent-server--json-body body))
           (task (typing-agent-engine-submit parsed)))
      (cons 202
            (list (cons :ok t)
                  (cons :id (typing-agent-task-id task))
                  (cons :status (typing-agent-status-label
                                 (typing-agent-task-status task)))
                  (cons :total (length (typing-agent-task-operations task)))))))

   ;; 暂停 / 继续 / 停止
   ((and (string= method "POST")
         (member path '("/pause" "/resume" "/stop")))
    (let ((task (typing-agent-server--task-by-body body)))
      (pcase path
        ("/pause" (typing-agent-engine-pause task))
        ("/resume" (typing-agent-engine-resume task))
        ("/stop" (typing-agent-engine-cancel task)))
      (cons 200
            (append (list (cons :ok t))
                    (typing-agent-task->alist task)))))

   ;; 撤销
   ((and (string= method "POST") (string= path "/undo"))
    (let ((task (typing-agent-server--task-by-body body)))
      (typing-agent-engine-undo-task task)
      (cons 200
            (append (list (cons :ok t))
                    (typing-agent-task->alist task)))))

   ;; 保存
   ((and (string= method "POST") (string= path "/save"))
    (with-current-buffer (typing-agent-server--current-buffer)
      (let ((file (typing-agent-engine-save-current)))
        (cons 200 (list (cons :ok t) (cons :file file))))))

   ;; Diff 转换
   ((and (string= method "POST") (string= path "/diff"))
    (let* ((parsed (typing-agent-server--json-body body))
           (diff-text (typing-agent-plist-string parsed :diff))
           (base-dir (typing-agent-plist-string parsed :base_dir))
           (options (plist-get parsed :options)))
      (unless diff-text
        (signal 'typing-agent-input-error (list "缺少 diff")))
      (let ((specs (typing-agent-diff->specs diff-text options)))
        (when base-dir
          (dolist (spec specs)
            (setf (plist-get spec :file)
                  (expand-file-name (plist-get spec :file) base-dir))))
        (cons 200 (list (cons :ok t) (cons :specs (vconcat specs)))))))

   ;; 录制
   ((and (string= method "POST") (string= path "/recording"))
    (let* ((parsed (typing-agent-server--json-body body))
           (action (typing-agent-plist-string parsed :action)))
      (pcase action
        ("start"
         (typing-agent-recording-start
          (typing-agent-plist-string parsed :file)
          (typing-agent-plist-integer parsed :line)))
        ("stop"
         (typing-agent-recording-stop
          (typing-agent-plist-boolean parsed :keep_window nil)))
        (_
         (signal 'typing-agent-input-error
                 (list "action 必须是 start 或 stop"))))
      (cons 200 (list (cons :ok t) (cons :action action)))))

   ;; 方法不匹配
   ((member path '("/status" "/buffer" "/tasks" "/open" "/goto" "/search"
                   "/task" "/pause" "/resume" "/stop" "/undo" "/save"
                   "/diff" "/recording"))
    (cons 405 (list (cons :ok :false)
                    (cons :error "Method Not Allowed"))))

   (t
    (cons 404 (list (cons :ok :false)
                    (cons :error (format "未知接口: %s %s" method path)))))))

;;; 生命周期

(defun typing-agent-server-start (&optional port)
  "启动本地 HTTP 服务。
PORT 缺省使用 `typing-agent-server-port'。已经运行时直接返回现有进程。"
  (interactive)
  (if (typing-agent-server-running-p)
      typing-agent-server--process
    (let* ((port (or port typing-agent-server-port))
           (host typing-agent-server-host))
      (unless (member host '("127.0.0.1" "localhost" "::1"))
        (signal 'typing-agent-input-error
                (list "Typing Agent 只允许监听回环地址")))
      ;; 提前生成 token，确保启动后 OpenCode 能读到。
      (typing-agent-token)
      (setq typing-agent-server--process
            (make-network-process
             :name "typing-agent-server"
             :server t
             :host host
             :service port
             :family 'ipv4
             :noquery t
             :coding 'binary
             :reuseaddr t
             :filter #'typing-agent-server--filter
             :sentinel #'typing-agent-server--sentinel))
      (setq typing-agent-server--started-at (float-time))
      (typing-agent-server--log "服务已启动: %s" (typing-agent-server-url))
      typing-agent-server--process)))

(defun typing-agent-server--sentinel (proc _event)
  "server PROC 的 sentinel。"
  (unless (process-live-p proc)
    (when (eq proc typing-agent-server--process)
      (setq typing-agent-server--process nil
            typing-agent-server--started-at nil))))

(defun typing-agent-server-stop ()
  "停止本地 HTTP 服务。"
  (interactive)
  (when (typing-agent-server-running-p)
    (delete-process typing-agent-server--process)
    (setq typing-agent-server--process nil
          typing-agent-server--started-at nil)
    t))

(defun typing-agent-server-show-token ()
  "返回 API token（不打印消息，避免录制时出现提示）。"
  (interactive)
  (typing-agent-token))

(defun typing-agent-server-status ()
  "返回服务状态与活动任务（不打印消息）。"
  (interactive)
  (format "Typing Agent: %s，活动任务: %s"
          (if (typing-agent-server-running-p)
              (typing-agent-server-url)
            "未启动")
          (if typing-agent--active-task
              (format "%s (%s)"
                      (typing-agent-task-id typing-agent--active-task)
                      (typing-agent-status-label
                       (typing-agent-task-status typing-agent--active-task)))
            "无")))

(provide 'typing-agent-server)
;;; typing-agent-server.el ends here
