;;; typing-agent-completion.el --- Eglot 补全弹框接入 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 在 Eglot 管理的 prog-mode buffer 里，逐字符输入时像人一样看补全弹框：
;;
;;   1. 输入点号或标识符字符后，等 corfu 弹框出现；
;;   2. 从候选中匹配目标标识符，逐步移动高亮；
;;   3. 目标位于前五项时优先选中，否则继续输入，
;;      并按实际插入的文本推进字符索引，绝不把已经补全的部分再敲一遍。
;;
;; 补全只负责“插入候选文本”，不执行 Eglot 的 textEdit / snippet /
;; additionalTextEdits：任务的目标内容由调用方精确给出，自动导入或
;; snippet 占位符会破坏最终校验。选中前会把 LSP item 里这些副作用字段
;; 清掉，选中后仍然走 `corfu-insert'，所以弹框会正常关闭。
;;
;; 这里只处理 Eglot + corfu；没有 Eglot 的 buffer 完全回到原来的逐字符输入。

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'typing-agent)
(require 'typing-agent-keycast)

(defvar corfu--base)
(defvar corfu--candidates)
(defvar corfu--index)
(defvar corfu--total)
(defvar corfu-auto-prefix)
(defvar completion-in-region-mode)
(defvar completion-in-region--data)

(declare-function corfu-insert "corfu")
(declare-function corfu-quit "corfu")
(declare-function corfu-next "corfu")
(declare-function corfu-previous "corfu")
(declare-function corfu--exhibit "corfu")

(defcustom typing-agent-completion-enabled t
  "是否为编辑任务接入 Eglot 补全弹框。
只对 Eglot 管理的 prog-mode buffer 生效；关闭后行为与以前完全一致。"
  :type 'boolean
  :group 'typing-agent)

(defcustom typing-agent-completion-settle 0.06
  "输入触发字符后，等多久再检查补全弹框（秒）。
给当前字符的显示和主模式语法分析留出时间。
只在词首或点号触发一次，不是每个字符都等。"
  :type 'number
  :group 'typing-agent)

(defcustom typing-agent-completion-popup-pause 0.25
  "补全弹框弹出后，停留多久再读取候选（秒）。
让弹框在屏幕上可见，而不是一闪而过。"
  :type 'number
  :group 'typing-agent)

(defcustom typing-agent-completion-selection-pause 0.18
  "补全候选高亮每移动一步后的停顿（秒）。"
  :type 'number
  :group 'typing-agent)

(defcustom typing-agent-completion-retry-delay 0.05
  "弹框还没出现时，隔多久重试（秒）。"
  :type 'number
  :group 'typing-agent)

(defcustom typing-agent-completion-max-retries 1
  "一次补全检查最多重试几次。
Eglot 没有候选时不会再弹框，重试几次后继续正常输入。"
  :type 'integer
  :group 'typing-agent)

(defcustom typing-agent-completion-import t
  "选中补全候选时是否允许 LSP 的 additionalTextEdits（例如自动 import）。
开启后，唯一候选带的 import 编辑会随选中一起应用，减少手动写 import；
关闭后清掉这些编辑，保持逐字符精确输入（与 expected.content/sha256 配合）。"
  :type 'boolean
  :group 'typing-agent)

(defcustom typing-agent-completion-prewarm-lsp t
  "任务开始前是否主动拉起 Eglot。
目标 buffer 没有连接 LSP、项目里也没有运行中的 server 时，在开始打字前
调用 `eglot-ensure' 冷启动并等待就绪，这样新建的文件在录制过程中也能
弹出补全。JDT 第一次启动要导入项目、建索引，可能要几十秒；等待上限由
`typing-agent-completion-prewarm-timeout' 控制。"
  :type 'boolean
  :group 'typing-agent)

(defcustom typing-agent-completion-prewarm-timeout 30
  "等待 Eglot 就绪的最长秒数。
超时后照常开始打字，只是可能暂时没有补全；LSP 就绪后补全会自动恢复。"
  :type 'number
  :group 'typing-agent)

(defvar-local typing-agent--completion-active nil
  "当前 buffer 的编辑任务是否启用补全。")

(defvar-local typing-agent--enabled-corfu-mode nil
  "任务是否临时启用了 `corfu-mode'。")

;;; 纯逻辑

(defun typing-agent-completion-trigger-char-p (char)
  "CHAR 是否会触发一次补全检查。
点号用于成员补全；字母、数字、下划线和 $ 用于标识符补全。"
  (and (characterp char)
       (or (eq char ?.)
           (string-match-p "[[:alnum:]_$]" (char-to-string char)))))

(defun typing-agent-completion-continuation-p (char)
  "CHAR 是否还是标识符的一部分。
只有目标文本后面还有标识符字符时，补全才可能帮我们少敲几个字。"
  (and (characterp char)
       (string-match-p "[[:alnum:]_$]" (char-to-string char))))

(defun typing-agent-completion-word-start-p (line char-index char)
  "CHAR 是否是一个标识符（词）的开头。
CHAR-INDEX 是输入 CHAR 之后的位置；CHAR 是刚输入的字符。前面不是
标识符字符（或已是行首）时就是词首；点号不是词首。"
  (and (typing-agent-completion-trigger-char-p char)
       (not (eq char ?.))
       (or (<= char-index 1)
           (not (typing-agent-completion-continuation-p
                 (aref line (- char-index 2)))))))

(defun typing-agent-completion-check-position-p (line char-index char)
  "在 LINE 的 CHAR-INDEX 处刚输入 CHAR 后，是否值得检查补全。
CHAR-INDEX 是输入 CHAR 之后的位置；LINE 后面必须还有标识符字符，
没有后续字符时（行尾、单词结束）补全不可能让最终内容更短，直接跳过。

点号 `.` 用于成员补全；字母、数字、下划线、`$` 用于标识符补全。是否
每个字符都检查由调用方按「词状态」退避决定，这里只回答「位置本身
值不值得检查」。"
  (and (typing-agent-completion-trigger-char-p char)
       (integer-or-marker-p char-index)
       (< char-index (length line))
       (typing-agent-completion-continuation-p (aref line char-index))))

(defun typing-agent-completion--fit (line start plain typed)
  "判断 PLAIN 是否能接在 LINE 的 START 处。
TYPED 是已经输入、位于补全范围内的字符数。只有 PLAIN 是 LINE 从
START 开始的前缀，并且比 TYPED 更长时才返回新的字符索引；否则返回 nil。
这样既保证最终内容完全一致，也保证选中候选后不会重复输入。"
  (when (and (integer-or-marker-p start)
             (<= 0 start)
             (< start (length line))
             (stringp plain)
             (not (string-empty-p plain))
             (not (string-match-p "\n" plain))
             (integer-or-marker-p typed)
             (<= 0 typed)
             (let ((remainder (substring line start)))
               (and (string-prefix-p plain remainder)
                    (> (length plain) typed))))
    (+ start (length plain))))

;;; Corfu / Eglot 状态

(defun typing-agent-completion-popup-p ()
  "当前 buffer 是否正显示 corfu 补全弹框。"
  (and (bound-and-true-p completion-in-region-mode)
       (boundp 'corfu--candidates)
       (consp corfu--candidates)
       (let ((end (nth 1 completion-in-region--data)))
         (or (not (markerp end))
             (eq (marker-buffer end) (current-buffer))))))

(defun typing-agent-completion-quit ()
  "收起当前 buffer 的补全弹框。"
  (when (bound-and-true-p completion-in-region-mode)
    (ignore-errors (corfu-quit)))
  nil)

(defun typing-agent-completion-trigger ()
  "让 corfu 在当前光标处弹出补全。
和 `corfu-auto' 使用同一个入口，但由任务主动调用，避免自动弹框的
时机和逐字符输入互相干扰。"
  (unless (featurep 'corfu-auto)
    (require 'corfu-auto))
  (when (fboundp 'corfu-auto--complete-deferred)
    ;; auto 入口在 completion-in-region-mode 已开启时直接返回。
    ;; 定时任务必须结束旧会话再查询，否则一直读取上个字符的候选。
    (typing-agent-completion-quit)
    ;; Eglot 的 session 缓存跨 buffer 共享，仅按符号位置复用；新文件
    ;; 恰好具有相同位置时可能拿到旧文件的候选。每次主动查询都清空。
    (when (fboundp 'eglot--capf-session-flush)
      (eglot--capf-session-flush))
    (let ((corfu-auto-prefix (if (eq (char-before) ?.) 0 1))
          ;; 任务只消费 LSP 候选，避免前面的文件名 CAPF 截走查询。
          (completion-at-point-functions '(eglot-completion-at-point)))
      (corfu-auto--complete-deferred))))

(defun typing-agent-completion-wanted-p ()
  "当前 buffer 是否希望为任务接入补全。
只检查主模式和 corfu，不要求 Eglot 已经就绪。任务途中 LSP 才连上时，
`typing-agent-completion-applicable-p' 会在下一个补全检查点自动生效。"
  (and (fboundp 'corfu-insert)
       (derived-mode-p 'prog-mode)))

(defun typing-agent-completion-applicable-p ()
  "当前 buffer 是否可以使用 Eglot 补全。
必须在 buffer 已经是 Eglot managed 之后调用。"
  (and (fboundp 'eglot-managed-p)
       (fboundp 'corfu-insert)
       (derived-mode-p 'prog-mode)
       (ignore-errors (eglot-managed-p))))

(defun typing-agent-completion-insert-context-p ()
  "当前光标位置是否适合检查补全。
字符串和注释里不触发，避免每敲一个字符都白等一次 LSP 响应。"
  (let ((ppss (syntax-ppss)))
    (and (not (nth 3 ppss))
         (not (nth 4 ppss)))))

;;; 候选与插入

(defun typing-agent-completion--item (candidate)
  "返回 CANDIDATE 携带的 Eglot LSP item。"
  (and (stringp candidate)
       (> (length candidate) 0)
       (get-text-property 0 'eglot--lsp-item candidate)))

(defun typing-agent-completion--plain-text (candidate)
  "返回 CANDIDATE 应当写入 buffer 的纯文本。
优先使用 LSP 的 insertText；没有时退回候选标签本身（去掉文本属性）。"
  (let* ((item (typing-agent-completion--item candidate))
         (insert (and item (plist-get item :insertText))))
    (if (and (stringp insert) (not (string-empty-p insert)))
        (substring-no-properties insert)
      (substring-no-properties candidate))))

(defun typing-agent-completion--clean-item (item)
  "复制 ITEM，并清掉会自动改写 buffer 的字段。
textEdit、snippet、command、data 都会让插入结果超出目标文本，一律清掉。
additionalTextEdits（例如自动 import）按 `typing-agent-completion-import'
决定保留还是清理：保留时 import 随选中一起应用；清理时保持逐字符精确。"
  (when item
    (let ((clean (copy-sequence item)))
      (dolist (key '(:textEdit :insertTextFormat :command :data))
        (setq clean (plist-put clean key nil)))
      (unless typing-agent-completion-import
        (setq clean (plist-put clean :additionalTextEdits nil)))
      clean)))

(defun typing-agent-completion--insert-string (plain item)
  "把 PLAIN 包装成 corfu 候选，并附带清理后的 ITEM。
保留 `eglot--lsp-item' 属性，Eglot 的 exit-function 因此仍能查到条目，
但条目里已经没有 textEdit / snippet / import 等副作用。"
  (if item
      (propertize plain 'eglot--lsp-item
                  (typing-agent-completion--clean-item item))
    plain))

(defun typing-agent-completion--select (plain item beg)
  "把 BEG..点 替换成候选 PLAIN，并关闭弹框。
仍然通过 `corfu-insert' 完成，所以 undo 分组、弹框收尾、以及 import
（additionalTextEdits）都与用户自己按 RET 选择候选一致；区别只是候选文本
使用纯 insertText。import 会在文件其它位置插入行，BEG 的绝对位置会偏移，
因此插入后的校验改用 point 之前的 len(plain) 个字符。"
  (let* ((str (typing-agent-completion--insert-string plain item))
         (before (buffer-substring-no-properties beg (point)))
         (corfu--index 0)
         (corfu--candidates (list str))
         (corfu--total 1))
    (condition-case nil
        (corfu-insert)
      (error
       ;; 弹框在检查期间消失时，直接做同样的替换，不留下半截状态。
       (typing-agent-completion-quit)
       (delete-region beg (point))
       (goto-char beg)
       (insert plain)))
    (typing-agent-completion-quit)
    (when (fboundp 'eglot--capf-session-flush)
      (ignore-errors (eglot--capf-session-flush)))
    ;; 最后一道保险：写入的内容必须正好是候选文本。import 可能已经往文件
    ;; 顶部插了行，beg 的绝对位置不再可靠，改校验 point 之前 len(plain) 个字符。
    (let ((start (max (point-min) (- (point) (length plain)))))
      (unless (string= (buffer-substring-no-properties start (point)) plain)
        (delete-region start (point))
        (goto-char start)
        (insert before)
        (signal 'typing-agent-verify-error
                (list "补全插入的内容与候选不一致"))))
    (typing-agent-keycast-mirror-event 'return)))

(defun typing-agent-completion--target-candidates (line candidates)
  "从 CANDIDATES 中找出与 LINE 目标匹配的完整标识符候选。
保留候选顺序，多个条目匹配时优先选择排序靠前的一项。"
  (let* ((beg (car completion-in-region--data))
         (beg (if (markerp beg) (marker-position beg) beg))
         (start (and (integerp beg) (- beg (line-beginning-position)))))
    (when (and start (<= 0 start) (<= start (length line)))
      (cl-remove-if-not
       (lambda (candidate)
         (let* ((plain (typing-agent-completion--plain-text candidate))
                (end (+ start (length plain))))
           (and (typing-agent-completion--item candidate)
                (string-prefix-p plain (substring line start))
                (not (string-empty-p plain))
                (or (= end (length line))
                    (not (typing-agent-completion-continuation-p
                          (aref line end)))))))
       candidates))))

;;; 检查入口

(defun typing-agent-completion-inspect (line)
  "检查当前补全弹框，优先逐步导航并选中前五项中的目标候选。
多个条目匹配时选择最靠前的一项，不等待候选总数减少或匹配唯一化。
LINE 是当前目标行。返回 plist：
  (:status none)                 没有弹框
  (:status multiple :count N)    目标在前五项之外，继续输入
  (:status navigating)          已移动高亮，等待下一次检查
  (:status selected :text S :char-index N)
  (:status rejected :text S)     候选与目标不匹配，继续输入"
  (let* ((candidates (and (typing-agent-completion-popup-p)
                          corfu--candidates))
         (matches (and candidates
                       (typing-agent-completion--target-candidates line candidates)))
         (candidate (car matches))
         (index (and candidate (cl-position candidate candidates :test #'eq))))
    (cond
     ((null candidates)
      (list :status 'none))
     ((null matches)
      (list :status 'rejected))
     ((>= index 5)
      (list :status 'multiple :count (length candidates)))
     (t
       (let* ((item (typing-agent-completion--item candidate))
             (plain (typing-agent-completion--plain-text candidate))
             (data completion-in-region--data)
             (beg (nth 0 data))
             (end (nth 1 data))
             (beg (if (markerp beg) (marker-position beg) beg))
             (end (if (markerp end) (marker-position end) end))
             (typed (and (integer-or-marker-p beg) (- (point) beg)))
             (start (and (integer-or-marker-p beg)
                         (- beg (line-beginning-position))))
             (new-index
              (and item
                   (integer-or-marker-p beg)
                   (integer-or-marker-p end)
                   (>= beg (point-min))
                   (<= beg (point))
                   (<= end (point))
                   (>= beg (line-beginning-position))
                   (<= 0 start)
                   (<= (+ start typed) (length line))
                   (string= (buffer-substring-no-properties beg (point))
                            (substring line start (+ start typed)))
                   (typing-agent-completion--fit line start plain typed))))
        (cond
         ((not item)
          ;; 其他 capf 的候选不归我们管，继续手动输入。
          (list :status 'rejected :text plain))
          (new-index
           (if (/= corfu--index index)
               (progn
                 (if (< corfu--index index)
                     (progn (corfu-next)
                            (typing-agent-keycast-mirror-event 'down))
                    (corfu-previous)
                    (typing-agent-keycast-mirror-event 'up))
                  ;; 定时器不运行 post-command-hook；导航命令只改索引，
                  ;; 必须主动刷新弹框，才能在下一步等待期间显示新高亮。
                  (corfu--exhibit)
                  (redisplay)
                  (list :status 'navigating))
             (typing-agent-completion--select plain item beg)
             (list :status 'selected :text plain :char-index new-index)))
         (t
          (list :status 'rejected :text plain))))))))

(provide 'typing-agent-completion)
;;; typing-agent-completion.el ends here
