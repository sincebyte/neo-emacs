;;; typing-agent-evil.el --- Evil 状态与按键适配 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Typing Agent 与 Evil 的唯一桥梁。
;;
;; 这里集中处理：
;;   - 读取当前 Evil state（不靠按键猜测）；
;;   - Normal / Insert 的进入与退出；
;;   - 发送真实键盘事件；
;;   - 在 Normal 状态下定位、移动、删除、缩进；
;;   - 任务级撤销边界。
;;
;; 所有编辑动作都要求明确的 Evil 状态。状态不明确时宁可报错，
;; 也不要在未知状态下直接发送按键。

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'typing-agent)
(require 'typing-agent-completion)

(declare-function evil-mode "evil")
(declare-function evil-insert "evil-commands")
(declare-function evil-append "evil-commands")
(declare-function evil-insert-line "evil-commands")
(declare-function evil-append-line "evil-commands")
(declare-function evil-open-below "evil-commands")
(declare-function evil-open-above "evil-commands")
(declare-function evil-delete "evil-commands")
(declare-function evil-normal-state "evil-states")
(declare-function evil-insert-state-p "evil-states")
(declare-function evil-normal-state-p "evil-states")
(declare-function evil-visual-state-p "evil-states")
(declare-function consult-buffer "consult")
(declare-function consult-recent-file "consult")
(declare-function project-find-file "project")
(declare-function project-current "project")
(declare-function dired "dired")
(declare-function dired-noselect "dired")
(declare-function dired-goto-file "dired")
(declare-function dired-get-filename "dired")
(declare-function dired-create-empty-file "dired-aux")

(defvar evil-mode)
(defvar evil-state)
(defvar evil-auto-indent)
(defvar recentf-mode)
(defvar recentf-list)

(defcustom typing-agent-evil-auto-normal t
  "遇到 Insert / Visual / Operator 状态时，是否自动按 ESC 回到 Normal。
关闭后，状态不符合要求就直接报错。"
  :type 'boolean
  :group 'typing-agent)

(defcustom typing-agent-evil-visual-delete-threshold 300
  "用 Visual 按键删除文本的最大字符数。
超过该长度时改用 `evil-delete' 批量删除，避免发送成百上千个移动键。"
  :type 'integer
  :group 'typing-agent)

(defcustom typing-agent-evil-bulk-delete nil
  "是否允许对长文本使用批量删除。
默认允许；设为 nil 时，超过阈值的删除会直接失败，要求调用方拆分任务。"
  :type 'boolean
  :group 'typing-agent)

;;; 状态检测

(defun typing-agent-evil-available-p ()
  "当前 buffer 是否启用了 Evil。"
  (and (boundp 'evil-mode)
       (bound-and-true-p evil-mode)
       (boundp 'evil-state)))

(defun typing-agent-evil-state ()
  "返回当前 buffer 的 Evil state 符号；没有 Evil 时返回 nil。"
  (and (typing-agent-evil-available-p)
       (symbolp evil-state)
       evil-state))

(defun typing-agent-evil-state-name ()
  "返回 Evil state 的字符串表示，供日志与 API 使用。"
  (if-let* ((state (typing-agent-evil-state)))
      (symbol-name state)
    "none"))

(defun typing-agent-evil-normal-p ()
  "当前是否处于 Evil Normal 状态。"
  (eq (typing-agent-evil-state) 'normal))

(defun typing-agent-evil-insert-p ()
  "当前是否处于 Evil Insert 状态。"
  (eq (typing-agent-evil-state) 'insert))

(defun typing-agent-evil-require-available ()
  "确认当前 buffer 启用了 Evil，否则报错。"
  (unless (typing-agent-evil-available-p)
    (signal 'typing-agent-state-error
            (list (format "当前 buffer %s 未启用 Evil，无法执行按键编辑"
                          (buffer-name))))))

;;; 发送按键

(defun typing-agent-evil--execute-keys (macro)
  "在当前 buffer 中执行键盘宏 MACRO。
`execute-kbd-macro' 把每条命令都执行在 selected window 的 buffer 上：
窗口没跟着切换时（比如 batch 测试），按键就会落到别的 buffer。这里先把
当前 buffer 放进 selected window，执行完再把当前 buffer 切回来。"
  (let ((buffer (current-buffer)))
    (let ((window (selected-window)))
      (when (and (windowp window)
                 (window-live-p window)
                 (not (window-minibuffer-p window))
                 (not (eq (window-buffer window) buffer)))
        (condition-case nil
            (set-window-buffer window buffer)
          (error nil))))
    (unwind-protect
        (execute-kbd-macro macro)
      (when (buffer-live-p buffer)
        (set-buffer buffer)))))

(defun typing-agent-evil-send-keys (keys)
  "发送 KEYS，KEYS 使用 `kbd' 语法。
这是 Emacs 内部键盘事件，不是直接调用编辑函数。"
  (typing-agent-evil--execute-keys (kbd keys))
  t)

(defun typing-agent-evil-send-char (char)
  "发送一个字符 CHAR 的键盘事件。
RET 发送为 Return 键；TAB 用 `insert' 精确插入，避免触发 yasnippet；
其余字符作为普通 self-insert 事件发送。"
  (cond
   ((memq char '(?\n ?\r))
    (typing-agent-evil--execute-keys (vector ?\r)))
   ((eq char ?\t)
    ;; Doom 的 Insert 状态把 TAB 绑定到 yas-expand；这里直接插入制表符，
    ;; 保证文件内容与任务预期完全一致。
    (insert "\t"))
   ((characterp char)
    (typing-agent-evil--execute-keys (vector char)))
   (t
    (signal 'typing-agent-input-error
            (list (format "无法发送非字符事件: %S" char)))))
  t)

(defun typing-agent-evil-send-string-fast (string)
  "一次性发送 STRING 的按键事件。
只用于不需要逐字符模拟的控制键序列（例如搜索串）。"
  (typing-agent-evil--execute-keys (string-to-vector string))
  t)

;;; 状态切换

(defun typing-agent-evil-ensure-normal (&optional context)
  "确保当前处于 Evil Normal 状态。
CONTEXT 用于错误信息。允许的转换：
  normal / motion              -> 直接通过
  insert / replace / visual   -> 发送 ESC
  operator                    -> 发送 ESC 取消
  emacs                       -> 仅当 `typing-agent-evil-auto-normal' 时切换
其他状态直接报错。"
  (typing-agent-evil-require-available)
  (let ((state (typing-agent-evil-state)))
    (pcase state
      ((or 'normal 'motion) t)
      ((or 'insert 'replace 'visual 'operator)
       (unless typing-agent-evil-auto-normal
         (signal 'typing-agent-state-error
                 (list (format "%s：要求 Normal 状态，当前为 %s"
                               (or context "操作") state))))
       ;; 最多按三次 ESC，处理 operator + visual 叠加的情况。
       (dotimes (_ 3)
         (when (memq (typing-agent-evil-state)
                     '(insert replace visual operator))
           (typing-agent-evil--execute-keys (vector 27))))
       (unless (typing-agent-evil-normal-p)
         (signal 'typing-agent-state-error
                 (list (format "%s：按 ESC 后仍未回到 Normal，当前为 %s"
                               (or context "操作")
                               (typing-agent-evil-state-name)))))
       t)
      ('emacs
       (unless typing-agent-evil-auto-normal
         (signal 'typing-agent-state-error
                 (list (format "%s：当前为 Emacs 状态，请先切换到 Normal"
                               (or context "操作")))))
       (when (fboundp 'evil-normal-state)
         (evil-normal-state))
       (unless (typing-agent-evil-normal-p)
         (signal 'typing-agent-state-error
                 (list (format "%s：无法从 Emacs 状态回到 Normal" context))))
       t)
      (_
       (signal 'typing-agent-state-error
               (list (format "%s：未知 Evil 状态 %S"
                             (or context "操作") state)))))))

(defun typing-agent-evil-require-normal (context)
  "要求当前处于 Normal，否则报错。CONTEXT 用于错误信息。"
  (typing-agent-evil-ensure-normal context)
  (unless (typing-agent-evil-normal-p)
    (signal 'typing-agent-state-error
            (list (format "%s：要求 Normal 状态，当前为 %s"
                          context (typing-agent-evil-state-name))))))

(defconst typing-agent-evil-insert-commands
  '("i" "a" "I" "A" "o" "O")
  "允许的进入 Insert 模式命令。")

(defun typing-agent-evil-enter-insert (command)
  "用 Evil 命令 COMMAND 进入 Insert 模式。
COMMAND 必须是 i/a/I/A/o/O 之一。执行前要求 Normal，执行后校验状态。
打开新行时临时关闭 `evil-auto-indent'，让任务自己控制每一行缩进。"
  (typing-agent-evil-require-normal "enter_insert")
  (unless (member command typing-agent-evil-insert-commands)
    (signal 'typing-agent-input-error
            (list (format "不支持的进入 Insert 命令: %s" command))))
  (let ((evil-auto-indent nil))
    (typing-agent-evil--execute-keys (kbd command)))
  (unless (typing-agent-evil-insert-p)
    (signal 'typing-agent-state-error
            (list (format "执行 %s 后没有进入 Insert 状态，当前为 %s"
                          command (typing-agent-evil-state-name)))))
  t)

(defun typing-agent-evil-exit-insert ()
  "退出 Insert 模式并确认回到 Normal。
已经是 Normal 时直接返回 t。"
  (typing-agent-evil-require-available)
  (cond
   ((typing-agent-evil-normal-p) t)
   ((typing-agent-evil-insert-p)
    ;; 先收起补全弹框，避免 ESC 被 corfu 的按键映射吃掉。
    (typing-agent-completion-quit)
    (typing-agent-evil--execute-keys (vector 27))
    (unless (typing-agent-evil-normal-p)
      ;; ESC 被用户配置拦截时，用 Evil 的状态函数兜底，并记录一次警告。
      (when (fboundp 'evil-normal-state)
        (evil-normal-state))
      (unless (typing-agent-evil-normal-p)
        (signal 'typing-agent-state-error
                (list (format "退出 Insert 后仍未回到 Normal，当前为 %s"
                              (typing-agent-evil-state-name))))))
    t)
   (t
    (signal 'typing-agent-state-error
            (list (format "exit_insert：当前不在 Insert 状态（%s）"
                          (typing-agent-evil-state-name)))))))

;;; 定位

(defun typing-agent-evil-literal-positions (text &optional from)
  "返回 TEXT 在 buffer 中所有出现位置的列表（升序）。
FROM 为搜索起点，默认 `point-min'。大小写敏感，按字面匹配。"
  (unless (and (stringp text) (not (string-empty-p text)))
    (signal 'typing-agent-input-error (list "搜索文本不能为空")))
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (or from (point-min)))
      (let ((case-fold-search nil)
            (positions nil))
        (while (search-forward text nil t)
          (push (match-beginning 0) positions))
        (nreverse positions)))))

(defun typing-agent-evil-locate (text &optional occurrence unique)
  "定位 TEXT 并返回位置。
OCCURRENCE 为第几个匹配（从 1 开始）；为 nil 时要求 TEXT 全局唯一。
UNIQUE 为 nil 时允许指定 OCCURRENCE。定位失败抛出
`typing-agent-locate-error'，绝不猜测位置。"
  (let* ((positions (typing-agent-evil-literal-positions text))
         (count (length positions)))
    (cond
     ((zerop count)
      (signal 'typing-agent-locate-error
              (list (format "找不到文本（前 80 字符）：%s"
                            (substring text 0 (min 80 (length text)))))))
     ((and occurrence (> occurrence count))
      (signal 'typing-agent-locate-error
              (list (format "要求第 %d 个匹配，但只有 %d 个：%s"
                            occurrence count
                            (substring text 0 (min 60 (length text)))))))
     ((and (null occurrence) (> count 1) unique)
      (signal 'typing-agent-locate-error
              (list (format "文本不唯一（%d 处匹配），拒绝盲目定位：%s"
                            count
                            (substring text 0 (min 60 (length text)))))))
     (t
      (nth (1- (or occurrence 1)) positions)))))

(defun typing-agent-evil-search-text (text &optional occurrence unique)
  "在 Normal 状态下把光标移动到 TEXT 的位置。
OCCURRENCE/UNIQUE 同 `typing-agent-evil-locate'。
移动时在 Echo Area 显示搜索提示，并闪烁当前匹配。"
  (typing-agent-evil-require-normal "search_text")
  (let ((pos (typing-agent-evil-locate text occurrence unique)))
    (goto-char pos)
    ;; 让画面里能看出“刚刚搜索过”，不改变 buffer。
    (when (fboundp 'evil-flash-search-pattern)
      (save-excursion
        (when (looking-at (regexp-quote text))
          (evil-flash-search-pattern
           (format "搜索: %s" (substring text 0 (min 60 (length text))))))))
    pos))

(defun typing-agent-evil-goto-line (line)
  "在 Normal 状态下跳到 LINE（从 1 开始）。
LINE 超出范围时报错。"
  (typing-agent-evil-require-normal "goto_line")
  (unless (and (integerp line) (>= line 1))
    (signal 'typing-agent-input-error
            (list (format "行号必须是正整数: %S" line))))
  (save-restriction
    (widen)
    (let ((max-line (line-number-at-pos (point-max))))
      (when (> line max-line)
        (signal 'typing-agent-locate-error
                (list (format "行号 %d 超出文件范围（共 %d 行）"
                              line max-line))))
      (goto-line line)))
  (beginning-of-line)
  t)

;;; 移动

(defconst typing-agent-evil-move-positions
  '("line_start" "line_end" "after_line" "before_line"
    "next_line" "prev_line" "buffer_start" "buffer_end"
    "word_forward" "word_backward" "char_forward" "char_backward")
  "`typing-agent-evil-move-cursor' 支持的语义位置。")

(defun typing-agent-evil-move-cursor (position &optional count)
  "在 Normal 状态下移动光标。
POSITION 见 `typing-agent-evil-move-positions'。
COUNT 为重复次数，默认 1。"
  (typing-agent-evil-require-normal "move_cursor")
  (let ((count (or count 1)))
    (unless (and (integerp count) (> count 0))
      (signal 'typing-agent-input-error
              (list (format "移动次数必须是正整数: %S" count))))
    (pcase position
      ((or "line_start" "before_line" "beginning_of_line")
       (typing-agent-evil--execute-keys (kbd "0")))
      ((or "line_end" "after_line" "end_of_line")
       (typing-agent-evil--execute-keys (kbd "$")))
      ("next_line"
       (dotimes (_ count) (typing-agent-evil--execute-keys (kbd "j"))))
      ("prev_line"
       (dotimes (_ count) (typing-agent-evil--execute-keys (kbd "k"))))
      ("buffer_start"
       (typing-agent-evil--execute-keys (kbd "gg")))
      ("buffer_end"
       (typing-agent-evil--execute-keys (kbd "G")))
      ("word_forward"
       (dotimes (_ count) (typing-agent-evil--execute-keys (kbd "w"))))
      ("word_backward"
       (dotimes (_ count) (typing-agent-evil--execute-keys (kbd "b"))))
      ("char_forward"
       (dotimes (_ count) (typing-agent-evil--execute-keys (kbd "l"))))
      ("char_backward"
       (dotimes (_ count) (typing-agent-evil--execute-keys (kbd "h"))))
      (_
       (signal 'typing-agent-input-error
               (list (format "不支持的移动位置: %s" position)))))
    t))

;;; 删除

(defun typing-agent-evil-delete-lines (count)
  "在 Normal 状态下用 dd 删除 COUNT 行。"
  (typing-agent-evil-require-normal "delete_lines")
  (unless (and (integerp count) (> count 0))
    (signal 'typing-agent-input-error
            (list (format "删除行数必须是正整数: %S" count))))
  (dotimes (_ count)
    (typing-agent-evil--execute-keys (kbd "dd")))
  t)

(defun typing-agent-evil--whole-line-region-p (beg end)
  "BEG..END 是否恰好覆盖完整的若干行。
要求两端的行前位置都在行首（或 buffer 边界）。"
  (and (or (= beg (point-min))
           (save-excursion (goto-char beg) (bolp)))
       (or (= end (point-max))
           (save-excursion (goto-char end) (bolp)))))

(defun typing-agent-evil-delete-region (beg end)
  "删除 BEG..END。
整行区域用 Visual Line（V + j + d）删除，单行短文本用 Visual 字符删除；
跨行且不是整行的少量文本交给 `evil-delete'。真正的大块删除必须显式允许
（`typing-agent-evil-bulk-delete'），否则报错要求拆分任务。"
  (typing-agent-evil-require-normal "delete_text")
  (let ((length (- end beg)))
    (when (<= length 0)
      (signal 'typing-agent-input-error (list "删除区域为空")))
    (let ((single-line-p
           (not (string-match-p "\n"
                                (buffer-substring-no-properties beg end)))))
      (cond
       ;; 整行：用 dd 删除，和真人按 dd 一致。
       ((typing-agent-evil--whole-line-region-p beg end)
        (goto-char beg)
        (typing-agent-evil-delete-lines (max 1 (count-lines beg end))))
       ;; 单行短文本：Visual 字符删除。
       ((and single-line-p
             (<= length typing-agent-evil-visual-delete-threshold))
        (goto-char beg)
        (typing-agent-evil--execute-keys (kbd "v"))
        (dotimes (_ (1- length))
          (typing-agent-evil--execute-keys (kbd "l")))
        (typing-agent-evil--execute-keys (kbd "d")))
       ;; 跨行的小块：交给 Evil 删除命令。
       ((<= length typing-agent-evil-visual-delete-threshold)
        (with-no-warnings
          (if (fboundp 'evil-delete)
              (evil-delete beg end 'char)
            (delete-region beg end))))
       (t
        (unless typing-agent-evil-bulk-delete
          (signal 'typing-agent-state-error
                  (list (format "要删除 %d 个字符，超过 Visual 阈值 %d；请拆分任务"
                                length
                                typing-agent-evil-visual-delete-threshold))))
        (with-no-warnings
          (if (fboundp 'evil-delete)
              (evil-delete beg end 'char)
            (delete-region beg end))))))
    t))

(defun typing-agent-evil-delete-match (text &optional occurrence)
  "定位并删除 TEXT。OCCURRENCE 同 `typing-agent-evil-locate'。"
  (typing-agent-evil-require-normal "delete_text")
  (let* ((pos (typing-agent-evil-locate text occurrence))
         (end (+ pos (length text))))
    (goto-char pos)
    (typing-agent-evil-delete-region pos end)))

;;; 缩进

(defun typing-agent-evil-indent (lines)
  "在 Normal 状态下用 Evil 的 = 操作重新缩进 LINES 行。"
  (typing-agent-evil-require-normal "indent")
  (unless (and (integerp lines) (> lines 0))
    (signal 'typing-agent-input-error
            (list (format "缩进行数必须是正整数: %S" lines))))
  (if (= lines 1)
      (typing-agent-evil--execute-keys (kbd "=="))
    (progn
      (typing-agent-evil--execute-keys (kbd "V"))
      (dotimes (_ (1- lines))
        (typing-agent-evil--execute-keys (kbd "j")))
      (typing-agent-evil--execute-keys (kbd "="))))
  t)

;;; 撤销

(defun typing-agent-evil-undo-step ()
  "在 Normal 状态下按一次 Evil 的撤销键（u）。
每次都是独立的用户可见按键，因此能配合 undo-tree / undo-fu 等撤销后端。"
  (typing-agent-evil-require-normal "undo")
  (typing-agent-evil--execute-keys (kbd "u"))
  t)

(defun typing-agent-evil-undo (count)
  "发送 COUNT 次 Evil 的撤销（u）。"
  (dotimes (_ (max 1 (or count 1)))
    (typing-agent-evil-undo-step))
  t)

;;; 像人一样切换 buffer / 打开文件

(defcustom typing-agent-confirm-pause 1.0
  "输入文件名之后、按回车确认之前的停顿，单位：秒。
创建文件和切换 buffer 都使用它：名字先出现在提示框里，停一下再回车。"
  :type 'number
  :group 'typing-agent)

(defcustom typing-agent-visit-method 'auto
  "查看或切换文件时使用的交互方式。
`auto' 按场景选择：已经打开的 buffer 用 `consult-buffer'，最近文件用
`consult-recent-file'，项目内文件用 `project-find-file'，其余用
`find-file'。也可以指定其中一个命令；`direct' 表示不弹选择框。
无论哪种方式，都会先弹出选择框、输入名字，再回车跳过去。"
  :type '(choice (const auto)
                 (const consult-buffer)
                 (const consult-recent-file)
                 (const project-find-file)
                 (const find-file)
                 (const direct))
  :group 'typing-agent)

(defcustom typing-agent-visit-pause 0.6
  "文件跳转时，选择框出现后停多久再输入名字，单位：秒。"
  :type 'number
  :group 'typing-agent)

(defcustom typing-agent-visit-char-delay 0.15
  "文件跳转时，在选择框里逐字符输入名字的间隔，单位：秒。"
  :type 'number
  :group 'typing-agent)

(defcustom typing-agent-visit-timeout 6.0
  "文件跳转时，等待每一步生效的最长时间，单位：秒。
超时就收掉还开着的选择框并直接切换，避免卡在 minibuffer 里。"
  :type 'number
  :group 'typing-agent)

(defvar typing-agent-evil--visit-token 0
  "当前这次「人式切换」的编号，用来丢弃过期的按键序列。")

(defun typing-agent-evil--poll-until (pred ok &optional timeout delay guard on-timeout)
  "轮询 PRED，为真时停 DELAY 秒再调用 OK。
GUARD 返回 nil 时停止轮询；超过 TIMEOUT 秒调用 ON-TIMEOUT。
DELAY 为 0 表示立刻调用 OK。"
  (let ((deadline (+ (float-time) (or timeout typing-agent-visit-timeout))))
    (cl-labels
        ((check ()
           (cond
            ((and guard (not (funcall guard))) nil)
            ((funcall pred)
             (run-at-time (if (numberp delay) delay 0.5) nil ok))
            ((>= (float-time) deadline)
             (when on-timeout (funcall on-timeout)))
            (t
             (run-at-time 0.08 nil #'check)))))
      (run-at-time 0 nil #'check))))

(defun typing-agent-evil--visit-prompt-p ()
  "当前 minibuffer 是否已经变成了文件 / buffer 选择框。
不同选择器的提示词不一样（Doom 的 consult-buffer 是 “Switch to: ”），
所以只排除 M-x 这类命令提示，其余都当作选择框。"
  (and (active-minibuffer-window)
       (ignore-errors
         (with-selected-window (active-minibuffer-window)
           (let ((prompt (minibuffer-prompt)))
             (and (stringp prompt)
                  (not (string-match-p "\\`M-x " prompt))))))))

(defun typing-agent-evil--visit-abort-minibuffer ()
  "选择框还开着时按 C-g 收掉它。"
  (when (active-minibuffer-window)
    (typing-agent-evil--push-events (vector 7))))

(defun typing-agent-evil--visit-force-direct (file line tries)
  "最多试 TRIES 次收掉选择框，然后直接打开 FILE 的 LINE。"
  (if (and (> tries 0) (active-minibuffer-window))
      (progn
        (typing-agent-evil--visit-abort-minibuffer)
        (run-at-time
         0.3 nil
         (lambda ()
           (typing-agent-evil--visit-force-direct file line (1- tries)))))
    (typing-agent-evil--visit-direct file line)))

(defun typing-agent-evil--command-keys (command)
  "返回 COMMAND 在当前按键映射中的按键序列，找不到时返回 nil。"
  (or (where-is-internal command nil t)
      (where-is-internal command (current-global-map) t)))

(defun typing-agent-evil--push-events (events)
  "把 EVENTS 注入 `unread-command-events'，让命令循环当成真实按键处理。"
  (setq unread-command-events
        (append (append events nil) unread-command-events)))

(defun typing-agent-evil--visit-plan (file &optional already)
  "为 FILE 选择「人式打开」方式，返回 (COMMAND INPUT)，direct 时返回 nil。
ALREADY 非空表示 FILE 的 buffer 已经打开，此时用 buffer 选择器；否则
按最近文件、项目文件、普通 find-file 的顺序选择。"
  (let* ((file (expand-file-name file))
         (buffer (find-buffer-visiting file))
         (name (file-name-nondirectory file))
         (method typing-agent-visit-method))
    (cond
     ((eq method 'direct) nil)
     ((eq method 'consult-buffer)
      (list 'consult-buffer (or (and buffer (buffer-name buffer)) name)))
     ((eq method 'consult-recent-file) (list 'consult-recent-file name))
     ((eq method 'project-find-file) (list 'project-find-file name))
     ((eq method 'find-file) (list 'find-file file))
     ;; auto：已打开的 buffer 用 buffer 选择器。
     ((and already buffer (fboundp 'consult-buffer))
      (list 'consult-buffer (buffer-name buffer)))
     ((and (bound-and-true-p recentf-mode)
           (fboundp 'consult-recent-file)
           (member file (mapcar #'expand-file-name recentf-list)))
      (list 'consult-recent-file name))
     ((and (fboundp 'project-find-file)
           (let ((inhibit-message t))
             (ignore-errors
               (project-current nil (file-name-directory file)))))
      (list 'project-find-file name))
     (t (list 'find-file file)))))

(defun typing-agent-evil--visit-finish (file line)
  "切到 FILE 的 buffer 后跳到 LINE，并保持窗口单窗口、全尺寸。"
  (let ((buffer (find-buffer-visiting (expand-file-name file))))
    (when (buffer-live-p buffer)
      (unless (eq (window-buffer (selected-window)) buffer)
        (ignore-errors (set-window-buffer (selected-window) buffer)))
      (with-current-buffer buffer
        (when (and (integerp line) (> line 0))
          (goto-line line))
        (recenter))
      (when (> (length (window-list)) 1)
        (ignore-errors (delete-other-windows)))
      buffer)))

(defun typing-agent-evil--visit-direct (file line)
  "不经过选择框，直接把 FILE 显示出来并跳到 LINE。"
  (let ((buffer (find-file-noselect (expand-file-name file))))
    (unless (eq (window-buffer (selected-window)) buffer)
      (switch-to-buffer buffer))
    (typing-agent-evil--visit-finish file line)))

(defun typing-agent-evil--visit-with-selector (base keys input file line)
  "在 BASE buffer 中按 KEYS 弹出选择框，逐字输入 INPUT，回车后跳到 FILE 的 LINE。
每一步都等上一步真的生效：选择框出现、名字逐字出现在提示框里、回车后
buffer 真的切过去。超时（`typing-agent-visit-timeout'）才收掉选择框直接切换，
避免卡在 minibuffer 里。"
  (let* ((token (cl-incf typing-agent-evil--visit-token))
         (target (expand-file-name file))
         (name (or input (file-name-nondirectory file)))
         (alive (lambda () (= token typing-agent-evil--visit-token)))
         (give-up
          (lambda ()
            (when (funcall alive)
              (cl-incf typing-agent-evil--visit-token)
              (typing-agent-evil--visit-force-direct file line 3)))))
    (cl-labels
        ((confirm ()
           (when (funcall alive)
             (if (not (active-minibuffer-window))
                 (funcall give-up)
               ;; 名字停够时间再回车。
               (typing-agent-evil--push-events (kbd "RET"))
               (typing-agent-evil--poll-until
                (lambda ()
                  ;; 选择框关掉、文件 buffer 也在，就算跳转完成；
                  ;; 窗口由 `typing-agent-evil--visit-finish' 统一整理。
                  (let ((buffer (find-buffer-visiting target)))
                    (and (buffer-live-p buffer)
                         (not (active-minibuffer-window)))))
                (lambda ()
                  (when (funcall alive)
                    (typing-agent-evil--visit-finish file line)))
                typing-agent-visit-timeout 0 alive give-up))))
         (type-name (chars index)
           (when (funcall alive)
             (if (>= index (length chars))
                 (run-at-time typing-agent-confirm-pause nil #'confirm)
               (let ((before (typing-agent-evil--create-minibuffer-contents)))
                 (typing-agent-evil--push-events (vector (aref chars index)))
                 ;; 等这个字符真的出现在提示框里，再敲下一个，避免事件乱序。
                 (typing-agent-evil--poll-until
                  (lambda ()
                    (let ((now (typing-agent-evil--create-minibuffer-contents)))
                      (and (stringp now)
                           (not (equal now before)))))
                  (lambda ()
                    (run-at-time typing-agent-visit-char-delay nil
                                 (lambda ()
                                   (type-name chars (1+ index)))))
                  typing-agent-visit-timeout 0 alive give-up))))))
      (run-at-time
       0 nil
       (lambda ()
         (when (funcall alive)
           ;; 按键由命令循环在选中窗口的 buffer 里执行；先把它切成
           ;; 用户正在看的 buffer，Doom 的 SPC 前缀才会命中。
           (set-buffer base)
           (let ((start (lambda ()
                          (when (funcall alive)
                            (typing-agent-evil--push-events keys)))))
             (if (typing-agent-evil-insert-p)
                 ;; ESC 和后面的键分开送，否则会被当成 Meta 前缀。
                 (progn
                   (typing-agent-evil--push-events (vector 27))
                   (run-at-time 0.3 nil start))
               (funcall start))))))
      (typing-agent-evil--poll-until
       #'typing-agent-evil--visit-prompt-p
       (lambda ()
         (when (funcall alive)
           (type-name (string-to-vector name) 0)))
       typing-agent-visit-timeout typing-agent-visit-pause alive give-up)
      t)))

;;; 像人一样创建文件（dired）

(defcustom typing-agent-create-pause 0.6
  "在 dired 中创建文件时，每个阶段之间的停顿，单位：秒。
dired 出现、按下新建键、输入完文件名、创建完成、打开文件，各停一下。"
  :type 'number
  :group 'typing-agent)

(defcustom typing-agent-create-char-delay 0.15
  "在「Create empty file:」提示里逐字符输入文件名时的间隔，单位：秒。"
  :type 'number
  :group 'typing-agent)

(defcustom typing-agent-create-timeout 6.0
  "dired 创建流程中等待每一步生效的最长时间，单位：秒。
超过这个时间就记录原因并退回直接创建，避免任务卡死。"
  :type 'number
  :group 'typing-agent)

(defvar typing-agent-evil--create-token 0
  "当前这次「人式创建文件」的编号，用来丢弃过期的按键序列。")

(defun typing-agent-evil--create-direct (file callback)
  "不经过 dired，直接创建空文件 FILE，然后调用 CALLBACK。
只在没有命令循环或 dired 流程失败时使用。"
  (let* ((file (expand-file-name file))
         (buffer (progn
                   (make-directory (file-name-directory file) t)
                   (with-temp-file file)
                   (find-file-noselect file))))
    (unless (eq (window-buffer (selected-window)) buffer)
      (ignore-errors (switch-to-buffer buffer)))
    (when callback (funcall callback buffer))
    buffer))

(defun typing-agent-evil--dired-mode-p (buffer)
  "BUFFER 是否是 dired。"
  (and (buffer-live-p buffer)
       (with-current-buffer buffer
         (derived-mode-p 'dired-mode))))

(defun typing-agent-evil--create-keys ()
  "返回在 dired 中新建空文件的按键序列。
没有直接绑定时退回 M-x 调用，画面里仍然看得到命令和提示。"
  (or (where-is-internal 'dired-create-empty-file nil t)
      (kbd "M-x dired-create-empty-file RET")))

(defun typing-agent-evil--create-prompt-p ()
  "当前 minibuffer 是否已经是「Create empty file」的文件名提示。
用来确认 M-x 或新建键之后真的停在了等待输入文件名的地方。"
  (and (active-minibuffer-window)
       (ignore-errors
         (with-selected-window (active-minibuffer-window)
           (let ((prompt (minibuffer-prompt)))
             (and (stringp prompt)
                  (string-match-p "empty file" prompt)))))))

(defun typing-agent-evil--create-log (log level message)
  "把 MESSAGE 交给任务的日志函数 LOG。"
  (when log
    (ignore-errors (funcall log level message))))

(defun typing-agent-evil--create-minibuffer-contents ()
  "返回当前 minibuffer 的内容；没有 minibuffer 时返回 nil。"
  (let ((window (active-minibuffer-window)))
    (and window
         (with-selected-window window
           (minibuffer-contents-no-properties)))))

(defun typing-agent-evil--create-show-dired (dir)
  "把 DIR 的 dired 显示在当前窗口，并让整个 frame 只留它。"
  (let ((buffer (dired-noselect (file-name-as-directory dir))))
    (unless (eq (window-buffer (selected-window)) buffer)
      (switch-to-buffer buffer))
    (when (> (length (window-list)) 1)
      (ignore-errors (delete-other-windows)))
    (with-current-buffer buffer
      (goto-char (point-min)))
    buffer))

(defun typing-agent-evil-create-file (file callback &optional guard log)
  "在 dired 中像人一样创建 FILE，完成后调用 CALLBACK。
过程由真实按键驱动，每一步都等到状态真的变化才继续：

  1. 打开父目录的 dired，停一下让目录列表出现；
  2. 按 dired 的「新建空文件」键，等文件名提示出现；
  3. 逐字符输入文件名；
  4. 停 `typing-agent-confirm-pause' 再回车创建；
  5. 等文件真的出现、dired 刷新后，按回车打开它。

GUARD 返回 nil 时中止后续按键（用于任务被取消）。LOG 是
\(LEVEL MESSAGE) 形式的日志函数，可省略。CALLBACK 收到文件 buffer。
批处理环境或某一步超时（`typing-agent-create-timeout'）时退回直接创建，
并记录原因，保证任务仍能继续。"
  (let* ((file (expand-file-name file))
         (dir (file-name-directory file))
         (name (file-name-nondirectory file))
         (target (file-truename file))
         (token (cl-incf typing-agent-evil--create-token))
         (base (window-buffer (selected-window)))
         (pause typing-agent-create-pause)
         (aborted nil))
    (cl-labels
        ((alive-p ()
           (and (not aborted)
                (= token typing-agent-evil--create-token)
                (or (null guard) (funcall guard))))
         (note (message)
           (typing-agent-evil--create-log log 'info message))
         (open-file ()
           (when callback
             (funcall callback (find-buffer-visiting target))))
         (fail (reason)
           (unless aborted
             (setq aborted t)
             (setq typing-agent-evil--create-token
                   (1+ typing-agent-evil--create-token))
             (typing-agent-evil--create-log
              log 'warn (format "dired 创建文件失败（%s），退回直接创建" reason))
             ;; 收掉还开着的提示框，避免后续按键落进 minibuffer。
             (when (active-minibuffer-window)
               (typing-agent-evil--push-events (vector 7)))
             (run-at-time
              0.35 nil
              (lambda ()
                (when (or (null guard) (funcall guard))
                  (typing-agent-evil--create-direct file callback))))))
         (poll-until (pred ok reason &optional delay)
           (typing-agent-evil--poll-until
            pred ok typing-agent-create-timeout delay #'alive-p
            (lambda () (fail reason))))
         (open-created ()
           (when (alive-p)
             (let ((buffer (window-buffer (selected-window))))
               (if (not (typing-agent-evil--dired-mode-p buffer))
                   (fail "创建完成后不在 dired 里")
                 (let ((found
                        (with-current-buffer buffer
                          (goto-char (point-min))
                          (ignore-errors (dired-goto-file target))
                          (let ((shown (ignore-errors
                                        (dired-get-filename nil t))))
                            (and shown
                                 (string= (file-truename
                                           (expand-file-name shown))
                                          target))))))
                   (if (not found)
                       (fail "dired 里找不到新建的文件")
                     (note "回车打开新建的文件")
                     (with-current-buffer buffer
                       (typing-agent-evil--execute-keys (kbd "RET")))
                     (poll-until
                      (lambda () (find-buffer-visiting target))
                      #'open-file
                      "打开文件失败"
                      pause)))))))
         (confirm-create ()
           (when (alive-p)
             (if (not (active-minibuffer-window))
                 (fail "输入文件名时提示框已经关闭")
               (note "文件名校对后回车创建")
               (run-at-time typing-agent-confirm-pause nil
                            (lambda ()
                              (when (alive-p)
                                (typing-agent-evil--push-events (kbd "RET"))
                                (poll-until
                                 (lambda () (file-exists-p file))
                                 (lambda ()
                                   (note "文件已创建，等 dired 刷新")
                                   (open-created))
                                 "文件没有创建出来"
                                 pause)))))))
         (type-each (chars index)
           (when (alive-p)
             (if (>= index (length chars))
                 (run-at-time pause nil #'confirm-create)
               (let ((before (typing-agent-evil--create-minibuffer-contents)))
                 (typing-agent-evil--push-events (vector (aref chars index)))
                 ;; 等这个字符真的出现在提示里，再敲下一个，避免事件乱序。
                 (poll-until
                  (lambda ()
                    (let ((now (typing-agent-evil--create-minibuffer-contents)))
                      (and (stringp now)
                           (not (equal now before)))))
                  (lambda ()
                    (run-at-time typing-agent-create-char-delay nil
                                 (lambda ()
                                   (type-each chars (1+ index)))))
                  "输入文件名时按键没有生效"
                  0)))))
         (type-file-name ()
           (when (alive-p)
             (let ((contents (typing-agent-evil--create-minibuffer-contents)))
               (if (and (stringp contents)
                        (not (string-empty-p contents))
                        (not (string-suffix-p "/" contents)))
                   ;; 提示框里预填了别的内容：先清空再重来。
                   (progn
                     (typing-agent-evil--push-events (kbd "C-a C-k"))
                     (poll-until
                      (lambda ()
                        (let ((now (typing-agent-evil--create-minibuffer-contents)))
                          (and (stringp now)
                               (or (string-empty-p now)
                                   (string-suffix-p "/" now)))))
                      #'type-file-name
                      "清空文件名提示失败"
                      0))
                 (note (format "输入文件名：%s" name))
                 (type-each (string-to-vector name) 0)))))
         (press-create-key ()
           (when (alive-p)
             (let ((buffer (window-buffer (selected-window))))
               (if (not (typing-agent-evil--dired-mode-p buffer))
                   (fail "没有进入 dired")
                 (let ((send
                        (lambda ()
                          (when (alive-p)
                            (typing-agent-evil--push-events
                             (with-current-buffer buffer
                               (typing-agent-evil--create-keys)))
                            (poll-until
                             #'typing-agent-evil--create-prompt-p
                             #'type-file-name
                             "新建文件提示没有出现"
                             pause)))))
                   (note "在 dired 里按新建空文件键")
                   (if (with-current-buffer buffer (typing-agent-evil-insert-p))
                       ;; ESC 和新建键分开送，否则会被当成 Meta 前缀。
                       (progn
                         (typing-agent-evil--push-events (vector 27))
                         (run-at-time 0.3 nil send))
                     (funcall send))))))))
      (cond
       ((file-exists-p file)
        (open-file)
        t)
       ;; 批处理里没有命令循环，注入的按键不会被执行。
       (noninteractive
        (typing-agent-evil--create-direct file callback)
        t)
       ;; 已经在 minibuffer 里，没法再弹 dired。
       ((or (minibufferp base) (active-minibuffer-window))
        (fail "当前在 minibuffer")
        t)
       (t
        (ignore-errors (make-directory dir t))
        ;; 用真实路径，避免 /tmp 与 /private/tmp 这类符号链接让 dired 定位失败。
        (run-at-time
         0 nil
         (lambda ()
           (when (alive-p)
             (let ((buffer (typing-agent-evil--create-show-dired dir)))
               (when (typing-agent-evil--dired-mode-p buffer)
                 (note (format "打开 dired 目录：%s" dir))
                 (run-at-time pause nil #'press-create-key))))))
        t)))))

(defun typing-agent-evil-visit-file (file &optional line already)
  "像人一样打开或切换到 FILE，并跳到 LINE。
先弹出 buffer/文件选择框，输入名字，再回车跳过去；FILE 已经显示在
当前窗口时只跳行，不打扰画面。ALREADY 表示调用前 buffer 是否已打开。"
  (let* ((file (expand-file-name file))
         (buffer (find-buffer-visiting file))
         (already (and already t))
         (window (selected-window))
         (base (window-buffer window)))
    (cond
     ;; 已经在当前窗口：只跳行。
     ((and already buffer (eq base buffer))
      (typing-agent-evil--visit-finish file line))
     ;; 在 minibuffer 里或明确要求直接打开。
     ((or (active-minibuffer-window) (eq typing-agent-visit-method 'direct))
      (typing-agent-evil--visit-direct file line))
     (t
      ;; 按键要落在用户正在看的 buffer 里，所以在这个 buffer 中查键位。
      (let* ((plan (with-current-buffer base
                     (typing-agent-evil--visit-plan file already)))
             (command (car-safe plan))
             (input (cadr plan))
             (keys (and command
                        (with-current-buffer base
                          (typing-agent-evil--command-keys command)))))
        (if keys
            (typing-agent-evil--visit-with-selector
             base keys (or input (file-name-nondirectory file)) file line)
          (typing-agent-evil--visit-direct file line)))))))

(provide 'typing-agent-evil)
;;; typing-agent-evil.el ends here
