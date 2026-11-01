;;; typing-agent-engine.el --- 编辑任务执行引擎 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 任务执行器。负责把结构化操作队列变成可见的 Evil 按键，
;; 并在任务前后做快照、校验、撤销和 buffer 局部配置的隔离。
;;
;; 执行模型：
;;   - 提交任务时同步检查文件与 buffer，异步开始执行；
;;   - 每个操作由定时器驱动，字符之间让出事件循环，保证画面可见；
;;   - type_text / backspace / insert_newline 是异步操作，其余操作是原子的；
;;   - 暂停只取消当前定时器，字符索引保存在任务的 op-state 里；
;;   - 失败、取消都不会自动保存。
;;
;; 操作列表见 `typing-agent-engine-operation-types'。

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'seq)
(require 'typing-agent)
(require 'typing-agent-completion)
(require 'typing-agent-evil)
(require 'typing-agent-humanizer)
(require 'typing-agent-lock)
(require 'typing-agent-validator)
(require 'typing-agent-recording)

(declare-function corfu-mode "corfu")
(defvar eglot--servers-by-project)
(defvar eglot--recent-changes)
(defvar eglot--docver)
(defvar eglot--managed-mode)
(declare-function eglot--before-change "eglot")
(declare-function eglot--after-change "eglot")
(declare-function eglot--signal-textDocument/didChange "eglot")
(declare-function eglot--maybe-activate-editing-mode "eglot")

;;; 执行期间的 buffer 局部保护

(defvar typing-agent-mode)
(defvar-local typing-agent--saved-minor-modes nil
  "任务开始前启用的 minor modes，形如 ((MODE . t) ...)。")
(defvar-local typing-agent--saved-overriding-map-alist nil
  "任务开始前的 `minor-mode-overriding-map-alist'。")
(defvar-local typing-agent--saved-auto-fill nil
  "任务开始前的 `auto-fill-function'。")
(defvar-local typing-agent--saved-auto-fill-local nil
  "任务开始前 `auto-fill-function' 是否是 buffer 局部变量。")
(defvar-local typing-agent--saved-electric-indent-inhibit nil
  "任务开始前的 `electric-indent-inhibit'。")
(defvar-local typing-agent--saved-electric-indent-local nil
  "任务开始前 `electric-indent-inhibit' 是否是 buffer 局部变量。")
(defvar-local typing-agent--saved-corfu-auto nil
  "任务开始前的 `corfu-auto'。")
(defvar-local typing-agent--saved-corfu-settings nil
  "任务前的 Corfu 设置，记录变量名、是否局部绑定和原值。")
(defvar-local typing-agent--saved-doom-word-count nil
  "任务开始前的 `doom-modeline-enable-word-count'（可能不存在）。")
(defvar-local typing-agent--saved-doom-word-count-local nil
  "任务开始前 `doom-modeline-enable-word-count' 是否已是 buffer 局部变量。")
(defvar-local typing-agent--saved-eglot-before-change nil
  "任务开始前 `eglot--before-change' 是否在 `before-change-functions' 里。")
(defvar-local typing-agent--saved-eglot-after-change nil
  "任务开始前 `eglot--after-change' 是否在 `after-change-functions' 里。")
(defvar-local typing-agent--eglot-hooks-quiesced nil
  "任务期间是否已经摘过 Eglot 的逐字符变更钩子。")

(defconst typing-agent--quiesced-minor-modes
  '(electric-indent-mode
    electric-pair-mode
    electric-pair-local-mode
    smartparens-mode
    smartparens-strict-mode
    yas-minor-mode
    abbrev-mode
    corfu-mode
    company-mode
    aggressive-indent-mode
    evil-cleverparens-mode
    flymake-mode
    flycheck-mode
    indent-bars-mode
    ws-butler-mode
    focus-mode)
  "执行任务期间临时关闭的 buffer 局部 minor modes。
关闭目的：防止自动配对、自动缩进、补全弹窗和 snippet 改变实际输入内容。
启用补全的任务会保留 `corfu-mode'，但用 buffer 局部的 `corfu-auto' = nil
关掉自动弹框，由补全状态机在需要时主动触发。")

(defvar typing-agent-mode-map
  (let ((map (make-sparse-keymap)))
    ;; 换行必须是纯粹的 newline，不能触发自动缩进。
    (define-key map [?\r] #'newline)
    ;; TAB 交给 Emacs 的缩进命令：Insert 下按 mode 的规则缩进，
    ;; 不是插入一个字面 Tab 字符。
    (define-key map [?\t] #'indent-for-tab-command)
    map)
  "Typing Agent 执行期间的按键覆盖表。
通过 `minor-mode-overriding-map-alist' 安装，优先级高于 Evil 的状态键位。" )

(defun typing-agent--avoid-popup-tip-padding ()
  "让 `flycheck-popup-tip' 在这个 buffer 里改用回显区显示诊断。
它用 popup.el 弹提示，而 popup.el 会在 buffer 末尾插入空行来撑出提示
所需的高度（`popup-create'），这些空行随后虽然会被删掉，但每次显示都会
让文件末尾短暂多出几行，任务结束时甚至会留在 buffer 里。改成回显区显示，
既不丢诊断，又不会碰文件内容。"
  (when (and (boundp 'flycheck-display-errors-function)
             (fboundp 'flycheck-popup-tip-show-popup)
             (eq flycheck-display-errors-function
                 #'flycheck-popup-tip-show-popup))
    (let ((fallback
           (or (and (boundp 'flycheck-popup-tip-old-display-function)
                    flycheck-popup-tip-old-display-function)
               (and (fboundp 'flycheck-display-error-messages)
                    #'flycheck-display-error-messages))))
      (when (functionp fallback)
        (setq-local flycheck-display-errors-function fallback)))))

(defun typing-agent--quiesce-eglot-hooks ()
  "摘掉 Eglot 的逐字符变更钩子，并记住原本是否启用。
任务期间补全只依赖 `eglot-completion-at-point'，每次触发补全前整份同步
一次文档即可；逐字符增量同步是「越打越慢」的主要来源。
任务开始时还没有 LSP 的话，等它途中连上后 `eglot-managed-mode-hook'
会再调一次这里：新出现的钩子照样摘掉，并把 saved 标成 t，任务结束时
恢复给用户后续编辑使用。"
  (when (and typing-agent--completion-active
             (fboundp 'eglot--before-change))
    (unless (local-variable-p 'typing-agent--eglot-hooks-quiesced)
      (setq-local typing-agent--eglot-hooks-quiesced t)
      (setq-local typing-agent--saved-eglot-before-change
                  (and (memq 'eglot--before-change before-change-functions) t))
      (setq-local typing-agent--saved-eglot-after-change
                  (and (memq 'eglot--after-change after-change-functions) t)))
    (when (memq 'eglot--before-change before-change-functions)
      (setq-local typing-agent--saved-eglot-before-change t)
      (remove-hook 'before-change-functions #'eglot--before-change t))
    (when (memq 'eglot--after-change after-change-functions)
      (setq-local typing-agent--saved-eglot-after-change t)
      (remove-hook 'after-change-functions #'eglot--after-change t))))

(defun typing-agent--eglot-arrived ()
  "任务期间 LSP 才连上时，补做逐字符钩子的摘除。"
  (when (bound-and-true-p typing-agent-mode)
    (typing-agent--quiesce-eglot-hooks)))

(defun typing-agent--quiesce-buffer ()
  "在当前 buffer 中关闭会干扰逐字符输入的局部行为。
保存原值，任务结束后由 `typing-agent--restore-buffer' 恢复。"
  (unless (local-variable-p 'typing-agent--saved-overriding-map-alist)
    (setq-local typing-agent--saved-overriding-map-alist
                minor-mode-overriding-map-alist)
    (setq-local minor-mode-overriding-map-alist
                (cons (cons 'typing-agent-mode typing-agent-mode-map)
                      minor-mode-overriding-map-alist))
    (setq typing-agent--saved-minor-modes nil)
    (dolist (mode typing-agent--quiesced-minor-modes)
      (when (and (boundp mode) (symbol-value mode)
                 (not (and typing-agent--completion-active
                           (eq mode 'corfu-mode))))
        (push (cons mode t) typing-agent--saved-minor-modes)
        (ignore-errors (funcall mode -1))))
    ;; 补全任务需要 corfu 的状态管理与按键映射；未开启时临时打开。
    (when (and typing-agent--completion-active
               (fboundp 'corfu-mode)
               (not (bound-and-true-p corfu-mode)))
      (setq-local typing-agent--enabled-corfu-mode t)
      (ignore-errors (corfu-mode 1)))
    ;; 保留 LSP：补全（含自动 import）依赖 Eglot 的 capf，任务期间不关闭。
    ;; 诊断类 minor mode（flymake/flycheck）已在上面的 quiesce 列表里关掉，
    ;; 所以 LSP 只服务于补全，不会因为诊断/语义高亮反复推迟定时器。
    (setq-local typing-agent--saved-auto-fill auto-fill-function)
    (setq typing-agent--saved-auto-fill-local
          (local-variable-p 'auto-fill-function))
    (setq-local auto-fill-function nil)
    (setq-local typing-agent--saved-electric-indent-inhibit
                electric-indent-inhibit)
    (setq typing-agent--saved-electric-indent-local
          (local-variable-p 'electric-indent-inhibit))
    (setq-local electric-indent-inhibit t)
    ;; `flycheck-popup-tip' 会往 buffer 末尾插空行撑提示高度，任务期间会污染
    ;; 文件内容；这个 buffer 里的诊断一律改走回显区。
    (typing-agent--avoid-popup-tip-padding)
    ;; 高亮仅供导航，禁止 Corfu 在下一次普通按键前隐式提交候选。
    ;; 保存局部绑定状态，成功、失败和取消均通过 restore 恢复。
    (setq typing-agent--saved-corfu-settings nil)
    (dolist (variable '(corfu-auto corfu-preview-current))
      (when (boundp variable)
        (push (list variable (local-variable-p variable) (symbol-value variable))
              typing-agent--saved-corfu-settings)
        (set (make-local-variable variable) nil)))
    ;; doom-modeline 的 word-count 段在 java-mode 等模式下每次 modeline 更新
    ;; 都 count-words 全文件遍历（O(n)），打字越久文件越大越慢。任务期间在
    ;; 这个 buffer 里临时关掉，结束恢复。
    (when (boundp 'doom-modeline-enable-word-count)
      (setq-local typing-agent--saved-doom-word-count
                  doom-modeline-enable-word-count)
      (setq typing-agent--saved-doom-word-count-local
            (local-variable-p 'doom-modeline-enable-word-count))
      (setq-local doom-modeline-enable-word-count nil))
    ;; eglot 的变更钩子每个字符都跑：before-change 做两次 O(n) 的
    ;; `line-number-at-pos' 行号换算，并把带 marker 的增量记录堆进
    ;; `eglot--recent-changes'；after-change 每个字符 cancel+重建一个 idle
    ;; timer，还会把增量变更喂给 jdtls 让它反复重解析。这些开销随文件变大/
    ;; 编辑次数变多而累积，是「越打越慢」的剩余来源之一。任务期间摘掉它们，
    ;; 改为补全触发前由 `typing-agent-engine--eglot-sync-now' 整份同步。
    (typing-agent--quiesce-eglot-hooks)
    ;; 任务开始时还没有 LSP 时，打字途中 server 才连上（例如预热超时后
    ;; JDT 才完成初始化）。等它 managed 后再摘一次逐字符钩子，避免后半段
    ;; 又回到每字符重解析的慢路径。
    (add-hook 'eglot-managed-mode-hook
              #'typing-agent--eglot-arrived nil t)
    (when (bound-and-true-p completion-in-region-mode)
      (ignore-errors (completion-in-region-mode -1)))
    ;; 补全词状态从零开始，避免上个任务残留 'has / 'none。
    (setq-local typing-agent--completion-word-state nil)))

(defun typing-agent--restore-buffer ()
  "恢复 `typing-agent--quiesce-buffer' 改动的 buffer 局部设置。"
  (when (local-variable-p 'typing-agent--saved-overriding-map-alist)
    (typing-agent-completion-quit)
    (setq-local minor-mode-overriding-map-alist
                typing-agent--saved-overriding-map-alist)
    (kill-local-variable 'typing-agent--saved-overriding-map-alist)
    (dolist (entry typing-agent--saved-minor-modes)
      (ignore-errors (funcall (car entry) 1)))
    (setq typing-agent--saved-minor-modes nil)
    (when typing-agent--enabled-corfu-mode
      (ignore-errors (corfu-mode -1))
      (kill-local-variable 'typing-agent--enabled-corfu-mode))
    (if typing-agent--saved-auto-fill-local
        (setq-local auto-fill-function typing-agent--saved-auto-fill)
      (kill-local-variable 'auto-fill-function))
    (kill-local-variable 'typing-agent--saved-auto-fill)
    (if typing-agent--saved-electric-indent-local
        (setq-local electric-indent-inhibit
                    typing-agent--saved-electric-indent-inhibit)
      (kill-local-variable 'electric-indent-inhibit))
    (kill-local-variable 'typing-agent--saved-electric-indent-inhibit)
    (dolist (setting typing-agent--saved-corfu-settings)
      (if (nth 1 setting)
          (set (make-local-variable (car setting)) (nth 2 setting))
        (kill-local-variable (car setting))))
    (kill-local-variable 'typing-agent--saved-corfu-settings)
    (when (local-variable-p 'typing-agent--saved-doom-word-count)
      (if typing-agent--saved-doom-word-count-local
          (setq-local doom-modeline-enable-word-count
                      typing-agent--saved-doom-word-count)
        (kill-local-variable 'doom-modeline-enable-word-count))
      (kill-local-variable 'typing-agent--saved-doom-word-count))
    ;; 恢复 eglot 变更钩子，并把最终内容整份同步回去，保证之后用户的补全/
    ;; 诊断基于最新文本，而不是任务期间那份摘了钩子的「脏」状态。
    (when typing-agent--saved-eglot-before-change
      (add-hook 'before-change-functions #'eglot--before-change nil t))
    (when typing-agent--saved-eglot-after-change
      (add-hook 'after-change-functions #'eglot--after-change nil t))
    (remove-hook 'eglot-managed-mode-hook #'typing-agent--eglot-arrived t)
    (kill-local-variable 'typing-agent--saved-eglot-before-change)
    (kill-local-variable 'typing-agent--saved-eglot-after-change)
    (kill-local-variable 'typing-agent--eglot-hooks-quiesced)
    (typing-agent-engine--eglot-sync-now)
    (kill-local-variable 'typing-agent--completion-active)))

(define-minor-mode typing-agent-mode
  "Typing Agent 任务执行期间的 buffer 局部保护模式。
只影响当前 buffer，结束后完全恢复原状。"
  :lighter " TA"
  :group 'typing-agent
  (if typing-agent-mode
      (typing-agent--quiesce-buffer)
    (typing-agent--restore-buffer)))

;;; 操作类型

(defconst typing-agent-engine-operation-types
  '("open_file"
    "goto_line"
    "search_text"
    "move_cursor"
    "enter_insert"
    "type_text"
    "backspace"
    "delete_text"
    "delete_lines"
    "insert_newline"
    "indent"
    "exit_insert"
    "replace_region"
    "save_buffer"
    "undo"
    "pause"
    "wait")
  "任务支持的全部操作类型。")

(defun typing-agent-engine--normalize-text (text)
  "把任务文本统一成 LF 换行。
JSON 里可能传入 CRLF，而 Emacs buffer 内部使用 LF。"
  (when (stringp text)
    (thread-last text
      (replace-regexp-in-string "\r\n" "\n")
      (replace-regexp-in-string "\r" "\n"))))

(defun typing-agent-engine--normalize-op (op)
  "校验并规范化单个操作 OP，返回新的 plist。"
  (let* ((type (typing-agent-plist-string op :type))
         (normalized (copy-sequence op)))
    (unless type
      (signal 'typing-agent-input-error (list "操作缺少 type")))
    (unless (member type typing-agent-engine-operation-types)
      (signal 'typing-agent-input-error
              (list (format "未知操作类型: %s" type))))
    (when (plist-member normalized :text)
      (setq normalized
            (plist-put normalized :text
                       (typing-agent-engine--normalize-text
                        (plist-get normalized :text)))))
    (when (plist-member normalized :replace)
      (setq normalized
            (plist-put normalized :replace
                       (typing-agent-engine--normalize-text
                        (plist-get normalized :replace)))))
    normalized))

(defun typing-agent-engine-parse-options (spec)
  "解析任务 SPEC 中的 options，返回 alist。"
  (let ((options (plist-get spec :options)))
    (list
     (cons :speed
           (let ((value (typing-agent-plist-number options :speed 1.0)))
             (if (> value 0) value 1.0)))
     (cons :allow_dirty
           (typing-agent-plist-boolean options :allow_dirty
                                       typing-agent-allow-dirty-buffer))
     (cons :save
           (typing-agent-plist-boolean options :save nil))
     (cons :recording
           (typing-agent-plist-boolean options :recording nil))
     (cons :completion
           (typing-agent-plist-boolean options :completion
                                       typing-agent-completion-enabled))
     (cons :post_delay
           (typing-agent-plist-number options :post_delay 1.5)))))

(defun typing-agent-engine--option (task key &optional default)
  "读取 TASK 的选项 KEY。"
  (let ((value (alist-get key (typing-agent-task-options task))))
    (if (or (null value) (eq value :false)) default value)))

;;; 任务提交

(defun typing-agent-engine--new-task (file buffer operations options
                                           expected requested-id)
  "创建任务结构。BUFFER 为 nil 表示目标文件尚未创建。"
  (typing-agent-task-create
   :id (or requested-id (typing-agent--new-task-id))
   :status typing-agent-status-pending
   :file file
   :buffer buffer
   :operations operations
   :index 0
   :op-state nil
   :options options
   :expected expected
   :snapshot (and (buffer-live-p buffer)
                  (with-current-buffer buffer
                    (buffer-substring-no-properties (point-min) (point-max))))
   :snapshot-sha (and (buffer-live-p buffer)
                      (typing-agent-buffer-sha256 buffer))
   :created-at (typing-agent--now)
   :logs nil
   :result nil))

(defun typing-agent-engine-submit (spec)
  "提交一个编辑任务。
SPEC 是 `typing-agent-json-parse' 解析出的 plist。返回
`typing-agent-task'。任务在后台定时器中执行，函数立即返回。
目标文件不存在时，先在 dired 里像人一样创建它，再开始编辑。"
  (let* ((file-arg (typing-agent-plist-string spec :file))
         (operations (typing-agent-plist-vector->list
                      (plist-get spec :operations)))
         (operations (and operations (append operations nil)))
         (options (typing-agent-engine-parse-options spec))
         (expected (plist-get spec :expected))
         (requested-id (typing-agent-plist-string spec :id)))
    (unless file-arg
      (signal 'typing-agent-input-error (list "任务缺少 file")))
    (unless (and operations (listp operations))
      (signal 'typing-agent-input-error
              (list "任务缺少非空 operations 数组")))
    (when (typing-agent-task-busy-p)
      (signal 'typing-agent-busy-error
              (list (format "已有任务正在执行: %s"
                            (typing-agent-task-id typing-agent--active-task)))))
    (when (and requested-id (typing-agent-task-get requested-id))
      (signal 'typing-agent-busy-error
              (list (format "任务 ID 已存在，拒绝重复执行: %s"
                            requested-id))))
    (let* ((file (expand-file-name file-arg))
           (operations (mapcar #'typing-agent-engine--normalize-op
                               operations)))
      (when (file-directory-p file)
        (signal 'typing-agent-input-error
                (list (format "目标路径是目录: %s" file))))
      (if (file-exists-p file)
          (let* ((buffer (typing-agent-engine--without-lsp
                          (lambda () (find-file-noselect file)))))
            (with-current-buffer buffer
              (when buffer-read-only
                (signal 'typing-agent-state-error
                        (list (format "buffer 是只读的: %s" (buffer-name)))))
              (unless (verify-visited-file-modtime buffer)
                (signal 'typing-agent-state-error
                        (list "buffer 与磁盘文件不一致，请先 revert-buffer")))
              (when (and (buffer-modified-p)
                         (not (alist-get :allow_dirty options)))
                (signal 'typing-agent-state-error
                        (list "目标 buffer 有未保存修改；请先保存，或用 options.allow_dirty 明确允许"))))
            (let ((settings (typing-agent-engine--new-task
                             file buffer operations options
                             expected requested-id)))
              (typing-agent-task-register settings)
              (typing-agent-task-log settings 'info
                                     "任务已创建：%d 个操作，文件 %s"
                                     (length operations) file)
              (run-at-time 0 nil #'typing-agent-engine--begin settings)
              settings))
        ;; 新文件：任务先占住执行权，再在 dired 中创建，创建完才开始编辑。
        (let ((settings (typing-agent-engine--new-task
                         file nil operations options expected requested-id)))
          (typing-agent-task-register settings)
          (typing-agent-task-log settings 'info
                                 "任务已创建：%d 个操作，新文件 %s"
                                 (length operations) file)
          (run-at-time 0 nil #'typing-agent-engine--create-and-begin settings)
          settings)))))

;;; 任务生命周期

(defun typing-agent-engine--call-in-task-buffer (task function)
  "在 TASK 的 buffer 中调用 FUNCTION。
定时器回调执行时 current buffer 未必是任务 buffer（可能是 minibuffer
或其他窗口），因此每个异步步骤都必须先切回任务 buffer。
FUNCTION 抛出的任何错误都转为任务失败：分行输入等异步状态机不经过
`typing-agent-engine--step' 的 condition-case，一旦抛错（例如行尾 ESC
失败）若不被这里接住，任务会永远停在 running、输入锁定无法释放、
watchdog 每 15 秒空转一次。"
  (let ((buffer (typing-agent-task-buffer task)))
    (cond
     ((not (buffer-live-p buffer))
      (typing-agent-engine--fail
       task
       (list 'typing-agent-state-error "目标 buffer 已关闭")))
     (t
      (condition-case err
          (with-current-buffer buffer
            (funcall function task))
        (error
         (typing-agent-engine--fail task err)))))))

(defun typing-agent-engine--schedule (task delay &optional function)
  "在 DELAY 秒后执行 FUNCTION（默认 `typing-agent-engine--step'）。
把定时器记录在 TASK 上，便于暂停和取消。
FUNCTION 总在 TASK 的 buffer 中执行。"
  (when (typing-agent-task-timer task)
    (cancel-timer (typing-agent-task-timer task)))
  (when (typing-agent-task-watchdog task)
    (cancel-timer (typing-agent-task-watchdog task)))
  (let* ((function (or function #'typing-agent-engine--step))
         (seconds (max 0 delay)))
    (setf (typing-agent-task-last-step-at task) (float-time))
    (setf (typing-agent-task-timer task)
          (run-at-time
           seconds nil
           (lambda (task)
             (typing-agent-engine--call-in-task-buffer task function))
           task))
    ;; 定时器链偶尔会被 quit 或第三方 hook 打断，任务永远停在 running。
    ;; 超过预期时间还没有下一步时重新驱动一次，避免整次演示卡死。
    (setf (typing-agent-task-watchdog task)
          (run-at-time
           (+ seconds 15) nil
           (lambda (task)
             (when (eq (typing-agent-task-status task)
                       typing-agent-status-running)
               (typing-agent-task-log
                task 'warn "任务 15 秒没有进展，重新驱动定时器")
               (typing-agent-engine--schedule task 0.05 function)))
           task))))

(defun typing-agent-engine--cancel-timer (task)
  "取消 TASK 当前定时器与 watchdog。
任务结束/失败/取消后必须把 watchdog 一并取消，否则残留的 watchdog
会在 15 秒后空转一次（虽然它检查状态不做事，但没必要留着）。"
  (when (typing-agent-task-timer task)
    (ignore-errors (cancel-timer (typing-agent-task-timer task)))
    (setf (typing-agent-task-timer task) nil))
  (when (typing-agent-task-watchdog task)
    (ignore-errors (cancel-timer (typing-agent-task-watchdog task)))
    (setf (typing-agent-task-watchdog task) nil)))

(defun typing-agent-engine--dismiss-transient-ui ()
  "收掉 minibuffer、补全弹框等临时界面，避免任务按键被它们吃掉。
任务开始时用户可能正停在文件选择框、搜索框或补全弹框里，此时直接开始
输入会让字符进入 minibuffer，表现为任务卡住或 Emacs 报 search-failed。"
  (when (active-minibuffer-window)
    (condition-case nil
        (with-selected-window (active-minibuffer-window)
          (abort-recursive-edit))
      (quit nil)
      (error nil)))
  (when (fboundp 'corfu-quit)
    (ignore-errors (corfu-quit)))
  (when (fboundp 'company-abort)
    (ignore-errors (company-abort)))
  (when (bound-and-true-p evil-ex-search)
    (when (fboundp 'evil-ex-search-abort)
      (ignore-errors (evil-ex-search-abort)))))

(defun typing-agent-engine--any-lsp-running-p ()
  "是否有任一 LSP server 正在运行。
只用于启发式判断：有 server 时尝试把 buffer 加入；没有时绝不启动。"
  (and (boundp 'eglot--servers-by-project)
       (hash-table-p eglot--servers-by-project)
       (> (hash-table-count eglot--servers-by-project) 0)))

(defun typing-agent-engine--without-lsp (function)
  "调用 FUNCTION；只在「没有任何 LSP 在运行」时阻止 `eglot-ensure' 启动。
JDT 建索引和下载依赖时会推迟 Emacs 的定时器，逐字符输入会卡成每步十几秒；
所以任务打开文件时绝不冷启动 LSP。但已有 server 在跑时不去拦 `eglot-ensure'，
让新打开的 buffer 正常加入项目，补全（含 import）才能用。"
  (if (and (fboundp 'eglot-ensure)
           (not (typing-agent-engine--any-lsp-running-p)))
      (let ((advice (lambda (&rest _) nil)))
        (advice-add 'eglot-ensure :override advice)
        (unwind-protect (funcall function)
          (advice-remove 'eglot-ensure advice)))
    (funcall function)))

(defun typing-agent-engine--lsp-ready-p ()
  "当前 buffer 是否已经连上并初始化完 Eglot server。"
  (and (fboundp 'eglot-current-server)
       (fboundp 'eglot-managed-p)
       (ignore-errors
         (and (eglot-current-server)
              (eglot-managed-p)))))

(defun typing-agent-engine--connect-lsp-now ()
  "在当前 buffer 立即发起 Eglot 接管，不依赖下一次交互命令。
已有项目 server 时补齐 managed-mode 和 didOpen；否则只执行
`eglot-ensure' 新注册的连接钩子，不运行用户的其他 post-command 钩子。"
  (if (and (eglot-current-server)
           (fboundp 'eglot--maybe-activate-editing-mode))
      (eglot--maybe-activate-editing-mode)
    (let ((post-command-hook nil))
      (eglot-ensure)
      (run-hooks 'post-command-hook))))

(defun typing-agent-engine--ensure-lsp (task)
  "确保当前 buffer 接入 Eglot，必要时冷启动并等待就绪。
项目里已有 server 时只把 buffer 加入；没有任何 server 且任务启用了补全、
`typing-agent-completion-prewarm-lsp' 非 nil 时，调用 `eglot-ensure' 冷启动，
最多等待 `typing-agent-completion-prewarm-timeout' 秒，超时照常开始打字。
`find-file-noselect' 打开文件时项目可能还没被识别（例如项目尚未 git init），
`eglot-ensure' 会静默失败；buffer 显示到窗口后再补一次连接。"
  (when (and (fboundp 'eglot-ensure)
             (fboundp 'eglot-current-server)
             (not (typing-agent-engine--lsp-ready-p)))
    (let* ((running (typing-agent-engine--any-lsp-running-p))
           (prewarm (and (bound-and-true-p typing-agent-completion-prewarm-lsp)
                         (typing-agent-engine--option task :completion t)))
           (timeout (cond (prewarm typing-agent-completion-prewarm-timeout)
                          (running 3.0)
                          (t 0))))
      (when (or running prewarm)
        (typing-agent-task-log
         task 'info "%s"
         (if running
             "检测到 LSP 在运行，把 buffer 加入项目"
           "LSP 未运行，冷启动并等待就绪"))
        (let ((started (float-time)))
          (unless running
            (message "typing-agent: 正在启动 LSP，最多等待 %s 秒…" timeout))
          (condition-case err
              (typing-agent-engine--connect-lsp-now)
            (error
             (typing-agent-task-log task 'warn "Eglot 接管失败：%s"
                                    (error-message-string err))))
          (let ((deadline (+ started timeout)))
            (while (and (not (typing-agent-engine--lsp-ready-p))
                        (< (float-time) deadline))
              (accept-process-output nil 0.1)
              (redisplay)))
          (unless running
            (message nil))
          (typing-agent-task-log
           task (if (typing-agent-engine--lsp-ready-p) 'info 'warn)
           "LSP %s（%.1f 秒）"
           (if (typing-agent-engine--lsp-ready-p)
               "已就绪"
             "未就绪，继续输入")
           (- (float-time) started)))
        (typing-agent-engine--eglot-sync-now)))))

;;;###autoload
(defun typing-agent-prewarm-lsp ()
  "为当前 buffer 拉起 Eglot 并等到就绪。
录制前手动执行一次，可以把 JDT 首次导入项目、建索引的等待放到正式任务之外；
已经连上时立即返回。"
  (interactive)
  (unless (buffer-file-name)
    (user-error "当前 buffer 没有关联文件"))
  (if (typing-agent-engine--lsp-ready-p)
      (message "typing-agent: LSP 已就绪")
    (let ((started (float-time)))
      (message "typing-agent: 正在启动 LSP，最多等待 %s 秒…"
               typing-agent-completion-prewarm-timeout)
      (typing-agent-engine--connect-lsp-now)
      (let ((deadline (+ started typing-agent-completion-prewarm-timeout)))
        (while (and (not (typing-agent-engine--lsp-ready-p))
                    (< (float-time) deadline))
          (accept-process-output nil 0.1)
          (redisplay)))
      (message "typing-agent: LSP %s（%.1f 秒）"
               (if (typing-agent-engine--lsp-ready-p) "已就绪" "未就绪")
               (- (float-time) started)))))

(defun typing-agent-engine--eglot-sync-now ()
  "把当前 buffer 的整份内容同步给 Eglot（full sync）。
任务期间 eglot 的 before/after-change 钩子被摘掉（见
`typing-agent--quiesce-buffer'），改为在补全触发前手动整份同步，这样补全
仍基于最新文本，而逐字符输入不再承担 eglot 的行号换算、增量记录堆积和
didChange 反复喂给 jdtls 的负担。full sync 只发生在补全触发点和任务结束，
远少于逐字符增量同步。"
  (when (and (fboundp 'eglot--signal-textDocument/didChange)
             (boundp 'eglot--managed-mode)
             eglot--managed-mode)
    (ignore-errors
      (when (boundp 'eglot--docver)
        (setq eglot--docver (1+ eglot--docver)))
      (setq eglot--recent-changes :emacs-messup)
      (eglot--signal-textDocument/didChange))))

(defun typing-agent-engine--focus-buffer (task buffer)
  "把 BUFFER 显示到用户眼前，并按需让它独占窗口。

任务开始前用户可能在别的窗口、甚至别的 frame；这里先把显示 BUFFER 的窗口
选中（没有就新建），再按 `typing-agent-maximize-window' 或任务选项
`:recording' 删除其他窗口，这样录制时只有一个全尺寸窗口。
TASK 为 nil 时只按 `typing-agent-maximize-window' 判断。"
  (let ((window (or (get-buffer-window buffer (selected-frame))
                    (get-buffer-window buffer t))))
    (cond
     ((null window)
      (switch-to-buffer buffer))
     ((eq (window-frame window) (selected-frame))
      (select-window window))
     (t
      ;; 文件已经在别的 frame 打开：把人切过去，而不是在当前 frame 再开一个。
      (select-frame-set-input-focus (window-frame window))
      (select-window window)))
    (when (or typing-agent-maximize-window
              (and task
                   (typing-agent-engine--option task :recording)))
      (condition-case err
          (unless (eq (selected-window) (frame-root-window))
            (delete-other-windows))
        (error
         (when task
           (typing-agent-task-log task 'warn "无法最大化窗口：%s"
                                  (error-message-string err))))))
    (with-selected-window (selected-window)
      (recenter))
    t))

(defun typing-agent-engine--start-typing (task buffer)
  "TASK 的 BUFFER 已经在眼前，准备输入并开始执行。"
  (condition-case err
      (progn
        ;; 先收掉搜索框、补全弹框等临时界面，再切到目标 buffer 敲键，
        ;; 否则按键会进入 minibuffer，任务卡住。
        (typing-agent-engine--dismiss-transient-ui)
        ;; 先找到文件并最大化窗口，再开始敲键。
        ;; 不保存任务开始前的窗口布局：任务结束就停在最后编辑/查看的 buffer。
        (typing-agent-engine--focus-buffer task buffer)
        (with-current-buffer buffer
          ;; 已有 LSP 时把 buffer 加入项目；新建文件时主动拉起 LSP 并等它
          ;; 就绪（见 `typing-agent-completion-prewarm-lsp'），否则这批
          ;; 新文件在录制过程中始终没有补全。
          (typing-agent-engine--ensure-lsp task)
          ;; 只要主模式支持就标记为“希望补全”；Eglot 是否就绪在每次
          ;; 补全检查时动态判断，预热超时后 server 中途就绪也能接上。
          (setq-local typing-agent--completion-active
                      (and typing-agent-completion-enabled
                           (alist-get :completion
                                      (typing-agent-task-options task))
                           (typing-agent-completion-wanted-p)))
          (typing-agent-mode 1)
          (when (typing-agent-engine--option task :recording)
            (typing-agent-recording-prepare-current))
          (undo-boundary))
        ;; visit/create 阶段的受信事件计数到此为止，之后打字全部走
        ;; `execute-kbd-macro'（executing-kbd-macro 放行），清空残留。
        (setq typing-agent--inject-count 0)
        (typing-agent-humanizer-reset
         (typing-agent-engine--option task :speed 1.0))
        (typing-agent-task-log task 'info "开始执行")
        ;; 刚进入 buffer 先像人一样看一眼，再开始敲第一行。
        (typing-agent-engine--schedule
         task (typing-agent-humanizer--random-range
               typing-agent-buffer-enter-pause)))
    (error
     (typing-agent-engine--fail task err))))

(defun typing-agent-engine--begin-after-visit (task buffer)
  "先像人一样切到 TASK 的 BUFFER，再开始执行。
跳转本身由 `typing-agent-evil-visit-file' 弹出选择框、输入名字、回车完成。"
  (let ((file (typing-agent-task-file task))
        (deadline (+ (float-time) 10.0)))
    (typing-agent-evil-visit-file
     file nil (and (find-buffer-visiting file) t))
    (cl-labels
        ((check ()
           (cond
            ((eq (window-buffer (selected-window)) buffer)
             (typing-agent-engine--start-typing task buffer))
            ((>= (float-time) deadline)
             (typing-agent-task-log task 'warn "跳转等待超时，收掉弹框后直接开始")
             ;; 让还在等待的选择框流程作废，避免它稍后继续注入按键。
             (when (boundp 'typing-agent-evil--visit-token)
               (cl-incf typing-agent-evil--visit-token))
             ;; 收弹框可能产生 `quit'（C-g 的 signal），必须连 quit 一起
             ;; 吞掉，否则后面的 start-typing 不会执行，任务停在 running。
             (condition-case err
                 (progn
                   (typing-agent-engine--dismiss-transient-ui)
                   (typing-agent-evil--visit-direct file nil))
               (quit nil)
               (error
                (typing-agent-task-log
                 task 'warn "直接打开失败：%s" (error-message-string err))))
             (typing-agent-engine--start-typing task buffer))
            (t
             (run-at-time 0.1 nil #'check)))))
      (run-at-time 0.1 nil #'check))))

(defun typing-agent-engine--begin (task &optional started)
  "开始执行 TASK。
STARTED 非 nil 表示调用前任务已经占用执行权（例如刚在 dired 中建好文件），
此时不再重复检查忙碌状态。目标是已存在的文件、且它还没显示在眼前时，
先像人一样弹选择框跳过去，再开始输入。"
  (unless started
    (when (typing-agent-task-busy-p)
      (typing-agent-engine--fail
       task
       (list 'typing-agent-busy-error "已有任务正在执行")))
    (setf (typing-agent-task-status task) typing-agent-status-running)
    (setf (typing-agent-task-started-at task) (typing-agent--now))
    (setq typing-agent--active-task task))
  (typing-agent-lock-on)
  (let ((buffer (typing-agent-task-buffer task)))
    (cond
     ((not (buffer-live-p buffer))
      (typing-agent-engine--fail
       task (list 'typing-agent-state-error "目标 buffer 已关闭")))
     ;; 批处理里没有命令循环；文件已经显示时直接开始。
     ;; 卡在 minibuffer 里时不走文件选择流程，交给 `--start-typing' 先收掉它。
     ((or noninteractive
          (eq (window-buffer (selected-window)) buffer)
          (not (fboundp 'typing-agent-evil-visit-file)))
      (typing-agent-engine--start-typing task buffer))
     (t
      (typing-agent-engine--begin-after-visit task buffer)))))

(defun typing-agent-engine--create-and-begin (task)
  "在 dired 中像人一样创建 TASK 的目标文件，创建完再开始执行。
创建期间任务已是 running 并占用执行权，其他任务会被拒绝。"
  (when (eq (typing-agent-task-status task) typing-agent-status-pending)
    (setf (typing-agent-task-status task) typing-agent-status-running)
    (setf (typing-agent-task-started-at task) (typing-agent--now))
    (setq typing-agent--active-task task)
    (typing-agent-lock-on)
    (typing-agent-task-log task 'info "目标文件不存在：在 dired 中创建")
    (condition-case err
        (typing-agent-evil-create-file
         (typing-agent-task-file task)
         (lambda (buffer) (typing-agent-engine--created task buffer))
         (lambda () (eq (typing-agent-task-status task)
                        typing-agent-status-running))
         (lambda (level message)
           (typing-agent-task-log task level "%s" message)))
      (error
       (typing-agent-engine--fail task err)))))

(defun typing-agent-engine--created (task buffer)
  "TASK 的目标文件已经创建并打开，校验 BUFFER 后开始执行。"
  (when (eq (typing-agent-task-status task) typing-agent-status-running)
    (condition-case err
        (let ((file (typing-agent-task-file task))
              (buffer (or (and (buffer-live-p buffer) buffer)
                          (find-file-noselect (typing-agent-task-file task)))))
          (unless (file-exists-p file)
            (signal 'typing-agent-state-error (list "文件创建后仍不存在")))
          (with-current-buffer buffer
            (when buffer-read-only
              (signal 'typing-agent-state-error
                      (list (format "buffer 是只读的: %s" (buffer-name)))))
            (when (and (buffer-modified-p)
                       (not (alist-get :allow_dirty
                                       (typing-agent-task-options task))))
              (signal 'typing-agent-state-error
                      (list "新建的 buffer 有未保存修改，请先保存"))))
          (setf (typing-agent-task-buffer task) buffer)
          (setf (typing-agent-task-snapshot task)
                (with-current-buffer buffer
                  (buffer-substring-no-properties (point-min) (point-max))))
          (setf (typing-agent-task-snapshot-sha task)
                (typing-agent-buffer-sha256 buffer))
          (typing-agent-task-log task 'info "文件已创建：%s" file)
          (typing-agent-engine--begin task t))
      (error
       (typing-agent-engine--fail task err)))))

(defun typing-agent-engine--step (task)
  "执行 TASK 的下一个操作。"
  (setf (typing-agent-task-timer task) nil)
  (when (eq (typing-agent-task-status task) typing-agent-status-running)
    (let* ((operations (typing-agent-task-operations task))
           (index (typing-agent-task-index task))
           (total (length operations)))
      (if (>= index total)
          (typing-agent-engine--finish task)
        (let ((op (nth index operations)))
          (condition-case err
              (let ((result (typing-agent-engine--execute-op task op)))
                (pcase result
                  (:done
                   (setf (typing-agent-task-index task) (1+ index))
                   (typing-agent-engine--schedule task 0.02))
                  (:async
                   ;; 异步操作自己负责调度下一步。
                   nil)))
            (error
             (typing-agent-engine--fail task err))))))))

(defun typing-agent-engine--op-summary (op)
  "返回操作的简短日志描述。"
  (let ((type (typing-agent-plist-string op :type)))
    (format "%s%s"
            type
            (let ((text (or (typing-agent-plist-string op :text)
                            (typing-agent-plist-string op :replace)
                            (typing-agent-plist-string op :search))))
              (if text
                  (format "(%d 字符: %s)"
                          (length text)
                          (substring text 0 (min 40 (length text))))
                "")))))

(defun typing-agent-engine--execute-op (task op)
  "执行任务 TASK 的 OP。返回 :done 或 :async。"
  (let* ((type (typing-agent-plist-string op :type))
         (index (typing-agent-task-index task))
         (total (length (typing-agent-task-operations task))))
    (typing-agent-task-log task 'info "操作 %d/%d: %s"
                           (1+ index) total
                           (typing-agent-engine--op-summary op))
    (pcase type
      ("open_file"
       (typing-agent-engine--op-open-file task op))
      ("goto_line"
       (let ((line (typing-agent-plist-integer op :line)))
         (unless line
           (signal 'typing-agent-input-error (list "goto_line 缺少 line")))
         (typing-agent-evil-goto-line line))
       :done)
      ("search_text"
       (let ((text (typing-agent-plist-string op :text)))
         (unless text
           (signal 'typing-agent-input-error (list "search_text 缺少 text")))
         (typing-agent-evil-search-text
          text
          (typing-agent-plist-integer op :occurrence)
          (typing-agent-plist-boolean op :unique t))
         :done))
      ("move_cursor"
       (let ((position (typing-agent-plist-string op :position)))
         (unless position
           (signal 'typing-agent-input-error
                   (list "move_cursor 缺少 position")))
         (typing-agent-evil-move-cursor
          position (or (typing-agent-plist-integer op :count) 1)))
       :done)
      ("enter_insert"
       (typing-agent-evil-enter-insert
        (or (typing-agent-plist-string op :command) "i"))
       :done)
      ("type_text"
       (typing-agent-engine--op-type-text task op))
      ("replace_region"
       (typing-agent-engine--op-replace-region task op))
      ("backspace"
       (typing-agent-engine--op-backspace task op))
      ("delete_text"
       (typing-agent-engine--op-delete-text task op))
      ("delete_lines"
       (typing-agent-evil-delete-lines
        (or (typing-agent-plist-integer op :count) 1))
       :done)
      ("insert_newline"
       (typing-agent-engine--op-insert-newline task op))
      ("indent"
       (typing-agent-evil-indent
        (or (typing-agent-plist-integer op :lines) 1))
       :done)
      ("exit_insert"
       (typing-agent-evil-exit-insert)
       (typing-agent-task-log task 'info "已退出 Insert 模式")
       :done)
      ("save_buffer"
       (typing-agent-engine--save-buffer task)
       :done)
      ("undo"
       (typing-agent-evil-undo
        (or (typing-agent-plist-integer op :count) 1))
       :done)
      ("pause"
       (typing-agent-engine--op-wait task
                                     (/ (or (typing-agent-plist-integer op :ms) 800)
                                        1000.0)))
      ("wait"
       (typing-agent-engine--op-wait task
                                     (/ (or (typing-agent-plist-integer op :ms) 800)
                                        1000.0)))
      (_
       (signal 'typing-agent-input-error
               (list (format "未实现的操作: %s" type)))))))

(defun typing-agent-engine--op-open-file (task op)
  "打开任务指定的文件。
第一版只允许操作任务顶层 file，避免多文件任务在未校验的情况下切换目标。"
  (let* ((path (typing-agent-plist-string op :path))
         (file (and path (expand-file-name path))))
    (unless file
      (signal 'typing-agent-input-error (list "open_file 缺少 path")))
    (unless (string= file (typing-agent-task-file task))
      (signal 'typing-agent-input-error
              (list (format "第一版只支持单文件任务，禁止切换到 %s" file))))
    (typing-agent-engine--focus-buffer task (typing-agent-task-buffer task))
    :done))

(defun typing-agent-engine--op-type-text (task op)
  "开始逐字符输入 TEXT。
含换行时按行输入：每行结束回 Normal，用 `o' 开新行再进 Insert。
每行的前导空白交给 TAB / 缩进命令，不逐字敲空格。"
  (let ((text (plist-get op :text)))
    (unless (stringp text)
      (signal 'typing-agent-input-error (list "type_text 缺少 text")))
    (unless (typing-agent-evil-insert-p)
      (signal 'typing-agent-state-error
              (list (format "type_text 要求 Insert 状态，当前为 %s"
                            (typing-agent-evil-state-name)))))
    (if (string-empty-p text)
        :done
      (typing-agent-engine--start-lines
       task
       (typing-agent-engine--split-lines text)
       t nil (copy-marker (point)) text nil)
      :async)))

(defun typing-agent-engine--op-replace-region (task op)
  "把 SEARCH 文本替换成 REPLACE 文本。
整行区域先 `dd' 删除，再用 `O'/`o' 开新行逐行输入；行内替换用 Visual
删除后 `i' 进入 Insert。"
  (let ((search (typing-agent-plist-string op :search))
        (replace (plist-get op :replace)))
    (unless search
      (signal 'typing-agent-input-error (list "replace_region 缺少 search")))
    (unless (stringp replace)
      (signal 'typing-agent-input-error (list "replace_region 缺少 replace")))
    (typing-agent-evil-require-normal "replace_region")
    (let* ((pos (typing-agent-evil-locate
                 search
                 (typing-agent-plist-integer op :occurrence)
                 (typing-agent-plist-boolean op :unique t)))
           (end (+ pos (length search)))
           (whole-line (typing-agent-evil--whole-line-region-p pos end)))
      (cond
       ;; 整行替换：dd 删除，再用 O/o 一行行写回去。
       ((and whole-line (not (string-empty-p replace)))
        (let* ((terminator (or (string-suffix-p "\n" search)
                               (< end (point-max))))
               (body (if (string-suffix-p "\n" replace)
                         (substring replace 0 -1)
                       replace))
               (lines (typing-agent-engine--split-lines body))
               (expected (concat (mapconcat #'identity lines "\n")
                                 (if terminator "\n" "")))
               ;; 行数必须在删除前算好：dd 之后 END 已越界。
               (count (max 1 (count-lines pos end))))
          (goto-char pos)
          (typing-agent-evil-delete-lines count)
          (typing-agent-task-log task 'info "dd 删除 %d 行" count)
          (typing-agent-engine--start-lines
           task lines t t (copy-marker pos) expected "O"))
        :async)

       ;; 只删除：dd 就够了。
       ((and whole-line (string-empty-p replace))
        (goto-char pos)
        (typing-agent-evil-delete-lines (max 1 (count-lines pos end)))
        (typing-agent-task-log task 'info "replace_region 只删除，不输入新内容")
        :done)

       ;; 行内替换：Visual 删除后 i 进入 Insert。
       (t
        (goto-char pos)
        (typing-agent-evil-delete-region pos end)
        (if (string-empty-p replace)
            (progn
              (typing-agent-task-log task 'info "replace_region 只删除，不输入新内容")
              :done)
          (progn
            (typing-agent-evil-enter-insert "i")
            (typing-agent-engine--start-lines
             task (typing-agent-engine--split-lines replace)
             t t (copy-marker (point)) replace nil)
            :async)))))))

(defun typing-agent-engine--op-backspace (task op)
  "在 Insert 状态下删除前一个字符。"
  (unless (typing-agent-evil-insert-p)
    (signal 'typing-agent-state-error
            (list (format "backspace 要求 Insert 状态，当前为 %s"
                          (typing-agent-evil-state-name)))))
  (let ((count (or (typing-agent-plist-integer op :count) 1)))
    (when (<= (point) (point-min))
      (signal 'typing-agent-state-error (list "光标已在 buffer 开头，无法退格")))
    (typing-agent-engine--start-repeat-key
     task (max 1 count) (vector 127)
     (typing-agent-humanizer--random-range '(0.05 . 0.14)))
    :async))

(defun typing-agent-engine--op-insert-newline (task op)
  "在 Insert 状态下插入 COUNT 个换行。
行尾时用 ESC + `o' 完成（体现 Normal/Insert 切换），行中仍用 RET。"
  (unless (typing-agent-evil-insert-p)
    (signal 'typing-agent-state-error
            (list (format "insert_newline 要求 Insert 状态，当前为 %s"
                          (typing-agent-evil-state-name)))))
  (let ((count (or (typing-agent-plist-integer op :count) 1)))
    (setf (typing-agent-task-op-state task)
          (list :kind 'newlines
                :remaining (max 1 count)
                :just-opened nil
                :delay (typing-agent-humanizer--random-range
                        typing-agent-newline-pause)))
    (typing-agent-engine--newline-next task)
    :async))

(defun typing-agent-engine--newline-next (task)
  "插入换行状态机的下一步。
行尾的第一次换行用 ESC + `o'（中间和之后都有停顿），同一位置继续
换行则用 RET，避免多开出空行。"
  (when (eq (typing-agent-task-status task) typing-agent-status-running)
    (let* ((state (typing-agent-task-op-state task))
           (remaining (plist-get state :remaining))
           (phase (plist-get state :phase)))
      (cond
       ((<= remaining 0)
        (setf (typing-agent-task-op-state task) nil)
        (setf (typing-agent-task-index task)
              (1+ (typing-agent-task-index task)))
        (typing-agent-engine--schedule task 0.04))

       ;; ESC 之后停一下，再按 o 开新行。
       ((eq phase 'open)
        (let ((pause (typing-agent-humanizer--random-range
                      typing-agent-next-line-pause)))
          (typing-agent-evil-enter-insert "o")
          (setf (plist-get state :phase) nil)
          (setf (plist-get state :just-opened) t)
          (setf (plist-get state :remaining) (1- remaining))
          (setf (typing-agent-task-op-state task) state)
          (typing-agent-task-log task 'info "o 开新行，停 %.2f 秒" pause)
          (typing-agent-engine--schedule
           task pause #'typing-agent-engine--newline-next)))

       ;; 行尾：ESC 回 Normal，停顿后再按 o。
       ((and (not (plist-get state :just-opened)) (eolp))
        (typing-agent-evil-exit-insert)
        (setf (plist-get state :phase) 'open)
        (setf (typing-agent-task-op-state task) state)
        (typing-agent-task-log task 'info "插入换行：ESC 回 Normal")
        (typing-agent-engine--schedule
         task (typing-agent-humanizer--random-range
               typing-agent-line-break-pause)
         #'typing-agent-engine--newline-next))

       ;; 行中或刚开过新行：直接 RET。
       (t
        (typing-agent-evil--execute-keys (vector ?\r))
        (setf (plist-get state :just-opened) nil)
        (setf (plist-get state :remaining) (1- remaining))
        (setf (typing-agent-task-op-state task) state)
        (typing-agent-engine--schedule
         task (or (plist-get state :delay) 0.08)
         #'typing-agent-engine--newline-next))))))

(defun typing-agent-engine--op-delete-text (task op)
  "删除文本。
支持 text（先唯一定位）、lines（从当前行起）或 count（从光标起）。"
  (let ((text (typing-agent-plist-string op :text))
        (lines (typing-agent-plist-integer op :lines))
        (count (typing-agent-plist-integer op :count)))
    (cond
     (text
      (typing-agent-evil-delete-match
       text (typing-agent-plist-integer op :occurrence))
      (typing-agent-task-log task 'info "已删除定位到的文本（%d 字符）"
                             (length text))
      :done)
     ((and lines (> lines 0))
      (typing-agent-evil-delete-lines lines)
      (typing-agent-task-log task 'info "已删除 %d 行" lines)
      :done)
     ((and count (> count 0))
      (typing-agent-evil-require-normal "delete_text")
      (let* ((beg (point))
             (end (min (point-max) (+ beg count))))
        (when (>= beg end)
          (signal 'typing-agent-state-error (list "光标后没有可删除的文本")))
        (typing-agent-evil-delete-region beg end)
        (typing-agent-task-log task 'info "已删除 %d 个字符" (- end beg))
        :done))
     (t
      (signal 'typing-agent-input-error
              (list "delete_text 需要 text、lines 或 count"))))))

(defun typing-agent-engine--op-wait (task seconds)
  "等待 SECONDS 秒后继续。用于任务内的思考停顿。"
  (setf (typing-agent-task-op-state task)
        (list :kind 'wait))
  (typing-agent-engine--schedule
   task seconds
   (lambda (task)
     (setf (typing-agent-task-timer task) nil)
     (setf (typing-agent-task-op-state task) nil)
     (setf (typing-agent-task-index task)
           (1+ (typing-agent-task-index task)))
     (typing-agent-engine--schedule task 0.02)))
  :async)

;;; 缩进

(defun typing-agent-engine--line-indent (line)
  "返回 LINE 的前导空白字符串。"
  (if (string-match "\\`[ \t]*" line)
      (match-string 0 line)
    ""))

(defun typing-agent-engine--indent-column (indent)
  "返回 INDENT 在当前 buffer 中渲染后的列号（考虑 tab）。"
  (let ((column 0)
        (width (if (and (integerp tab-width) (> tab-width 0)) tab-width 8)))
    (dolist (char (string-to-list indent) column)
      (if (= char ?\t)
          (setq column (* width (1+ (/ column width))))
        (setq column (1+ column))))))

(defun typing-agent-engine--at-line-start-p ()
  "判断 point 与行首之间是否只有空白。"
  (save-excursion
    (skip-chars-backward " \t" (line-beginning-position))
    (bolp)))

(defun typing-agent-engine--apply-line-indent (task indent)
  "在 Insert 状态下把当前行缩进到 INDENT。
先用 TAB（`indent-for-tab-command'）让主模式自己缩进，再用空格/退格
校正到精确列；若主模式给出的空白与 INDENT 不一致（tab 与空格的差异），
改成完全一致，保证落盘内容与预期一致。"
  (when (> (length indent) 0)
    (let ((target (typing-agent-engine--indent-column indent))
          (guard 0)
          (limit 24))
      ;; 行首已有空白时先清掉，避免叠加。
      (let ((existing (buffer-substring-no-properties
                       (line-beginning-position) (point))))
        (when (and (not (string-empty-p existing))
                   (string-match-p "\\`[ \t]*\\'" existing))
          (delete-region (line-beginning-position) (point))))
      ;; 让主模式用 TAB 自己缩进到目标列附近。
      (while (and (< (current-column) target) (< guard limit))
        (let ((before (current-column)))
          (typing-agent-evil--execute-keys (kbd "TAB"))
          (setq guard (1+ guard))
          (when (<= (current-column) before)
            (setq guard limit))))
      (typing-agent-task-log task 'info "TAB 缩进：第 %d 列（目标 %d 列）"
                             (current-column) target)
      ;; 用空格 / 退格把列号校正到精确位置。
      (cond
       ((> (current-column) target)
        (dotimes (_ (- (current-column) target))
          (typing-agent-evil--execute-keys (vector 127))))
       ((< (current-column) target)
        ;; 行首要补 N 个空格：退出 Insert 回 Normal，用 Evil 的计数前缀
        ;; `N a <SPC> <ESC>'（append）一次插入 N 个空格，而不是 dotimes
        ;; 一个个 self-insert，既快又不会越打越慢。这里用 `a' 而非 `i'：
        ;; TAB 已把行缩进到接近目标列，光标停在已有缩进的最后一个字符上，
        ;; `a' 才把空格追加到缩进末尾；`i' 在光标前插入，会把空格插进已有
        ;; 缩进中间，末尾多出一个空格。换行后行首本就为空时二者等价。
        (let ((n (- target (current-column))))
          (typing-agent-task-log task 'debug "行首补 %d 个空格（%d a <SPC> <ESC>）" n n)
          (typing-agent-evil-exit-insert)
          (typing-agent-evil-send-keys (format "%d a <SPC> <escape>" n))
          (typing-agent-evil-enter-insert "a"))))
      ;; tab / 空格的写法必须与预期逐字符一致。
      (let ((actual (buffer-substring-no-properties
                     (line-beginning-position) (point))))
        (unless (string= actual indent)
          (typing-agent-task-log
           task 'debug "TAB 缩进为 %S，按预期改为 %S" actual indent)
          (delete-region (line-beginning-position) (point))
          (insert indent))))))

(defun typing-agent-engine--split-lines (text)
  "按换行把 TEXT 拆成行列表，保留末尾空行。"
  (let ((lines nil)
        (start 0))
    (while (string-match "\n" text start)
      (push (substring text start (match-beginning 0)) lines)
      (setq start (match-end 0)))
    (push (substring text start) lines)
    (nreverse lines)))

;;; 分行输入（Normal <-> Insert）

(defcustom typing-agent-import-inline t
  "任务里出现的 import 行是否一次性整行写入，而不是逐字符敲。
Java `import ...`、Go `import ...` 这类行是 IDE/补全自动补的，不是人敲
出来的；开启后这些行直接 insert 整行（不镜像 KeyCastr），又快又自然。
设为 nil 时退回逐字符输入，保持完全一致的打字演示。"
  :type 'boolean
  :group 'typing-agent)

(defun typing-agent-engine--import-line-p (line)
  "LINE 是否是需要一次性写入的 import 行。
匹配 Java `import ...`、`import static ...`，以及 Go `import ...` /
`import (...)`。行首允许有空白。"
  (and (stringp line)
       (string-match-p "\\`[ \t]*import\\([ \t(]\\|$\\)" line)))

(defun typing-agent-engine--insert-import-line (task line skip)
  "在 Insert 状态下一次性插入 import 行 LINE（跳过前 SKIP 个缩进字符）。
缩进已经在 `--lines-next' 的 open 阶段用 TAB 写好，这里只插入剩余正文。
import 不是真实按键，不镜像到 KeyCastr。"
  (typing-agent-task-log task 'info "import 行：一次性写入 %S" line)
  (insert (substring line skip)))

(defun typing-agent-engine--start-lines (task lines indent-p auto-exit start expected open)
  "开始按行输入 LINES。
INDENT-P 非空时每行的前导空白用 TAB 完成；AUTO-EXIT 非空时最后一行后回
Normal。START 是校验起点，EXPECTED 是应写入 buffer 的内容；OPEN 是首行
进入 Insert 的命令（\"O\"/\"o\"，nil 表示已经在 Insert）。"
  (setf (typing-agent-task-op-state task)
        (list :kind 'lines
              :lines lines
              :index 0
              :char-index 0
              :phase 'open
              :open open
              :indent-p indent-p
              :auto-exit auto-exit
              :start (copy-marker start)
              :expected expected
              :speed (typing-agent-engine--option task :speed 1.0)))
  (typing-agent-engine--lines-next task))

;;; 补全

(defvar-local typing-agent--completion-word-state nil
  "当前标识符（词）的补全状态。
nil 表示尚未检查；`has' 表示这个词已有候选、后续字符继续追踪唯一化；
`none' 表示这个词确认无候选、后续字符退避不再白等 LSP。
点号或词首开始新词时会重新检查并更新这个值。")

(defun typing-agent-engine--completion-word-eligible-p (line char-index char)
  "根据「词状态」判断是否值得为 CHAR 再查一次补全。
点号和词首总是检查（开始/刷新一个词）；非词首只在「本词已知有候选」
时继续追踪，否则退避，避免无候选时每个字符都白等一次 LSP 响应。"
  (cond
   ((eq char ?.) t)
   ((and (typing-agent-completion-word-start-p line char-index char)
         (not (and (> char-index 1)
                   (eq (aref line (- char-index 2)) ?.)))) t)
   (t (eq typing-agent--completion-word-state 'has))))

(defun typing-agent-engine--completion-start-p (line char-index char)
  "刚在 LINE 的 CHAR-INDEX 处输入 CHAR 后，是否开始一次补全检查。
先做纯字符判断（触发位置 + 词状态退避），不满足就直接短路，避免每个
字符都跑一次 `syntax-ppss'；通过后才检查是否在字符串/注释里。"
  (and typing-agent--completion-active
       ;; Eglot 可能在任务中途才就绪（预热超时后 JDT 继续初始化），
       ;; 每个检查点重新判断，server 一到位补全就接着用。
       (typing-agent-completion-applicable-p)
       (typing-agent-evil-insert-p)
       (typing-agent-completion-check-position-p line char-index char)
       (typing-agent-engine--completion-word-eligible-p line char-index char)
       (typing-agent-completion-insert-context-p)))

(defun typing-agent-engine--completion-done (task state &optional char-index)
  "结束补全检查，回到逐字符输入。
CHAR-INDEX 非 nil 时，用它替换 STATE 里的字符索引（选中候选后的新位置）。"
  (when char-index
    (setf (plist-get state :char-index) char-index))
  (setf (plist-get state :phase) 'type)
  (setf (plist-get state :completion-tries) 0)
  (setf (typing-agent-task-op-state task) state)
  (typing-agent-engine--schedule task 0.05 #'typing-agent-engine--lines-next))

(defun typing-agent-engine--completion-next (task)
  "补全状态机：先让弹框出现，再读取候选并决定是否选中。"
  (when (eq (typing-agent-task-status task) typing-agent-status-running)
    (let* ((state (typing-agent-task-op-state task))
           (phase (plist-get state :phase))
           (tries (or (plist-get state :completion-tries) 0))
           (line (nth (plist-get state :index) (plist-get state :lines))))
      (pcase phase
        ('completion-show
         (let ((popup (typing-agent-completion-popup-p)))
           ;; 始终触发：首次让弹框出现，后续让 corfu 重新 complete 刷新候选。
           ;; 只在弹框没开时才 trigger 的话，「有候选」的词追踪时读到的永远是
           ;; 旧候选，候选永远无法唯一化，也就永远选不中。
           (typing-agent-completion-trigger)
           (setf (plist-get state :completion-tries)
                 (if popup tries (1+ tries)))
           (setf (plist-get state :phase) 'completion-check)
           (setf (typing-agent-task-op-state task) state)
           (typing-agent-engine--schedule
            task (if (typing-agent-completion-popup-p)
                     typing-agent-completion-popup-pause
                   typing-agent-completion-retry-delay)
            #'typing-agent-engine--completion-next)))

        ('completion-check
         (if (typing-agent-completion-popup-p)
             (let ((result (typing-agent-completion-inspect line)))
                (pcase (plist-get result :status)
                  ('navigating
                   (typing-agent-engine--schedule
                    task typing-agent-completion-selection-pause
                    #'typing-agent-engine--completion-next))
                  ('selected
                  ;; 这个词通过补全完成，词状态清零，等下一个词首再判。
                  (setq typing-agent--completion-word-state nil)
                  (typing-agent-task-log
                   task 'info "补全：选择目标候选 %S，字符索引 %d -> %d"
                   (plist-get result :text)
                   (plist-get state :char-index)
                   (plist-get result :char-index))
                  (typing-agent-engine--completion-done
                   task state (plist-get result :char-index)))
                 ('multiple
                  ;; 有候选但还不唯一，继续输入追踪。
                  (setq typing-agent--completion-word-state 'has)
                  (typing-agent-task-log
                   task 'debug "补全：%d 个候选，继续输入"
                   (plist-get result :count))
                  (typing-agent-engine--completion-done task state))
                 ('rejected
                  ;; 无匹配候选：收起弹框，本词剩余字符不再等待。
                  (setq typing-agent--completion-word-state 'none)
                  (typing-agent-completion-quit)
                  (typing-agent-task-log
                   task 'debug "补全：候选 %S 与目标不匹配，继续输入"
                   (plist-get result :text))
                  (typing-agent-engine--completion-done task state))
                 (_
                  (typing-agent-engine--completion-done task state))))
           (if (< tries typing-agent-completion-max-retries)
               (progn
                 (setf (plist-get state :phase) 'completion-show)
                 (setf (typing-agent-task-op-state task) state)
                 (typing-agent-engine--schedule
                  task typing-agent-completion-retry-delay
                  #'typing-agent-engine--completion-next))
             ;; 重试耗尽仍无弹框：这个词没有候选，标记退避，本词不再白等。
             (setq typing-agent--completion-word-state 'none)
             (typing-agent-engine--completion-done task state))))

        (_
         (typing-agent-engine--completion-done task state))))))

(defun typing-agent-engine--lines-next (task)
  "分行输入状态机的下一步。"
  (when (eq (typing-agent-task-status task) typing-agent-status-running)
    (let* ((state (typing-agent-task-op-state task))
           (lines (plist-get state :lines))
           (index (plist-get state :index))
           (phase (plist-get state :phase))
           (speed (or (plist-get state :speed) 1.0)))
      (cond
       ;; 全部行处理完：校验，然后按需要回 Normal。
       ((>= index (length lines))
        (typing-agent-engine--verify-lines task state)
        (when (plist-get state :auto-exit)
          (typing-agent-evil-exit-insert))
        (typing-agent-task-log task 'info "分行输入完成：%d 行" (length lines))
        (setf (typing-agent-task-op-state task) nil)
        (setf (typing-agent-task-index task)
              (1+ (typing-agent-task-index task)))
        (typing-agent-engine--schedule task 0.05))

       ;; 新行已经由 o 打开：先停一下，再开始输入这一行。
       ((eq phase 'open-next)
        (let ((pause (typing-agent-humanizer--random-range
                      typing-agent-next-line-pause)))
          (typing-agent-evil-enter-insert "o")
          (setf (plist-get state :open) nil)
          (setf (plist-get state :phase) 'open)
          (setf (typing-agent-task-op-state task) state)
          (typing-agent-task-log
           task 'info "第 %d 行：o 开新行，停 %.2f 秒再输入" (1+ index) pause)
          (typing-agent-engine--schedule
           task pause #'typing-agent-engine--lines-next)))

       ;; 准备当前行：按需进入 Insert，并用 TAB 完成缩进。
       ((eq phase 'open)
        (let* ((line (nth index lines))
               (open (plist-get state :open))
               (indent (typing-agent-engine--line-indent line))
               (skip 0))
          (when open
            (typing-agent-evil-enter-insert open))
          (when (and (plist-get state :indent-p)
                     (> (length indent) 0))
            (if (typing-agent-engine--at-line-start-p)
                (progn
                  (typing-agent-engine--apply-line-indent task indent)
                  (setq skip (length indent)))
              ;; 正常路径不会走到这里：说明有别的包在 `o' 开新行时自动插了
              ;; 前缀（例如 Doom 的注释续行 ` * '）。此时再从 0 开始输入整行
              ;; 会把前缀叠加成 ` *  * 文本'，留一条日志方便定位。
              (typing-agent-task-log
               task 'warn "第 %d 行行首不是空白（%S），跳过缩进"
               (1+ index)
               (buffer-substring-no-properties
                (line-beginning-position) (point)))))
          (setf (plist-get state :open) nil)
          (setf (plist-get state :phase) 'type)
          (setf (typing-agent-task-op-state task) state)
          ;; import 行：一次性整行写入，不逐字符敲（import 是机器自动补的）。
          (if (and typing-agent-import-inline
                   (typing-agent-engine--import-line-p line))
              (progn
                (typing-agent-engine--insert-import-line task line skip)
                (setf (plist-get state :char-index) (length line))
                (setf (typing-agent-task-op-state task) state)
                (typing-agent-engine--schedule
                 task 0.02 #'typing-agent-engine--lines-next))
            (setf (plist-get state :char-index) skip)
            (setf (typing-agent-task-op-state task) state)
            (typing-agent-engine--schedule
             task 0.03 #'typing-agent-engine--lines-next))))

       ;; 输入当前行的字符。
       (t
        (let* ((line (nth index lines))
               (char-index (plist-get state :char-index)))
          (if (>= char-index (length line))
              (typing-agent-engine--lines-finish-line task state)
            (let ((char (aref line char-index)))
              (typing-agent-evil-send-char char)
              (setf (plist-get state :char-index) (1+ char-index))
              (setf (typing-agent-task-op-state task) state)
              (if (typing-agent-engine--completion-start-p
                   line (1+ char-index) char)
                  (progn
                    (setf (plist-get state :phase) 'completion-show)
                    (setf (plist-get state :completion-tries) 0)
                    (setf (typing-agent-task-op-state task) state)
                    ;; 补全前把当前内容整份同步给 Eglot：任务期间 eglot 的
                    ;; 逐字符变更钩子已被摘掉，这里手动同步一次，补全才基于
                    ;; 最新文本（含刚敲的这个字符）。
                    (typing-agent-engine--eglot-sync-now)
                    (typing-agent-engine--schedule
                     task typing-agent-completion-settle
                     #'typing-agent-engine--completion-next))
                ;; 一个词已经写完：收起还开着的弹框，继续普通输入。
                (when (and typing-agent--completion-active
                           (typing-agent-completion-popup-p))
                  (typing-agent-completion-quit))
                (typing-agent-engine--schedule
                 task (typing-agent-humanizer-delay
                       char speed (aref line char-index))
                 #'typing-agent-engine--lines-next))))))))))

(defun typing-agent-engine--lines-finish-line (task state)
  "当前行输入完毕：行尾回 Normal 用 `o' 开新行，行中则用 RET 继续。
行尾先停一下再回 Normal（`typing-agent-line-break-pause'），开新行后
再停一下才开始输入下一行（`typing-agent-next-line-pause'）。"
  (let* ((lines (plist-get state :lines))
         (next (1+ (plist-get state :index))))
    (typing-agent-completion-quit)
    ;; 首行可能从行中开始，末行后可能还有原有文本；只校验本次写入部分。
    (let* ((beg (if (= next 1) (plist-get state :start)
                  (line-beginning-position)))
           (expected (nth (1- next) lines))
           (actual (buffer-substring-no-properties beg (point))))
      (unless (string= actual expected)
        (signal 'typing-agent-verify-error
                (list (format "第 %d 行输入不一致：预期 %S，实际 %S"
                              next expected actual)))))
    (cond
     ;; 最后一行：直接进入收尾。
     ((>= next (length lines))
      (setf (plist-get state :index) next)
      (setf (plist-get state :phase) 'open)
      (setf (typing-agent-task-op-state task) state)
      (typing-agent-engine--schedule
       task 0.05 #'typing-agent-engine--lines-next))
     ;; 行尾：ESC 回 Normal，停顿后（下一个状态）再按 o 开新行。
     ((eolp)
      (typing-agent-task-log task 'info
                             "第 %d 行写完：ESC 回 Normal"
                             (1+ (plist-get state :index)))
      (typing-agent-evil-exit-insert)
      (setf (plist-get state :index) next)
      (setf (plist-get state :phase) 'open-next)
      (setf (typing-agent-task-op-state task) state)
      (typing-agent-engine--schedule
       task (typing-agent-humanizer--random-range typing-agent-line-break-pause)
       #'typing-agent-engine--lines-next))
     ;; 行中（例如行内替换跨行）：仍在同一行，用 RET 换行继续。
     (t
      (typing-agent-task-log task 'info "行中换行：RET")
      (typing-agent-evil--execute-keys (vector ?\r))
      (setf (plist-get state :index) next)
      (setf (plist-get state :phase) 'open)
      (setf (typing-agent-task-op-state task) state)
      (typing-agent-engine--schedule
       task 0.05 #'typing-agent-engine--lines-next)))))

(defun typing-agent-engine--verify-lines (task state)
  "校验分行输入的结果与 STATE 记录的 EXPECTED 完全一致。
这是发现自动配对、自动缩进、snippet 展开等干扰的最后一道防线。"
  (let* ((start (plist-get state :start))
         (expected (or (plist-get state :expected) ""))
         (end (min (point-max) (+ start (length expected))))
         (actual (buffer-substring-no-properties start end)))
    (unless (string= actual expected)
      (typing-agent-task-log task 'debug "实际写入：%S" actual)
      (signal 'typing-agent-verify-error
              (list (format "分行输入结果与预期不一致（实际 %d 字符，预期 %d 字符）"
                            (length actual) (length expected)))))))

;;; 重复按键

(defun typing-agent-engine--start-repeat-key (task count event delay)
  "在 TASK 中重复发送 EVENT，共 COUNT 次，每次间隔 DELAY 秒。"
  (setf (typing-agent-task-op-state task)
        (list :kind 'repeat-key
              :remaining count
              :event event
              :delay delay))
  (typing-agent-engine--repeat-key-next task))

(defun typing-agent-engine--repeat-key-next (task)
  "发送重复按键序列中的下一个事件。"
  (when (eq (typing-agent-task-status task) typing-agent-status-running)
    (let* ((state (typing-agent-task-op-state task))
           (remaining (plist-get state :remaining)))
      (if (<= remaining 0)
          (progn
            (setf (typing-agent-task-op-state task) nil)
            (setf (typing-agent-task-index task)
                  (1+ (typing-agent-task-index task)))
            (typing-agent-engine--schedule task 0.04))
        (typing-agent-evil--execute-keys (plist-get state :event))
        (setf (plist-get state :remaining) (1- remaining))
        (setf (typing-agent-task-op-state task) state)
        (typing-agent-engine--schedule
         task (or (plist-get state :delay) 0.08)
         #'typing-agent-engine--repeat-key-next)))))

;;; 保存

(defun typing-agent-engine--save-buffer (task)
  "校验并保存 TASK 的 buffer。
保存前必须通过 buffer 校验；保存后重新读取文件确认内容一致。"
  (let* ((buffer (typing-agent-task-buffer task))
         (file (typing-agent-task-file task)))
    (unless (buffer-live-p buffer)
      (signal 'typing-agent-state-error (list "目标 buffer 已关闭")))
    (with-current-buffer buffer
      (when (typing-agent-evil-insert-p)
        (typing-agent-evil-exit-insert))
      ;; 校验失败时绝不保存。
      (when (typing-agent-task-expected task)
        (typing-agent-validator-check-buffer buffer
                                             (typing-agent-task-expected task)))
      (when (buffer-modified-p)
        ;; 保存期间禁用所有可能改写内容的钩子。
        ;; 只做动态绑定，不修改用户的全局配置。
        (let ((before-save-hook nil)
              (after-save-hook nil)
              (write-contents-functions nil)
              (require-final-newline nil))
          (save-buffer)))
      (when (and typing-agent-save-round-trip-check
                 (file-exists-p file))
        (let ((disk (typing-agent-file-content file))
              (memory (buffer-substring-no-properties (point-min) (point-max))))
          (unless (string= disk memory)
            (signal 'typing-agent-verify-error
                    (list "保存后文件内容与 buffer 不一致（可能被保存钩子改写）")))))
      (when (typing-agent-task-expected task)
        (typing-agent-validator-check-file file
                                           (typing-agent-task-expected task)))
      (setf (typing-agent-task-result task)
            (cons (cons :saved t)
                  (cons (cons :saved_file file)
                        (cons (cons :sha256 (typing-agent-file-sha256 file))
                              (typing-agent-task-result task)))))
      (typing-agent-task-log task 'info "已保存文件：%s" file))))

;;; 结束、失败、取消

(defun typing-agent-engine--finish (task)
  "正常结束 TASK。"
  (condition-case err
      (let ((buffer (typing-agent-task-buffer task)))
        ;; 可选：任务结束时自动保存（仍在校验之后）。
        (when (and (typing-agent-engine--option task :save)
                   (buffer-live-p buffer)
                   (with-current-buffer buffer (buffer-modified-p)))
          (typing-agent-task-log task 'info "options.save 为真，执行最终保存")
          (typing-agent-engine--save-buffer task))
        (when (buffer-live-p buffer)
          (with-current-buffer buffer
            (when (typing-agent-task-expected task)
              (typing-agent-validator-check-buffer
               buffer (typing-agent-task-expected task)))
            (setf (typing-agent-task-result task)
                  (cons (cons :sha256 (typing-agent-buffer-sha256 buffer))
                        (cons (cons :line_count
                                    (typing-agent-validator--line-count
                                     (buffer-substring-no-properties
                                      (point-min) (point-max))))
                              (typing-agent-task-result task))))))
        (typing-agent-engine--cleanup task)
        (setf (typing-agent-task-status task) typing-agent-status-completed)
        (setf (typing-agent-task-finished-at task) (typing-agent--now))
        (typing-agent-task-log task 'info "任务完成"))
    (error
     (typing-agent-engine--fail task err))))

(defun typing-agent-engine--cleanup (task)
  "恢复任务 TASK 的执行期 buffer 配置。"
  (typing-agent-engine--cancel-timer task)
  (let ((buffer (typing-agent-task-buffer task)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        ;; 绝不让任务把 buffer 留在 Insert 模式。
        (when (and (typing-agent-evil-available-p)
                   (not (typing-agent-evil-normal-p)))
          (ignore-errors (typing-agent-evil-ensure-normal "任务结束")))
        ;; 录制模式只是给当前 buffer 加了滚动边距，结束时还原。
        (when (typing-agent-engine--option task :recording)
          (typing-agent-recording-restore-scroll))
        (when (bound-and-true-p typing-agent-mode)
          (typing-agent-mode -1))))
    (when (eq typing-agent--active-task task)
      (setq typing-agent--active-task nil))
    ;; 任务结束（完成/失败/取消）后解锁输入。
    (typing-agent-lock-off)))

(defun typing-agent-engine--fail (task err)
  "把 TASK 标记为失败，记录 ERR，并恢复执行环境。"
  (when (memq (typing-agent-task-status task)
              (list typing-agent-status-running typing-agent-status-paused
                    typing-agent-status-pending))
    (let ((message-text (if (and (consp err) (symbolp (car err)))
                            (error-message-string err)
                          (format "%s" err))))
      (typing-agent-task-log task 'error "任务失败：%s" message-text)
      (setf (typing-agent-task-error task) message-text)
      (typing-agent-engine--cleanup task)
      (setf (typing-agent-task-status task) typing-agent-status-failed)
      (setf (typing-agent-task-finished-at task) (typing-agent--now)))))

(defun typing-agent-engine-cancel (task)
  "取消 TASK。已经结束的任务不做任何事。"
  (interactive)
  (when (memq (typing-agent-task-status task)
              (list typing-agent-status-running typing-agent-status-paused
                    typing-agent-status-pending))
    (typing-agent-engine--cancel-timer task)
    (typing-agent-engine--cleanup task)
    (setf (typing-agent-task-status task) typing-agent-status-cancelled)
    (setf (typing-agent-task-finished-at task) (typing-agent--now))
    (typing-agent-task-log task 'warn "任务被取消")
    t))

(defun typing-agent-engine-pause (task)
  "暂停 TASK。只在 running 状态有效。"
  (when (eq (typing-agent-task-status task) typing-agent-status-running)
    (if (null (typing-agent-task-buffer task))
        ;; 文件还在 dired 里创建，按键序列没法安全中断。
        (progn
          (typing-agent-task-log task 'warn "正在创建文件，稍后再暂停")
          nil)
      (setf (typing-agent-task-status task) typing-agent-status-paused)
      (typing-agent-engine--cancel-timer task)
      (typing-agent-task-log task 'info "任务暂停")
      t)))

(defun typing-agent-engine-resume (task)
  "继续 TASK。只在 paused 状态有效。"
  (when (eq (typing-agent-task-status task) typing-agent-status-paused)
    (setf (typing-agent-task-status task) typing-agent-status-running)
    (typing-agent-task-log task 'info "任务继续")
    (let ((state (typing-agent-task-op-state task)))
      (pcase (plist-get state :kind)
        ('lines (typing-agent-engine--lines-next task))
        ('newlines (typing-agent-engine--newline-next task))
        ('repeat-key (typing-agent-engine--repeat-key-next task))
        (_
         (setf (typing-agent-task-op-state task) nil)
         (typing-agent-engine--schedule task 0.02))))
    t))

;;; 任务级撤销

(defun typing-agent-engine--undo-builtin-p ()
  "当前 Evil 撤销后端是否就是 Emacs 内置 undo。
`undo-tree'/`undo-fu' 每次按 u 都是独立的一步；内置 undo 必须先用
`undo-start' 再连续调用 `undo-more'，否则会来回翻转（撤销/重做）。"
  (not (memq (or (bound-and-true-p evil-undo-system) 'undo)
             '(undo-tree undo-fu undo-redo))))

(defun typing-agent-engine--undo-save-buffer (task)
  "把撤销后的 buffer 直接写回文件，并记录保存结果。
撤销后的内容等于任务快照，再按任务期望内容校验没有意义，
所以这里跳过校验，只做保存钩子屏蔽与磁盘回读比对。"
  (when (and (buffer-modified-p) (buffer-file-name))
    (let ((before-save-hook nil)
          (after-save-hook nil)
          (write-contents-functions nil)
          (require-final-newline nil)
          (file (buffer-file-name)))
      (save-buffer)
      (when typing-agent-save-round-trip-check
        (unless (string= (typing-agent-file-content file)
                         (buffer-substring-no-properties
                          (point-min) (point-max)))
          (signal 'typing-agent-verify-error
                  (list "撤销后保存的文件内容与 buffer 不一致"))))
      (setf (typing-agent-task-result task)
            (cons (cons :saved t)
                  (cons (cons :saved_file file)
                        (cons (cons :sha256 (typing-agent-file-sha256 file))
                              (typing-agent-task-result task)))))
      (typing-agent-task-log task 'info "已保存撤销后的文件：%s" file))))

(defun typing-agent-engine-undo-task (task)
  "撤销 TASK 的全部修改，并把结果写回文件。
使用任务开始前的内容快照作为边界，最多回退
`typing-agent-undo-max-steps' 次；无法回到快照时报错，绝不静默成功。"
  (let* ((buffer (typing-agent-task-buffer task))
         (snapshot (typing-agent-task-snapshot task)))
    (unless (buffer-live-p buffer)
      (signal 'typing-agent-state-error (list "目标 buffer 已关闭，无法撤销")))
    (unless snapshot
      (signal 'typing-agent-state-error (list "任务没有保存快照，无法撤销")))
    (typing-agent-engine--focus-buffer task buffer)
    (with-current-buffer buffer
      (if (string= (buffer-substring-no-properties (point-min) (point-max))
                   snapshot)
          (typing-agent-task-log task 'info "内容已经与任务前一致，无需撤销")
        (when (eq buffer-undo-list t)
          (signal 'typing-agent-state-error
                  (list "当前 buffer 的撤销已被禁用，无法撤销任务")))
        (undo-boundary)
        (let* ((builtin (typing-agent-engine--undo-builtin-p))
               (steps 0)
               (done nil))
          (when builtin
            (undo-start))
          (while (and (< steps typing-agent-undo-max-steps) (not done))
            (cl-incf steps)
            (condition-case nil
                (if builtin
                    (undo-more 1)
                  ;; undo-tree / undo-fu：每次按一次 u，和真人撤销一致。
                  (typing-agent-evil-undo-step))
              (error (setq done 'failed)))
            (when (string= (buffer-substring-no-properties (point-min) (point-max))
                           snapshot)
              (setq done t)))
          (when builtin
            ;; 清掉内部状态，避免影响用户之后自己按 u。
            (setq pending-undo-list nil))
          (unless (eq done t)
            (signal 'typing-agent-verify-error
                    (list (format "退回 %d 步后仍未回到任务前内容；请手动检查" steps))))
          (typing-agent-task-log task 'info "已撤销任务（%d 步）" steps)))
      ;; 撤销只改了 buffer，磁盘必须同步，否则文件和 buffer 会不一致。
      (typing-agent-engine--undo-save-buffer task)
      (setf (typing-agent-task-result task)
            (cons (cons :undone t)
                  (cons (cons :undone_at (typing-agent--now))
                        (typing-agent-task-result task))))
      t)))

;;; 直接操作（HTTP 端点使用）

(defun typing-agent-engine--require-idle ()
  "任务运行期间禁止直接操作 buffer。"
  (when (typing-agent-task-busy-p)
    (signal 'typing-agent-busy-error
            (list "任务正在执行，请先停止或等待完成"))))

(defun typing-agent-engine-open (file &optional line)
  "查看 FILE，并可选跳到 LINE。
不直接切换 buffer：像人一样弹出 buffer/文件选择框，输入名字再跳过去。
FILE 已经在当前窗口显示时只跳行。"
  (typing-agent-engine--require-idle)
  (let* ((path (expand-file-name file))
         (already (and (find-buffer-visiting path) t))
         (buffer (progn
                   (unless (file-exists-p path)
                     (signal 'typing-agent-input-error
                             (list (format
                                    "文件不存在: %s（编辑任务会自动在 dired 中创建）"
                                    path))))
                   (find-file-noselect path))))
    (typing-agent-evil-visit-file path line already)
    buffer))

(defun typing-agent-engine-goto (line)
  "在当前 buffer 跳到 LINE。"
  (typing-agent-engine--require-idle)
  (typing-agent-evil-goto-line line))

(defun typing-agent-engine-search (text &optional occurrence unique)
  "在当前 buffer 搜索 TEXT。"
  (typing-agent-engine--require-idle)
  (typing-agent-evil-search-text text occurrence unique))

(defun typing-agent-engine-save-current ()
  "保存当前 buffer，并返回文件路径。"
  (typing-agent-engine--require-idle)
  (unless buffer-file-name
    (signal 'typing-agent-state-error (list "当前 buffer 没有关联文件")))
  (let ((before-save-hook nil)
        (after-save-hook nil)
        (write-contents-functions nil)
        (require-final-newline nil))
    (save-buffer))
  buffer-file-name)

(provide 'typing-agent-engine)
;;; typing-agent-engine.el ends here
