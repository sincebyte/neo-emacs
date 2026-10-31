;;; typing-agent-completion.el --- Eglot 补全弹框接入 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 在 Eglot 管理的 prog-mode buffer 里，逐字符输入时像人一样看补全弹框：
;;
;;   1. 输入点号或标识符字符后，等 corfu 弹框出现；
;;   2. 候选有多个时继续输入，让弹框自己筛选；
;;   3. 只剩一个候选、且候选文本正好是目标文本的前缀时，选中它，
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

(defcustom typing-agent-completion-enabled t
  "是否为编辑任务接入 Eglot 补全弹框。
只对 Eglot 管理的 prog-mode buffer 生效；关闭后行为与以前完全一致。"
  :type 'boolean
  :group 'typing-agent)

(defcustom typing-agent-completion-settle 0.16
  "输入触发字符后，等多久再检查补全弹框（秒）。
给当前字符的显示和主模式语法分析留出时间。"
  :type 'number
  :group 'typing-agent)

(defcustom typing-agent-completion-popup-pause 0.12
  "补全弹框弹出后，停留多久再读取候选（秒）。
让弹框在屏幕上可见，而不是一闪而过。"
  :type 'number
  :group 'typing-agent)

(defcustom typing-agent-completion-retry-delay 0.08
  "弹框还没出现时，隔多久重试（秒）。"
  :type 'number
  :group 'typing-agent)

(defcustom typing-agent-completion-max-retries 2
  "一次补全检查最多重试几次。
Eglot 没有候选时不会再弹框，重试几次后继续正常输入。"
  :type 'integer
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

(defun typing-agent-completion-check-position-p (line char-index char)
  "在 LINE 的 CHAR-INDEX 处刚输入 CHAR 后，是否值得检查补全。
CHAR-INDEX 是输入 CHAR 之后的位置；LINE 后面必须还有标识符字符。
没有后续字符时（行尾、单词结束）补全不可能让最终内容更短，直接跳过。"
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
    (let ((corfu-auto-prefix 1))
      (corfu-auto--complete-deferred))))

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
textEdit、snippet 和 additionalTextEdits（例如自动 import）都会让
插入结果超出目标文本；data 清掉后 Eglot 不会再去 resolve 出这些字段。"
  (when item
    (let ((clean (copy-sequence item)))
      (dolist (key '(:textEdit :additionalTextEdits :data :command
                     :insertTextFormat))
        (setq clean (plist-put clean key nil)))
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
仍然通过 `corfu-insert' 完成，所以 undo 分组、弹框收尾都与用户自己
按 RET 选择候选一致；区别只是候选文本使用纯 insertText。"
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
    ;; 最后一道保险：写入的内容必须正好是候选文本。
    (let ((actual (buffer-substring-no-properties
                   beg (min (point-max) (+ beg (length plain))))))
      (unless (string= actual plain)
        (delete-region beg (point))
        (goto-char beg)
        (insert before)
        (goto-char (+ beg (length before)))
        (signal 'typing-agent-verify-error
                (list (format "补全插入的内容与候选不一致: %S" actual)))))
    ;; 补全补上的那一段也算打字，镜像到 KeyCastr。
    (typing-agent-keycast-mirror-text
     (if (and (stringp before) (string-prefix-p before plain))
         (substring plain (length before))
       plain))))

;;; 检查入口

(defun typing-agent-completion-inspect (line)
  "检查当前补全弹框，并在合适时选中唯一候选。
LINE 是当前目标行。返回 plist：
  (:status none)                 没有弹框
  (:status multiple :count N)    候选多个，继续输入
  (:status selected :text S :char-index N)
  (:status rejected :text S)     候选与目标不匹配，继续输入"
  (let ((candidates (and (typing-agent-completion-popup-p)
                         corfu--candidates)))
    (cond
     ((null candidates)
      (list :status 'none))
     ((> (length candidates) 1)
      (list :status 'multiple :count (length candidates)))
     (t
      (let* ((candidate (car candidates))
             (item (typing-agent-completion--item candidate))
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
          (typing-agent-completion--select plain item beg)
          (list :status 'selected :text plain :char-index new-index))
         (t
          (list :status 'rejected :text plain))))))))

(provide 'typing-agent-completion)
;;; typing-agent-completion.el ends here
