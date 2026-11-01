;;; typing-agent-lock.el --- 任务运行期间的输入锁定 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 任务运行时把用户的键盘、鼠标输入全部拦下，避免误触打断打字。
;;
;; 两个关键点：
;;   1. agent 自己的按键必须放行。agent 走两条路：
;;      - `typing-agent-evil--execute-keys'（`execute-kbd-macro'）：执行期间
;;        `executing-kbd-macro' 为 t，靠它放行；
;;      - `typing-agent-evil--push-events'（`unread-command-events'）：这些
;;        事件在后续命令循环里执行时 `executing-kbd-macro' 已是 nil，所以
;;        推送时按事件数累加 `typing-agent--inject-count'，命令执行前递减
;;        放行。
;;   2. 停止不能靠本地按键：任务运行期间只通过 MCP 的 /stop（HTTP，走进程
;;      过滤器，不经命令循环，不受锁定影响）或
;;      `emacsclient -e "(typing-agent-cancel)"' 停止。
;;
;; 锁定范围是「任务 running → cleanup」，pause/resume 期间同样保持锁定。

;;; Code:

(require 'cl-lib)
(require 'typing-agent)

(defgroup typing-agent-lock nil
  "Typing Agent 任务期间的输入锁定。"
  :group 'typing-agent
  :prefix "typing-agent-")

(defcustom typing-agent-input-lock t
  "任务运行期间是否锁定用户输入。
开启后，任务执行中用户的键盘和鼠标输入都会被忽略，直到任务完成、
失败或被 MCP 取消；中途想停止只能通过 MCP 的 /stop，或
`emacsclient -e \"(typing-agent-cancel)\"'。"
  :type 'boolean
  :group 'typing-agent-lock)

(defvar typing-agent--input-locked nil
  "任务运行期间的非 nil 标志，`typing-agent-lock-mode' 据此拦截输入。")

(defvar typing-agent--inject-count 0
  "已注入 `unread-command-events' 但尚未执行的受信事件数。")

(defvar typing-agent--lock-warned nil
  "本次任务是否已经提示过输入被锁定。")

(defun typing-agent-lock-blocked ()
  "任务期间拦截的用户输入占位命令。
只做一次轻提示，其余时间静默忽略，避免刷屏。"
  (interactive)
  (unless typing-agent--lock-warned
    (setq typing-agent--lock-warned t)
    (message "Typing Agent 正在执行任务，输入已锁定；停止请用 MCP /stop")))

(defun typing-agent-lock-pre-command ()
  "在命令执行前拦截用户输入。
agent 用 `execute-kbd-macro' 发送的按键 `executing-kbd-macro' 为 t，直接
放行；用 `unread-command-events' 注入的按键靠 `typing-agent--inject-count'
放行；其余一律换成 `typing-agent-lock-blocked'。"
  (when (and typing-agent--input-locked
             (not executing-kbd-macro)
             (not (and (> typing-agent--inject-count 0)
                       (cl-decf typing-agent--inject-count))))
    (setq this-command #'typing-agent-lock-blocked)))

(define-minor-mode typing-agent-lock-mode
  "任务运行期间锁定用户输入，防止误触打断打字。"
  :global t
  :lighter " 🔒"
  :group 'typing-agent-lock
  (if typing-agent-lock-mode
      (progn
        ;; 深度 -90，抢在 evil 等大多数 pre-command 钩子之前把 this-command
        ;; 换成占位命令，让它们看到的也是被拦截后的命令。
        (add-hook 'pre-command-hook #'typing-agent-lock-pre-command -90)
        (setq typing-agent--lock-warned nil))
    (remove-hook 'pre-command-hook #'typing-agent-lock-pre-command)
    (setq typing-agent--input-locked nil
          typing-agent--inject-count 0
          typing-agent--lock-warned nil)))

(defun typing-agent-lock-on ()
  "开启输入锁定（幂等）。"
  (when typing-agent-input-lock
    (setq typing-agent--input-locked t
          typing-agent--inject-count 0
          typing-agent--lock-warned nil)
    (unless typing-agent-lock-mode
      (typing-agent-lock-mode 1))))

(defun typing-agent-lock-off ()
  "关闭输入锁定（幂等）。"
  (setq typing-agent--input-locked nil
        typing-agent--inject-count 0)
  (when typing-agent-lock-mode
    (typing-agent-lock-mode -1)))

(defun typing-agent-lock-trust-events (events)
  "把 EVENTS 计入受信事件数，供 `typing-agent-lock-pre-command' 放行。
在 `typing-agent-evil--push-events' 里调用。事件数取 list 长度作为上界：
命令循环可能把多个事件合成一个键序列（例如 ESC + x -> M-x），只触发一次
pre-command，因此计数只会残留不会为负，最多多放行一两个用户按键。"
  (cl-incf typing-agent--inject-count
           (length (append events nil))))

(provide 'typing-agent-lock)
;;; typing-agent-lock.el ends here
