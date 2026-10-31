;;; typing-agent-recording.el --- 录屏模式 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 录制模式只做“画面准备”，不控制 OBS。
;;
;;  - 保存/恢复窗口布局；
;;  - 让目标文件独占当前 frame；
;;  - 光标居中、留出滚动边距；
;;  - 任务结束时不弹出任何临时窗口。
;;
;; 不修改任何全局 Doom 配置；所有 buffer 局部变量在任务结束时恢复。

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'typing-agent)

(defvar typing-agent-recording--saved-config nil
  "录制前的窗口布局。")

(defvar typing-agent-recording--saved-scroll-margin nil
  "录制前的 `scroll-margin'，按 buffer 保存。")

(defvar-local typing-agent-recording--scroll-margin nil
  "本 buffer 录制前的滚动边距。")

(defvar-local typing-agent-recording--scroll-margin-was-local nil
  "本 buffer 录制前 `scroll-margin' 是否本来就是 buffer-local。")

(defcustom typing-agent-recording-scroll-margin 8
  "录制时保留的滚动边距（行数）。"
  :type 'integer
  :group 'typing-agent)

(defun typing-agent-recording-active-p ()
  "当前是否保存了录制布局。"
  (window-configuration-p typing-agent-recording--saved-config))

(defun typing-agent-recording-prepare-current ()
  "在当前 buffer 上做录制画面准备，不改变窗口布局。
设置滚动边距并让光标居中；重复调用不会覆盖最初保存的边距。"
  (unless (local-variable-p 'typing-agent-recording--scroll-margin)
    (setq-local typing-agent-recording--scroll-margin scroll-margin)
    (setq-local typing-agent-recording--scroll-margin-was-local
                (local-variable-p 'scroll-margin)))
  (setq-local scroll-margin typing-agent-recording-scroll-margin)
  (recenter)
  (redisplay t)
  t)

(defun typing-agent-recording-prepare (&optional file line)
  "准备录制画面。
FILE 非 nil 时打开它；LINE 非 nil 时跳转。
保留语法高亮和 Tree-sitter，不改变任何全局配置。"
  (when file
    (find-file file)
    (when (and line (integerp line) (> line 0))
      (goto-line line)))
  (delete-other-windows)
  (typing-agent-recording-prepare-current))

(defun typing-agent-recording-restore-scroll ()
  "恢复当前 buffer 的滚动边距。"
  (when (local-variable-p 'typing-agent-recording--scroll-margin)
    (if typing-agent-recording--scroll-margin-was-local
        (setq-local scroll-margin
                    (or typing-agent-recording--scroll-margin 0))
      (kill-local-variable 'scroll-margin))
    (kill-local-variable 'typing-agent-recording--scroll-margin)
    (kill-local-variable 'typing-agent-recording--scroll-margin-was-local)))

(defun typing-agent-recording-start (&optional file line)
  "保存当前窗口布局并进入录制准备状态。
FILE/LINE 同 `typing-agent-recording-prepare'。"
  (unless (typing-agent-recording-active-p)
    (setq typing-agent-recording--saved-config
          (current-window-configuration)))
  (typing-agent-recording-prepare file line))

(defun typing-agent-recording-stop (&optional keep-window)
  "退出录制模式并恢复之前的窗口布局。
KEEP-WINDOW 非 nil 时只恢复滚动边距，不改变当前窗口。"
  (typing-agent-recording-restore-scroll)
  (when (and (typing-agent-recording-active-p) (not keep-window))
    (set-window-configuration typing-agent-recording--saved-config))
  (setq typing-agent-recording--saved-config nil))

(provide 'typing-agent-recording)
;;; typing-agent-recording.el ends here
