;;; typing-agent-keycast.el --- 把打字动作镜像到 KeyCastr -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Typing Agent 的按键是 Emacs 内部的键盘事件（`execute-kbd-macro'、
;; `unread-command-events'），不会进入 macOS 的 CGEvent 流，所以 KeyCastr
;; 的 event tap 看不到它们。这里把每个要敲的键用 Unix 数据报 socket 发给
;; 本地 KeyCastr 的一个 fork 版本，由它直接交给当前 visualizer 显示。
;;
;; 协议（每个数据报一行 JSON，UTF-8）：
;;
;;   {"text":"a"}
;;   {"text":"G","modifiers":["shift"]}
;;
;; socket 路径默认 `/tmp/keycastr-inject-<uid>.sock'，KeyCastr 没开或
;; 没有这个 socket 时静默跳过，绝不影响编辑任务本身。

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'subr-x)

(defgroup typing-agent-keycast nil
  "Typing Agent 的 KeyCastr 按键显示。"
  :group 'typing-agent
  :prefix "typing-agent-keycast-")

(defcustom typing-agent-keycast-enabled t
  "是否把打字动作镜像到本机 KeyCastr。
关闭后不连接 socket，也不会尝试显示任何按键。"
  :type 'boolean
  :group 'typing-agent-keycast)

(defcustom typing-agent-keycast-socket nil
  "KeyCastr 注入通道的 socket 路径。
nil 表示使用 `/tmp/keycastr-inject-<uid>.sock'。"
  :type '(choice (const :tag "默认路径" nil) string)
  :group 'typing-agent-keycast)

(defcustom typing-agent-keycast-retry-interval 5.0
  "连接失败后隔多久再试，单位：秒。
KeyCastr 后启动时不必重启 Emacs，最多等这么久就会连上。"
  :type 'number
  :group 'typing-agent-keycast)

(defconst typing-agent-keycast-special-glyphs
  '((?\r . "⏎")
    (?\n . "⏎")
    (?\t . "⇥")
    (?\s . "␣")
    (?\d . "⌫")
    (?\e . "⎋"))
  "与 KeyCastr 自身显示一致的按键符号。
空格、TAB、RET、DEL、ESC 在 KeyCastr 里都是特殊键，不走字符本身。")

(defvar typing-agent-keycast--process nil
  "到 KeyCastr 的本地数据报连接。")

(defvar typing-agent-keycast--attempt nil
  "上一次连接失败的时间（`float-time'），用于退避重试。")

(defun typing-agent-keycast-socket-path ()
  "返回当前使用的注入 socket 路径。"
  (or typing-agent-keycast-socket
      (format "/tmp/keycastr-inject-%d.sock" (user-uid))))

(defun typing-agent-keycast--sentinel (process _event)
  "PROCESS 断开时清掉连接状态，下次输入重新连。"
  (when (eq process typing-agent-keycast--process)
    (setq typing-agent-keycast--process nil
          typing-agent-keycast--attempt nil)))

(defun typing-agent-keycast--connect ()
  "返回可用的 KeyCastr 连接；失败时返回 nil 并在退避期内不再尝试。
这里用的必须是数据报 socket：本机 Emacs 的 build 不支持 AF_UNIX 的
stream socket，数据报收发正常，而按键显示丢一个包也无所谓。"
  (let ((now (float-time)))
    (when (or (null typing-agent-keycast--attempt)
              (>= (- now typing-agent-keycast--attempt)
                  typing-agent-keycast-retry-interval))
      (condition-case nil
          (progn
            (setq typing-agent-keycast--process
                  (make-network-process
                   :name "typing-agent-keycast"
                   :family 'local
                   :service (typing-agent-keycast-socket-path)
                   :type 'datagram
                   :noquery t
                   :coding 'utf-8-unix
                   :sentinel #'typing-agent-keycast--sentinel))
            (setq typing-agent-keycast--attempt nil))
        (error
         (setq typing-agent-keycast--process nil
               typing-agent-keycast--attempt now))))
    (and (process-live-p typing-agent-keycast--process)
         typing-agent-keycast--process)))

(defun typing-agent-keycast--send (text &optional modifiers)
  "把 TEXT 和 MODIFIERS 发给 KeyCastr。
MODIFIERS 是 \"shift\"、\"control\"、\"option\"、\"command\" 的列表。
任何失败都静默忽略：按键显示不能影响正在进行的编辑任务。"
  (when (and typing-agent-keycast-enabled
             (stringp text)
             (> (length text) 0))
    (when-let* ((process (typing-agent-keycast--connect)))
      (condition-case nil
          (process-send-string
           process
           (concat
            (json-encode
             (if modifiers
                 (list (cons 'text text)
                       (cons 'modifiers (vconcat modifiers)))
               (list (cons 'text text))))
            "\n"))
        (error
         ;; 数据报 socket 的 connect 是“假”的：对端不存在时只有真正发送才
         ;; 会报错。这里记下失败时间，退避期内不再逐字符重试。
         (ignore-errors (delete-process process))
         (setq typing-agent-keycast--process nil
               typing-agent-keycast--attempt (float-time)))))))

(defun typing-agent-keycast--char-text (char)
  "把字符 CHAR 转成 KeyCastr 的显示文本。
控制字符用 `key-description'，例如 `C-g'；普通字符原样显示。"
  (or (cdr (assq char typing-agent-keycast-special-glyphs))
      (if (or (< char 32) (= char 127))
          (condition-case nil
              (key-description (vector char))
            (error nil))
        (char-to-string char))))

(defun typing-agent-keycast--event-text (event)
  "把 Emacs 按键事件 EVENT 转成 KeyCastr 的显示文本。"
  (cond
   ((characterp event)
    (typing-agent-keycast--char-text event))
   ((symbolp event)
    (pcase event
      ('escape "⎋")
      ('return "⏎")
      ('tab "⇥")
      ('backspace "⌫")
      ('delete "⌦")
      ('kp-enter "⏎")
      ('space "␣")
      (_ (condition-case nil
             (key-description (vector event))
           (error nil)))))
   (t nil)))

(defun typing-agent-keycast-mirror-event (event)
  "在 KeyCastr 上显示单个按键事件 EVENT。返回显示文本。"
  (when-let* ((text (typing-agent-keycast--event-text event)))
    (typing-agent-keycast--send text)
    text))

(defun typing-agent-keycast-mirror-text (text)
  "逐字符在 KeyCastr 上显示 TEXT。"
  (when (stringp text)
    (mapc (lambda (char)
            (typing-agent-keycast--send (typing-agent-keycast--char-text char)))
          (string-to-list text)))
  t)

(defun typing-agent-keycast-mirror-events (events)
  "在 KeyCastr 上依次显示 EVENTS。
EVENTS 可以是字符串、向量或事件列表。"
  (cond
   ((stringp events)
    (typing-agent-keycast-mirror-text events))
   ((vectorp events)
    (mapc #'typing-agent-keycast-mirror-event events))
   ((consp events)
    (mapc #'typing-agent-keycast-mirror-event events)))
  t)

(defun typing-agent-keycast-connected-p ()
  "当前是否已经连上 KeyCastr 的注入 socket。"
  (and (process-live-p typing-agent-keycast--process) t))

(provide 'typing-agent-keycast)
;;; typing-agent-keycast.el ends here
