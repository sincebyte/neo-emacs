;;; config.el -*- lexical-binding: t; -*-
;;
;; Emacs Typing Agent：让 OpenCode 通过可见的 Evil 按键修改代码。
;;
;; 启动本地 HTTP 服务（默认 127.0.0.1:8765），token 在
;; `~/.local/state/typing-agent/token'。
;;
;; 常用命令：
;;   M-x typing-agent-server-start / typing-agent-server-stop
;;   M-x typing-agent-server-status
;;   M-x typing-agent-recording-start / typing-agent-recording-stop
;;   M-x typing-agent-pause / typing-agent-resume / typing-agent-cancel
;;
;; 快捷键（SPC t y ...）：
;;   s  启动服务        S  停止服务        i  查看状态
;;   r  录制准备        R  退出录制        u  撤销当前任务
;;   p  暂停任务        c  继续任务        x  取消任务

(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'typing-agent)
(require 'typing-agent-humanizer)
(require 'typing-agent-keycast)
(require 'typing-agent-completion)
(require 'typing-agent-lock)
(require 'typing-agent-evil)
(require 'typing-agent-validator)
(require 'typing-agent-diff)
(require 'typing-agent-engine)
(require 'typing-agent-recording)
(require 'typing-agent-server)

(defvar typing-agent--initialized nil
  "模块是否已经完成初始化。")

(defun typing-agent-maybe-start-server ()
  "按 `typing-agent-auto-start' 启动本地 HTTP 服务。"
  (when (and typing-agent-auto-start (not noninteractive))
    (condition-case nil
        (typing-agent-server-start)
      (error nil))))

(defun typing-agent-pause ()
  "暂停当前 Typing Agent 任务。"
  (interactive)
  (if-let* ((task typing-agent--active-task))
      (typing-agent-engine-pause task)
    nil))

(defun typing-agent-resume ()
  "继续当前 Typing Agent 任务。"
  (interactive)
  (if-let* ((task typing-agent--active-task))
      (typing-agent-engine-resume task)
    nil))

(defun typing-agent-cancel ()
  "取消当前 Typing Agent 任务。"
  (interactive)
  (if-let* ((task typing-agent--active-task))
      (typing-agent-engine-cancel task)
    nil))

(defun typing-agent-undo-current ()
  "撤销当前（或最近一个）任务的全部修改。"
  (interactive)
  (if-let* ((task (typing-agent-task-current)))
      (typing-agent-engine-undo-task task)
    nil))

(defun typing-agent-init ()
  "初始化 Typing Agent。
只创建状态目录、绑定快捷键并启动服务，不修改任何 Doom 全局配置。"
  (unless typing-agent--initialized
    (setq typing-agent--initialized t)
    (typing-agent--state-dir)
    (typing-agent-maybe-start-server)
    (when (fboundp 'map!)
      (map! :leader
            :desc "Typing Agent: 启动服务" "t y s" #'typing-agent-server-start
            :desc "Typing Agent: 停止服务" "t y S" #'typing-agent-server-stop
            :desc "Typing Agent: 状态"     "t y i" #'typing-agent-server-status
            :desc "Typing Agent: 录制准备" "t y r" #'typing-agent-recording-start
            :desc "Typing Agent: 退出录制" "t y R" #'typing-agent-recording-stop
            :desc "Typing Agent: 撤销任务" "t y u" #'typing-agent-undo-current
            :desc "Typing Agent: 暂停"     "t y p" #'typing-agent-pause
            :desc "Typing Agent: 继续"     "t y c" #'typing-agent-resume
            :desc "Typing Agent: 取消"     "t y x" #'typing-agent-cancel))))

;; Doom 的 leader keymap 会在 `doom-after-init-hook' 里重建；
;; 所以初始化挂到 hook 末尾，避免快捷键被覆盖。
(if after-init-time
    (typing-agent-init)
  (add-hook 'doom-after-init-hook #'typing-agent-init t))

(provide 'neoemacs-typing-agent)
;;; config.el ends here
