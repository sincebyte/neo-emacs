;;; typing-agent-test.el --- Typing Agent 测试 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 运行方式（在已启动的 Emacs 中）：
;;   M-x load-file RET .../typing-agent-test.el
;;   M-x ert-run-tests-interactively RET
;;
;; 或者在命令行：
;;   emacsclient -e '(progn (load "…/typing-agent-test.el") (ert-run-tests-batch-and-exit))'

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'typing-agent)
(require 'typing-agent-humanizer)
(require 'typing-agent-keycast)
(require 'typing-agent-completion)
(require 'typing-agent-validator)
(require 'typing-agent-diff)
(require 'typing-agent-engine)
(require 'typing-agent-server)

;; 测试期间不要往用户真正开着的 KeyCastr 里灌按键。
(setq typing-agent-keycast-enabled nil)

;; 纯 `emacs -Q' + Evil 的环境没有 Doom 的撤销后端配置，
;; 这里显式退回到 Emacs 内置 undo；在 Doom 中该变量已由用户配置。
(unless (bound-and-true-p evil-undo-system)
  (setq evil-undo-system 'undo))

(defmacro typing-agent-test-with-temp-file (content &rest body)
  "创建内容为 CONTENT 的临时文件，执行 BODY。
BODY 中变量 `file' 是文件路径。"
  (declare (indent 1))
  `(let* ((file (make-temp-file "typing-agent-test-" nil ".java"))
          (buffer nil))
     (unwind-protect
         (progn
           (with-temp-file file (insert ,content))
           (setq buffer (find-file-noselect file))
           (with-current-buffer buffer
             (when (fboundp 'evil-mode)
               (evil-mode 1))
             (goto-char (point-min)))
           ,@body)
       (when (buffer-live-p buffer)
         (with-current-buffer buffer
           (set-buffer-modified-p nil))
         (kill-buffer buffer))
       (ignore-errors (delete-file file)))))

(defun typing-agent-test--wait (task &optional timeout)
  "等待 TASK 结束，最多 TIMEOUT 秒。返回最终状态。"
  (let ((deadline (+ (float-time) (or timeout 30))))
    (while (and (memq (typing-agent-task-status task)
                      (list typing-agent-status-pending
                            typing-agent-status-running
                            typing-agent-status-paused))
                (< (float-time) deadline))
      (accept-process-output nil 0.05))
    (typing-agent-task-status task)))

;;; 纯逻辑

(ert-deftest typing-agent-test-humanizer-delay ()
  (typing-agent-humanizer-reset 1.0)
  (let ((delay (typing-agent-humanizer-delay ?a)))
    (should (> delay 0))
    (should (< delay 1.0)))
  (typing-agent-humanizer-reset 2.0)
  (should (> (typing-agent-humanizer-delay ?a) 0)))

(ert-deftest typing-agent-test-humanizer-punctuation ()
  (typing-agent-humanizer-reset 1.0)
  (should (typing-agent-humanizer-punctuation-p ?.))
  (should (typing-agent-humanizer-punctuation-p ?\)))
  (should-not (typing-agent-humanizer-punctuation-p ?a)))

(ert-deftest typing-agent-test-humanizer-human-pace ()
  ;; 提速后的节奏：基础 11 字符/秒（约 132 WPM），单字符间隔在 0.07 秒上下，
  ;; 有随机快慢，但不会慢到卡、也不会快得像机器连发（min-key-delay 兜底）。
  (typing-agent-humanizer-reset 1.0)
  (let ((typing-agent-thinking-probability 0)
        (typing-agent-burst-probability 0)
        (delay (typing-agent-humanizer-delay ?a)))
    (should (>= delay 0.02))
    (should (<= delay 0.40)))
  ;; 不再模拟错字：打错的实现和任务选项都已移除。
  (should-not (fboundp 'typing-agent-humanizer-should-typo-p))
  (should-not (assq :typo_probability
                    (typing-agent-engine-parse-options
                     (list (cons :options
                                 (list (cons :typo_probability 0.5))))))))

(ert-deftest typing-agent-test-json-prepare ()
  (let* ((object (list (cons :ok t)
                       (cons :operations
                             (typing-agent-json-array
                              (list :type "type_text"
                                    :text "hello")
                              (list :type "save_buffer")))))
         (prepared (typing-agent-json-prepare object))
         (json (json-encode prepared)))
    (should (string-match-p "\"ok\":true" json))
    (should (string-match-p "\"operations\":\\[" json))
    (should (string-match-p "\"type\":\"type_text\"" json))
    (should (string-match-p "\"type\":\"save_buffer\"" json))))

(ert-deftest typing-agent-test-json-boolean ()
  ;; 假值必须编码成 false，不能退化成 null；null 另有含义。
  (should (string-match-p
           "\"modified\":false"
           (json-encode
            (typing-agent-json-prepare
             (list (cons :modified
                         (typing-agent-json-boolean nil)))))))
  (should (string-match-p
           "\"modified\":true"
           (json-encode
            (typing-agent-json-prepare
             (list (cons :modified
                         (typing-agent-json-boolean 0)))))))
  ;; 解析后 :false 也要能原样编码回 false。
  (should (string-match-p
           "\"ok\":false"
           (json-encode
            (typing-agent-json-prepare
             (list (cons :ok :false)))))))

(ert-deftest typing-agent-test-json-prepare-rejects-ambiguous-list ()
  ;; 列表既可能是对象也可能是数组，必须用 vector 明确表示数组。
  (should-error (typing-agent-json-prepare '("a" "b"))
                :type 'typing-agent-input-error))

;;; 校验

(ert-deftest typing-agent-test-validator-success ()
  (with-temp-buffer
    (insert "public class A {\n}\n")
    (should (= 3
               (typing-agent-validator-check-buffer
                (current-buffer)
                (list :contains ["class A"]
                      :not_contains ["class B"]
                      :line_count 2))))))

(ert-deftest typing-agent-test-validator-failure ()
  (with-temp-buffer
    (insert "public class A {\n}\n")
    (should-error
     (typing-agent-validator-check-buffer
      (current-buffer)
      (list :contains ["class B"]))
     :type 'typing-agent-verify-error)))

(ert-deftest typing-agent-test-validator-content ()
  (with-temp-buffer
    (insert "abc")
    (should (typing-agent-validator-check-buffer
             (current-buffer)
             (list :content "abc")))
    (should-error
     (typing-agent-validator-check-buffer
      (current-buffer)
      (list :content "abcd"))
     :type 'typing-agent-verify-error)))

;;; Diff

(defconst typing-agent-test--java-diff
  "--- a/src/main/java/UserService.java
+++ b/src/main/java/UserService.java
@@ -1,6 +1,10 @@
 public class UserService {
 
     public void createUser() {
         System.out.println(\"create\");
     }
+
+    public void deleteUser() {
+        System.out.println(\"delete\");
+    }
 }
")

(ert-deftest typing-agent-test-diff-parse ()
  (let* ((files (typing-agent-diff-parse typing-agent-test--java-diff))
         (file (car files))
         (hunks (plist-get file :hunks)))
    (should (= 1 (length files)))
    (should (string= "src/main/java/UserService.java"
                     (plist-get file :new_path)))
    (should (= 1 (length hunks)))
    (should (= 1 (plist-get (car hunks) :old_start)))
    (should (= 6 (plist-get (car hunks) :old_lines)))
    (should (= 10 (plist-get (car hunks) :new_lines)))
    (should (= 10 (length (plist-get (car hunks) :lines))))))

(ert-deftest typing-agent-test-diff-operations ()
  (let* ((files (typing-agent-diff-parse typing-agent-test--java-diff))
         (ops (typing-agent-diff->operations (car files))))
    ;; search_text / move_cursor / enter_insert / type_text / exit_insert / save
    (should (= 6 (length ops)))
    (should (equal "search_text" (plist-get (nth 0 ops) :type)))
    (should (equal "    }" (plist-get (nth 0 ops) :text)))
    (should (equal "o" (plist-get (nth 2 ops) :command)))
    (should (equal "type_text" (plist-get (nth 3 ops) :type)))
    (should (string-prefix-p "\n    public void deleteUser()"
                             (plist-get (nth 3 ops) :text)))
    (should (equal "save_buffer" (plist-get (nth 5 ops) :type)))))

(ert-deftest typing-agent-test-diff-modify ()
  (let* ((diff "--- a/A.java
+++ b/A.java
@@ -1,3 +1,3 @@
 class A {
-    int x = 1;
+    int x = 2;
 }
")
         (ops (typing-agent-diff->operations
               (car (typing-agent-diff-parse diff)))))
    (should (equal "replace_region" (plist-get (car ops) :type)))
    (should (equal "    int x = 1;\n" (plist-get (car ops) :search)))
    (should (equal "    int x = 2;\n" (plist-get (car ops) :replace)))))

(ert-deftest typing-agent-test-diff-delete ()
  (let* ((diff "--- a/A.java
+++ b/A.java
@@ -1,3 +1,2 @@
 class A {
-    int x = 1;
 }
")
         (ops (typing-agent-diff->operations
               (car (typing-agent-diff-parse diff)))))
    (should (equal "replace_region" (plist-get (car ops) :type)))
    (should (equal "    int x = 1;\n" (plist-get (car ops) :search)))
    (should (equal "" (plist-get (car ops) :replace)))))

;;; 端到端（需要 Evil）

(ert-deftest typing-agent-test-engine-insert-and-save ()
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n\n    public void run() {\n        System.out.println(\"run\");\n    }\n}\n"))
    (typing-agent-test-with-temp-file content
      (let ((task (typing-agent-engine-submit
                   (typing-agent-json-parse
                    (json-encode
                     (typing-agent-json-prepare
                      (list (cons :file file)
                            (cons :operations
                                  (vconcat
                                   (list (list :type "search_text"
                                               :text "System.out.println(\"run\");")
                                         (list :type "move_cursor"
                                               :position "line_end")
                                         (list :type "enter_insert"
                                               :command "o")
                                         (list :type "type_text"
                                               :text "        System.out.println(\"done\");")
                                         (list :type "exit_insert")
                                         (list :type "save_buffer")))))))))))
        (should (typing-agent-test--wait task))
        (should (eq (typing-agent-task-status task) 'completed))
        (should (string-match-p
                 "println(\"run\");\n        System.out.println(\"done\");"
                 (typing-agent-file-content file)))
        (should (string-match-p
                 "System.out.println(\"done\");"
                 (typing-agent-file-content file)))))))

(ert-deftest typing-agent-test-engine-replace-region ()
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n    int value = 1;\n}\n"))
    (typing-agent-test-with-temp-file content
      (let ((task (typing-agent-engine-submit
                   (typing-agent-json-parse
                    (json-encode
                     (typing-agent-json-prepare
                      (list (cons :file file)
                            (cons :operations
                                  (vconcat
                                   (list (list :type "replace_region"
                                               :search "    int value = 1;\n"
                                               :replace "    int value = 42;\n")
                                         (list :type "save_buffer")))))))))))
        (should (typing-agent-test--wait task))
        (should (eq (typing-agent-task-status task) 'completed))
        (should (equal "public class A {\n    int value = 42;\n}\n"
                       (typing-agent-file-content file)))))))

(ert-deftest typing-agent-test-engine-replace-multiline ()
  ;; 整行替换：dd 删除后用 O/o 逐行写回，包含空行与缩进。
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n    int value = 1;\n}\n"))
    (typing-agent-test-with-temp-file content
      (let ((task (typing-agent-engine-submit
                   (typing-agent-json-parse
                    (json-encode
                     (typing-agent-json-prepare
                      (list (cons :file file)
                            (cons :operations
                                  (vconcat
                                   (list (list :type "replace_region"
                                               :search "    int value = 1;\n"
                                               :replace "    int value = 42;\n\n    int other = 7;\n")
                                         (list :type "save_buffer")))))))))))
        (should (typing-agent-test--wait task))
        (should (eq (typing-agent-task-status task) 'completed))
        (should (equal "public class A {\n    int value = 42;\n\n    int other = 7;\n}\n"
                       (typing-agent-file-content file)))))))

(ert-deftest typing-agent-test-engine-type-text-multiline ()
  ;; type_text 含换行时按行输入：每个行尾回 Normal，用 o 开新行。
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n    public void run() {\n    }\n}\n"))
    (typing-agent-test-with-temp-file content
      (let ((task (typing-agent-engine-submit
                   (typing-agent-json-parse
                    (json-encode
                     (typing-agent-json-prepare
                      (list (cons :file file)
                            (cons :operations
                                  (vconcat
                                   (list (list :type "search_text"
                                               :text "    public void run() {")
                                         (list :type "move_cursor"
                                               :position "line_end")
                                         (list :type "enter_insert"
                                               :command "o")
                                         (list :type "type_text"
                                               :text "        int a = 1;\n        int b = 2;")
                                         (list :type "exit_insert")
                                         (list :type "save_buffer")))))))))))
        (should (typing-agent-test--wait task))
        (should (eq (typing-agent-task-status task) 'completed))
        (should (equal (concat "public class A {\n"
                               "    public void run() {\n"
                               "        int a = 1;\n"
                               "        int b = 2;\n"
                               "    }\n}\n")
                       (typing-agent-file-content file)))))))

(defun typing-agent-test--comment-continuing-open-below (fn count)
  "模拟 Doom 的 `o'：在注释内开新行时续写 ` * ' 前缀。
只用于验证任务把 `+evil-want-o/O-to-continue-comments' 绑成 nil 后，
Javadoc 不会再被叠加成 ` *  * 文本'。"
  (if (or (not +evil-want-o/O-to-continue-comments)
          (not (nth 4 (syntax-ppss))))
      (funcall fn count)
    (prog1 (funcall fn count)
      (save-excursion
        (goto-char (line-beginning-position))
        (insert " * ")))))

(ert-deftest typing-agent-test-engine-javadoc-ignores-comment-continuation ()
  ;; Doom 的 `o'/`O' 在注释内会自动续写 ` * ' 前缀
  ;; （`+evil-want-o/O-to-continue-comments'）。任务自己按 spec 写整行缩进，
  ;; 两者叠加会把 Javadoc 打成 ` *  * 文本'。这里用一条模拟 advice 复现
  ;; Doom 的行为，确保任务把它关掉后仍逐字符一致。
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n    /**\n}\n")
        (expected (concat "public class A {\n"
                          "    /**\n"
                          "     * 楼栋名称\n"
                          "     *\n"
                          "     * @author van\n"
                          "     */\n"
                          "}\n")))
    (typing-agent-test-with-temp-file content
      (let ((original +evil-want-o/O-to-continue-comments))
        (setq +evil-want-o/O-to-continue-comments t)
        (advice-add 'evil-open-below :around
                    #'typing-agent-test--comment-continuing-open-below)
        (unwind-protect
            (let ((task (typing-agent-engine-submit
                         (typing-agent-json-parse
                          (json-encode
                           (typing-agent-json-prepare
                            (list (cons :file file)
                                  (cons :options (list :speed 30))
                                  (cons :operations
                                        (vconcat
                                         (list (list :type "search_text"
                                                     :text "    /**")
                                               (list :type "move_cursor"
                                                     :position "line_end")
                                               (list :type "enter_insert"
                                                     :command "o")
                                               (list :type "type_text"
                                                     :text (concat
                                                            "     * 楼栋名称\n"
                                                            "     *\n"
                                                            "     * @author van\n"
                                                            "     */"))
                                               (list :type "exit_insert")))))))))))
              (should (typing-agent-test--wait task))
              (should (eq (typing-agent-task-status task) 'completed))
              (should (equal expected
                             (with-current-buffer (typing-agent-task-buffer task)
                               (buffer-substring-no-properties
                                (point-min) (point-max))))))
          (advice-remove 'evil-open-below
                         #'typing-agent-test--comment-continuing-open-below)
          (setq +evil-want-o/O-to-continue-comments original))))))

(ert-deftest typing-agent-test-engine-import-inline ()
  ;; import 行一次性整行写入，不逐字符敲；最终内容仍逐字符一致。
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n}\n"))
    (typing-agent-test-with-temp-file content
      (let ((task (typing-agent-engine-submit
                   (typing-agent-json-parse
                    (json-encode
                     (typing-agent-json-prepare
                      (list (cons :file file)
                            (cons :options (list :speed 30))
                            (cons :operations
                                  (vconcat
                                   (list (list :type "search_text"
                                               :text "public class A {")
                                         (list :type "move_cursor"
                                               :position "line_start")
                                         (list :type "enter_insert"
                                               :command "O")
                                         (list :type "type_text"
                                               :text "import java.util.List;\nimport java.util.Map;")
                                         (list :type "exit_insert")
                                         (list :type "save_buffer")))))))))))
        (should (typing-agent-test--wait task))
        (should (eq (typing-agent-task-status task) 'completed))
        (should (equal (concat "import java.util.List;\n"
                               "import java.util.Map;\n"
                               "public class A {\n}\n")
                       (typing-agent-file-content file)))))))

(ert-deftest typing-agent-test-engine-indent-preserves-tabs ()
  ;; 文件用制表符缩进时，TAB 缩进后仍必须精确还原成 tab。
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n\tint value = 1;\n}\n"))
    (typing-agent-test-with-temp-file content
      (let ((task (typing-agent-engine-submit
                   (typing-agent-json-parse
                    (json-encode
                     (typing-agent-json-prepare
                      (list (cons :file file)
                            (cons :operations
                                  (vconcat
                                   (list (list :type "replace_region"
                                               :search "\tint value = 1;\n"
                                               :replace "\tint value = 2;\n")
                                         (list :type "save_buffer")))))))))))
        (should (typing-agent-test--wait task))
        (should (eq (typing-agent-task-status task) 'completed))
        (should (equal "public class A {\n\tint value = 2;\n}\n"
                       (typing-agent-file-content file)))))))

(ert-deftest typing-agent-test-engine-insert-newline-at-eol ()
  ;; 行尾插入换行：走 ESC 回 Normal + o 开新行，而不是一路 insert。
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n}\n"))
    (typing-agent-test-with-temp-file content
      (let ((task (typing-agent-engine-submit
                   (typing-agent-json-parse
                    (json-encode
                     (typing-agent-json-prepare
                      (list (cons :file file)
                            (cons :operations
                                  (vconcat
                                   (list (list :type "search_text"
                                               :text "public class A {")
                                         (list :type "enter_insert"
                                               :command "A")
                                         (list :type "insert_newline"
                                               :count 2)
                                         (list :type "type_text"
                                               :text "    int x;")
                                         (list :type "exit_insert")
                                         (list :type "save_buffer")))))))))))
        (should (typing-agent-test--wait task))
        (should (eq (typing-agent-task-status task) 'completed))
        (should (equal "public class A {\n\n    int x;\n}\n"
                       (typing-agent-file-content file)))))))

(ert-deftest typing-agent-test-engine-undo ()
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n    int value = 1;\n}\n"))
    (typing-agent-test-with-temp-file content
      (let ((task (typing-agent-engine-submit
                   (typing-agent-json-parse
                    (json-encode
                     (typing-agent-json-prepare
                      (list (cons :file file)
                            (cons :operations
                                  (vconcat
                                   (list (list :type "replace_region"
                                               :search "    int value = 1;\n"
                                               :replace "    int value = 42;\n")))))))))))
        (should (typing-agent-test--wait task))
        (should (eq (typing-agent-task-status task) 'completed))
        (should (equal "public class A {\n    int value = 42;\n}\n"
                       (with-current-buffer (typing-agent-task-buffer task)
                         (buffer-substring-no-properties
                          (point-min) (point-max)))))
        (typing-agent-engine-undo-task task)
        (should (equal content
                       (with-current-buffer (typing-agent-task-buffer task)
                         (buffer-substring-no-properties
                          (point-min) (point-max)))))))))

(ert-deftest typing-agent-test-popup-tip-does-not-touch-buffer ()
  ;; `flycheck-popup-tip' 用 popup.el 弹提示，而 popup.el 会往 buffer 末尾插
  ;; 空行来撑高度。任务开始时这个 buffer 的诊断改走回显区，文件内容因此不会
  ;; 被多余空行污染。
  (cl-letf (((symbol-function 'flycheck-popup-tip-show-popup) #'ignore)
            ((symbol-function 'flycheck-display-error-messages) #'ignore))
    (with-temp-buffer
      (setq-local flycheck-display-errors-function
                  #'flycheck-popup-tip-show-popup)
      (typing-agent--quiesce-buffer)
      (should-not (eq flycheck-display-errors-function
                      #'flycheck-popup-tip-show-popup))
      (should (functionp flycheck-display-errors-function))
      (typing-agent--restore-buffer))))

(ert-deftest typing-agent-test-quiesce-eglot-hooks ()
  ;; 任务期间摘掉 eglot 的逐字符变更钩子（消除 O(n) 行号换算与增量记录堆积），
  ;; 结束后恢复。这里用假 eglot 函数验证钩子的摘除/恢复。
  (cl-letf (((symbol-function 'eglot--before-change) #'ignore)
            ((symbol-function 'eglot--after-change) #'ignore))
    (with-temp-buffer
      (setq-local typing-agent--completion-active t)
      (add-hook 'before-change-functions #'eglot--before-change nil t)
      (add-hook 'after-change-functions #'eglot--after-change nil t)
      (typing-agent--quiesce-buffer)
      (should-not (memq 'eglot--before-change before-change-functions))
      (should-not (memq 'eglot--after-change after-change-functions))
      (typing-agent--restore-buffer)
      (should (memq 'eglot--before-change before-change-functions))
      (should (memq 'eglot--after-change after-change-functions)))))

(ert-deftest typing-agent-test-eglot-hooks-quiesced-when-lsp-arrives-late ()
  ;; 任务开始时没有 LSP：先没有钩子可摘；等它途中连上后，新钩子也要摘掉，
  ;; 任务结束时再把钩子还给用户后续编辑。
  (cl-letf (((symbol-function 'eglot--before-change) #'ignore)
            ((symbol-function 'eglot--after-change) #'ignore))
    (with-temp-buffer
      (setq-local typing-agent--completion-active t)
      (setq-local typing-agent-mode t)
      (typing-agent--quiesce-buffer)
      (should-not (memq 'eglot--before-change before-change-functions))
      (add-hook 'before-change-functions #'eglot--before-change nil t)
      (add-hook 'after-change-functions #'eglot--after-change nil t)
      (typing-agent--eglot-arrived)
      (should-not (memq 'eglot--before-change before-change-functions))
      (should-not (memq 'eglot--after-change after-change-functions))
      (typing-agent--restore-buffer)
      (should (memq 'eglot--before-change before-change-functions))
      (should (memq 'eglot--after-change after-change-functions)))))

(ert-deftest typing-agent-test-lsp-connect-runs-deferred-hook-only ()
  ;; 真实 eglot-ensure 延迟到 post-command 才连接；定时任务不能只等待。
  (with-temp-buffer
    (let ((connected nil)
          (unrelated nil))
      (setq-local post-command-hook (list (lambda () (setq unrelated t))))
      (let ((original post-command-hook))
        (cl-letf (((symbol-function 'eglot-current-server) #'ignore)
                  ((symbol-function 'eglot-ensure)
                   (lambda ()
                     (add-hook 'post-command-hook
                               (lambda () (setq connected t)) nil t))))
          (typing-agent-engine--connect-lsp-now)
          (should connected)
          (should-not unrelated)
          (should (equal post-command-hook original)))))))

(ert-deftest typing-agent-test-lsp-existing-server-unmanaged-buffer ()
  ;; 项目 server 存在不等于新文件已发送 didOpen、装好 CAPF。
  (let ((managed nil)
        (activated nil))
    (cl-letf (((symbol-function 'eglot-current-server) (lambda () 'fake))
              ((symbol-function 'eglot-managed-p) (lambda () managed))
              ((symbol-function 'eglot-ensure)
               (lambda () (ert-fail "不应重连已有 server")))
              ((symbol-function 'eglot--maybe-activate-editing-mode)
               (lambda () (setq activated t managed t)))
              ((symbol-function 'typing-agent-engine--any-lsp-running-p) (lambda () t))
              ((symbol-function 'typing-agent-engine--option) (lambda (&rest _) nil))
              ((symbol-function 'typing-agent-task-log) #'ignore)
              ((symbol-function 'typing-agent-engine--eglot-sync-now) #'ignore))
      (typing-agent-engine--ensure-lsp nil)
      (should activated)
      (should (typing-agent-engine--lsp-ready-p)))))

(ert-deftest typing-agent-test-ensure-lsp-prewarms ()
  ;; 项目里没有 LSP 时，开启预热会冷启动并等到 eglot-managed-p 为真，
  ;; 这样新建文件在打字时也能有补全。
  (let ((server nil)
        (ensured nil))
    (cl-letf (((symbol-function 'eglot-current-server) (lambda () server))
              ((symbol-function 'eglot-managed-p) (lambda () (not (null server))))
              ((symbol-function 'eglot-ensure)
               (lambda () (setq ensured t server 'fake)))
              ((symbol-function 'typing-agent-engine--any-lsp-running-p) #'ignore)
              ((symbol-function 'typing-agent-engine--option) (lambda (&rest _) t))
              ((symbol-function 'typing-agent-task-log) #'ignore)
              ((symbol-function 'typing-agent-engine--eglot-sync-now) #'ignore)
              ((symbol-function 'accept-process-output) #'ignore))
      (typing-agent-engine--ensure-lsp nil)
      (should ensured)
      (should (eq server 'fake)))))

(ert-deftest typing-agent-test-ensure-lsp-no-prewarm ()
  ;; 关掉预热、且没有任何 server 时，绝不冷启动。
  (let ((typing-agent-completion-prewarm-lsp nil)
        (ensured nil))
    (cl-letf (((symbol-function 'eglot-current-server) #'ignore)
              ((symbol-function 'eglot-managed-p) (lambda () t))
              ((symbol-function 'eglot-ensure) (lambda () (setq ensured t)))
              ((symbol-function 'typing-agent-engine--any-lsp-running-p) #'ignore)
              ((symbol-function 'typing-agent-engine--option) (lambda (&rest _) t))
              ((symbol-function 'typing-agent-task-log) #'ignore))
      (typing-agent-engine--ensure-lsp nil)
      (should-not ensured))))

(ert-deftest typing-agent-test-ensure-lsp-joins-running-server ()
  ;; 已有 server 时立即连接，不需要冷启动。
  (let ((server nil)
        (ensured nil))
    (cl-letf (((symbol-function 'eglot-current-server) (lambda () server))
              ((symbol-function 'eglot-managed-p) (lambda () (not (null server))))
              ((symbol-function 'eglot-ensure)
               (lambda () (setq ensured t server 'fake)))
              ((symbol-function 'typing-agent-engine--any-lsp-running-p) (lambda () t))
              ((symbol-function 'typing-agent-engine--option) (lambda (&rest _) nil))
              ((symbol-function 'typing-agent-task-log) #'ignore)
              ((symbol-function 'typing-agent-engine--eglot-sync-now) #'ignore)
              ((symbol-function 'accept-process-output) #'ignore))
      (typing-agent-engine--ensure-lsp nil)
      (should ensured)
      (should (eq server 'fake)))))

(ert-deftest typing-agent-test-visit-file-already-shown ()
  ;; 文件已经在当前窗口：只跳行，不再弹选择框、不换 buffer。
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n    int value = 1;\n}\n"))
    (typing-agent-test-with-temp-file content
      (switch-to-buffer buffer)
      (typing-agent-evil-visit-file file 2 t)
      (should (eq (window-buffer (selected-window)) buffer))
      (should (= 2 (line-number-at-pos)))
      (should (= 1 (length (window-list)))))))

(ert-deftest typing-agent-test-visit-file-direct ()
  ;; direct 模式不弹选择框，直接把文件显示出来并跳到指定行。
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n}\n")
        (other (make-temp-file "typing-agent-test-other-" nil ".java")))
    (unwind-protect
        (progn
          (with-temp-file other (insert "public class B {\n    int b;\n}\n"))
          (typing-agent-test-with-temp-file content
            (let ((typing-agent-visit-method 'direct))
              (typing-agent-evil-visit-file other 2)
              (should (equal (buffer-file-name (window-buffer (selected-window)))
                             (expand-file-name other)))
              (should (= 2 (line-number-at-pos)))
              (should (= 1 (length (window-list)))))))
      (when-let* ((buffer (find-buffer-visiting other)))
        (with-current-buffer buffer (set-buffer-modified-p nil))
        (kill-buffer buffer))
      (ignore-errors (delete-file other)))))

(ert-deftest typing-agent-test-task-maximizes-window ()
  ;; 任务开始时必须找到目标文件，并让它独占窗口，避免两个小窗口看不清楚。
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n    int value = 1;\n}\n"))
    (typing-agent-test-with-temp-file content
      (let ((other (generate-new-buffer " *typing-agent-other*")))
        (unwind-protect
            (progn
              (switch-to-buffer other)
              (split-window-below)
              (should (> (length (window-list)) 1))
              (let* ((spec
                      (typing-agent-json-parse
                       (json-encode
                        (typing-agent-json-prepare
                         (list (cons :file file)
                               (cons :options (list :speed 30))
                               (cons :operations
                                     (vconcat
                                      (list
                                       (list :type "replace_region"
                                             :search "    int value = 1;\n"
                                             :replace "    int value = 2;\n")
                                       (list :type "save_buffer")))))))))
                     (task (typing-agent-engine-submit spec)))
                ;; 等任务开始并完成窗口切换。
                (let ((deadline (+ (float-time) 3)))
                  (while (and (> (length (window-list)) 1)
                              (< (float-time) deadline))
                    (accept-process-output nil 0.02)))
                (should (= 1 (length (window-list))))
                (should (eq (window-buffer (selected-window))
                            (typing-agent-task-buffer task)))
                (should (typing-agent-test--wait task))
                (should (eq (typing-agent-task-status task) 'completed))
                ;; 默认不恢复布局：录制时画面保持单窗口。
                (should (= 1 (length (window-list))))
                (should (equal "public class A {\n    int value = 2;\n}\n"
                               (typing-agent-file-content file)))))
          (when (buffer-live-p other)
            (kill-buffer other)))))))

(ert-deftest typing-agent-test-task-ignores-restore-window-option ()
  ;; 任务结束不做任何恢复：即使显式传 restore_window，也停在
  ;; 任务最后编辑的 buffer，保持单窗口。
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n}\n"))
    (typing-agent-test-with-temp-file content
      (let ((other (generate-new-buffer " *typing-agent-other*")))
        (unwind-protect
            (progn
              (switch-to-buffer other)
              (split-window-below)
              (let* ((spec
                      (typing-agent-json-parse
                       (json-encode
                        (typing-agent-json-prepare
                         (list (cons :file file)
                               (cons :options
                                     (list :speed 30 :restore_window t))
                               (cons :operations
                                     (vconcat
                                      (list
                                       (list :type "replace_region"
                                             :search "public class A {\n}\n"
                                             :replace "public class A {\n    int x;\n}\n")
                                       (list :type "save_buffer")))))))))
                     (task (typing-agent-engine-submit spec)))
                (should (typing-agent-test--wait task))
                (should (eq (typing-agent-task-status task) 'completed))
                ;; 不恢复：仍然只有一个窗口，并停在任务 buffer。
                (should (= 1 (length (window-list))))
                (should (eq (window-buffer (selected-window))
                            (typing-agent-task-buffer task)))))
          (when (buffer-live-p other)
            (kill-buffer other)))))))

;;; 新建文件（dired）

(ert-deftest typing-agent-test-create-file-direct ()
  ;; 批处理里没有命令循环：仍然要创建文件、打开 buffer 并回调。
  (skip-unless (fboundp 'evil-mode))
  (let* ((dir (make-temp-file "typing-agent-create-" t))
         (file (expand-file-name "Brand.java" dir))
         (created nil))
    (unwind-protect
        (progn
          (should-not (file-exists-p file))
          (typing-agent-evil-create-file
           file (lambda (buffer) (setq created buffer)))
          (should (file-exists-p file))
          (should (buffer-live-p created))
          (should (equal (expand-file-name file)
                         (buffer-file-name created)))
          (should (zerop (buffer-size created)))
          (should (= 1 (length (window-list)))))
      (when (buffer-live-p created)
        (with-current-buffer created
          (set-buffer-modified-p nil))
        (kill-buffer created))
      (ignore-errors (delete-directory dir t)))))

(ert-deftest typing-agent-test-create-show-dired-and-keys ()
  ;; 打开父目录的 dired，并在该 buffer 里找到「新建空文件」的按键。
  (skip-unless (fboundp 'dired-noselect))
  (let* ((dir (make-temp-file "typing-agent-dired-" t))
         (buffer nil))
    (unwind-protect
        (progn
          (setq buffer (typing-agent-evil--create-show-dired dir))
          (should (typing-agent-evil--dired-mode-p buffer))
          (should (eq (window-buffer (selected-window)) buffer))
          (should (= 1 (length (window-list))))
          ;; Doom 的 dired 里新建空文件绑在 c；没绑定时退回 M-x 调用。
          (should (member (typing-agent-evil--create-keys)
                          (list (string-to-vector "c")
                                (kbd "M-x dired-create-empty-file RET")))))
      (when (and buffer (buffer-live-p buffer))
        (kill-buffer buffer))
      (ignore-errors (delete-directory dir t)))))

(ert-deftest typing-agent-test-task-creates-missing-file ()
  ;; 目标文件不存在时，任务先创建空文件，再编辑并保存。
  (skip-unless (fboundp 'evil-mode))
  (let* ((dir (make-temp-file "typing-agent-create-task-" t))
         (file (expand-file-name "Fresh.java" dir))
         (buffer nil)
         (task nil))
    (unwind-protect
        (progn
          (should-not (file-exists-p file))
          (let* ((spec
                  (typing-agent-json-parse
                   (json-encode
                    (typing-agent-json-prepare
                     (list (cons :file file)
                           (cons :options (list :speed 30))
                           (cons :operations
                                 (vconcat
                                  (list
                                   (list :type "enter_insert")
                                   (list :type "type_text"
                                         :text "public class Fresh {\n    int fresh = 1;\n}\n")
                                   (list :type "exit_insert")
                                   (list :type "save_buffer"))))))))))
                 (setq task (typing-agent-engine-submit spec)))
          ;; 任务在创建文件时就开始占住执行权。
          (should (eq (typing-agent-task-status task) 'pending))
          (should (typing-agent-test--wait task))
          (should (eq (typing-agent-task-status task) 'completed))
          (should (file-exists-p file))
          (should (equal "public class Fresh {\n    int fresh = 1;\n}\n"
                         (typing-agent-file-content file)))
          (setq buffer (typing-agent-task-buffer task))
          (should (buffer-live-p buffer))
          (should (eq (window-buffer (selected-window)) buffer))
          (should (= 1 (length (window-list)))))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          (set-buffer-modified-p nil))
        (kill-buffer buffer))
      (ignore-errors (delete-directory dir t)))))

;;; HTTP（在测试端口上临时启动服务）

(defun typing-agent-test--http (method path &optional body token)
  "向测试服务发送请求，返回 (STATUS BODY-STRING)。
BODY 为字符串时按 JSON 发送；TOKEN 为 nil 时使用当前 token。"
  (let* ((proc (open-network-stream "typing-agent-test-client"
                                    (format " *typing-agent-test-%d*"
                                            (random 100000))
                                    "127.0.0.1" typing-agent-server-port))
         (payload (and body (encode-coding-string body 'utf-8)))
         (head (concat
                (format "%s %s HTTP/1.1\r\n" method path)
                "Host: 127.0.0.1\r\n"
                "Connection: close\r\n"
                (format "Authorization: Bearer %s\r\n"
                        (or token (typing-agent-token)))
                (if payload
                    (format "Content-Type: application/json\r\nContent-Length: %d\r\n"
                            (string-bytes payload))
                  "")
                "\r\n")))
    (unwind-protect
        (progn
          (set-process-coding-system proc 'binary 'binary)
          (process-send-string proc (encode-coding-string head 'utf-8))
          (when payload
            (process-send-string proc payload))
          (let ((deadline (+ (float-time) 10)))
            (while (and (process-live-p proc)
                        (< (float-time) deadline))
              (accept-process-output proc 0.05))
            (accept-process-output nil 0.05))
          (let ((data (with-current-buffer (process-buffer proc)
                        (buffer-string))))
            (unless (string-match "\r\n\r\n" data)
              (error "响应不完整: %S" data))
            (let* ((head-end (match-beginning 0))
                   (head-text (substring data 0 head-end))
                   (body-text (substring data (+ head-end 4))))
              (unless (string-match "\\`HTTP/1\\.1 \\([0-9]+\\)" head-text)
                (error "无法解析状态行: %S" head-text))
              (let ((status (string-to-number (match-string 1 head-text))))
                ;; 只取 Content-Length 声明的字节数，避免进程消息混进 body。
                (when (string-match "\r\nContent-Length: *\\([0-9]+\\)" head-text)
                  (let ((length (string-to-number (match-string 1 head-text))))
                    (when (> (length body-text) length)
                      (setq body-text (substring body-text 0 length)))))
                (list status
                      (decode-coding-string body-text 'utf-8))))))
      (when (process-live-p proc)
        (delete-process proc))
      (when (buffer-live-p (process-buffer proc))
        (kill-buffer (process-buffer proc))))))

(defmacro typing-agent-test-with-server (&rest body)
  "在测试端口启动服务并执行 BODY，结束后关闭。
如果当前进程已经有服务在运行，跳过测试，避免影响真实服务。"
  (declare (indent 0))
  `(if (typing-agent-server-running-p)
       (ert-skip "已有服务在运行，跳过 HTTP 测试")
     (let ((typing-agent-server-port 18766))
       (unwind-protect
           (progn
             (typing-agent-server-start)
             ,@body)
         (typing-agent-server-stop)))))

(ert-deftest typing-agent-test-server-token-file ()
  (should (stringp (typing-agent-token)))
  (should (> (length (typing-agent-token)) 16))
  (should (file-exists-p (typing-agent-token-file-path))))

(ert-deftest typing-agent-test-server-unauthorized ()
  (typing-agent-test-with-server
    (let ((result (typing-agent-test--http "GET" "/status" nil "wrong-token")))
      (should (= 401 (car result)))
      (should (string-match-p "\"ok\":false" (cadr result))))))

(ert-deftest typing-agent-test-server-status ()
  (typing-agent-test-with-server
    (let ((result (typing-agent-test--http "GET" "/status")))
      (should (= 200 (car result)))
      (let* ((json (typing-agent-json-parse (cadr result)))
             (server (plist-get json :server)))
        (should (eq t (plist-get json :ok)))
        (should (equal typing-agent-version (plist-get json :version)))
        (should (eq t (plist-get server :running)))
        (should (= typing-agent-server-port (plist-get server :port)))))))

(ert-deftest typing-agent-test-server-buffer ()
  (typing-agent-test-with-server
    (let ((result (typing-agent-test--http "GET" "/buffer")))
      (should (= 200 (car result)))
      (let ((json (typing-agent-json-parse (cadr result))))
        (should (eq t (plist-get json :ok)))
        (should (stringp (plist-get json :buffer)))))))

(ert-deftest typing-agent-test-server-task-lifecycle ()
  (skip-unless (fboundp 'evil-mode))
  (let ((content "public class A {\n    int value = 1;\n}\n"))
    (typing-agent-test-with-temp-file content
      (typing-agent-test-with-server
        (let* ((request (json-encode
                         (typing-agent-json-prepare
                          (list (cons :file file)
                                (cons :operations
                                      (vconcat
                                       (list (list :type "replace_region"
                                                   :search "    int value = 1;\n"
                                                   :replace "    int value = 42;\n")
                                             (list :type "save_buffer"))))))))
               (submit (typing-agent-test--http "POST" "/task" request)))
          (should (= 202 (car submit)))
          (let* ((json (typing-agent-json-parse (cadr submit)))
                 (id (plist-get json :id)))
            (should (stringp id))
            (should (= 2 (plist-get json :total)))
            ;; 轮询任务直到结束
            (let ((status nil))
              (dotimes (_ 200)
                (unless (member status '("completed" "failed" "cancelled"))
                  (let* ((result (typing-agent-test--http
                                  "GET" (format "/task/%s" id)))
                         (task (typing-agent-json-parse (cadr result))))
                    (setq status (plist-get task :status))
                    (unless (member status '("completed" "failed" "cancelled"))
                      (accept-process-output nil 0.05)))))
              (should (equal "completed" status)))
            (should (equal "public class A {\n    int value = 42;\n}\n"
                           (typing-agent-file-content file)))
            ;; 撤销
            (let ((undo (typing-agent-test--http "POST" "/undo"
                                                 (format "{\"id\":\"%s\"}" id))))
              (should (= 200 (car undo)))
              (should (equal content
                             (with-current-buffer
                                 (typing-agent-task-buffer
                                  (typing-agent-task-get id))
                               (buffer-substring-no-properties
                                (point-min) (point-max)))))
              ;; 撤销必须同步写回文件，不能只改 buffer。
              (should (equal content (typing-agent-file-content file))))))))))

(ert-deftest typing-agent-test-server-diff ()
  (typing-agent-test-with-server
    (let* ((request (json-encode
                     (typing-agent-json-prepare
                      (list (cons :diff typing-agent-test--java-diff)
                            (cons :base_dir "/tmp")))))
           (result (typing-agent-test--http "POST" "/diff" request)))
      (should (= 200 (car result)))
      (let* ((json (typing-agent-json-parse (cadr result)))
             (specs (plist-get json :specs)))
        (should (vectorp specs))
        (should (= 1 (length specs)))
        (let ((spec (aref specs 0)))
          (should (equal "/tmp/src/main/java/UserService.java"
                         (plist-get spec :file)))
          (should (vectorp (plist-get spec :operations)))
          (should (> (length (plist-get spec :operations)) 3)))))))

(ert-deftest typing-agent-test-server-tasks-list ()
  (typing-agent-test-with-server
    (let ((result (typing-agent-test--http "GET" "/tasks")))
      (should (= 200 (car result)))
      (let ((json (typing-agent-json-parse (cadr result))))
        (should (eq t (plist-get json :ok)))
        (should (vectorp (plist-get json :tasks)))))))

(ert-deftest typing-agent-test-server-unknown-route ()
  (typing-agent-test-with-server
    (let ((result (typing-agent-test--http "GET" "/nope")))
      (should (= 404 (car result)))
      (should (string-match-p "\"ok\":false" (cadr result))))))

;;; 补全
(ert-deftest typing-agent-test-completion-trigger-char ()
  (should (typing-agent-completion-trigger-char-p ?.))
  (should (typing-agent-completion-trigger-char-p ?a))
  (should (typing-agent-completion-trigger-char-p ?Z))
  (should (typing-agent-completion-trigger-char-p ?_))
  (should (typing-agent-completion-trigger-char-p ?$))
  (should-not (typing-agent-completion-trigger-char-p ?\s))
  (should-not (typing-agent-completion-trigger-char-p ?\())
  (should-not (typing-agent-completion-trigger-char-p ?\;)))

(ert-deftest typing-agent-test-completion-check-position ()
  (let ((line "System.out.pri"))
    ;; 输入点号后，后面是 p，值得等成员补全。
    (should (typing-agent-completion-check-position-p line 11 ?.))
    ;; 输入 r 后，后面还是 i，仍在同一个标识符里。
    (should (typing-agent-completion-check-position-p line 13 ?r))
    ;; 行尾和单词结束都不检查。
    (should-not (typing-agent-completion-check-position-p
                 line (length line) ?i)))
  (should-not (typing-agent-completion-check-position-p "System." 7 ?.))
  (should-not (typing-agent-completion-check-position-p "foo.(" 4 ?.))
  (should-not (typing-agent-completion-check-position-p "a " 1 ?a)))

(ert-deftest typing-agent-test-completion-word-start ()
  (let ((line "System.out.pri"))
    ;; p 前面是点号，是词首。
    (should (typing-agent-completion-word-start-p line 12 ?p))
    ;; r 前面还是 p（标识符），不是词首。
    (should-not (typing-agent-completion-word-start-p line 13 ?r))
    ;; 点号本身不是词首。
    (should-not (typing-agent-completion-word-start-p line 11 ?.)))
  ;; 行首第一个字符是词首。
  (should (typing-agent-completion-word-start-p "print" 1 ?p))
  (should-not (typing-agent-completion-word-start-p "print" 2 ?r)))

(ert-deftest typing-agent-test-completion-fit ()
  (let ((line "        System.out.println(\"hello\");"))
    ;; "pri" 已经输入，候选 println 正好补上剩下的字符。
    (should (= 26 (typing-agent-completion--fit line 19 "println" 3)))
    ;; 候选自带括号，不是目标文本的前缀，必须拒绝。
    (should-not (typing-agent-completion--fit line 19 "println()" 3))
    ;; 候选没有变长，选中没有意义。
    (should-not (typing-agent-completion--fit line 19 "pri" 3))
    ;; 候选与目标文本分叉。
    (should-not (typing-agent-completion--fit line 19 "outx" 3))
    ;; 空候选、多行候选都不接受。
    (should-not (typing-agent-completion--fit line 19 "" 3))
    (should-not (typing-agent-completion--fit line 19 "pri\nnt" 3))
    ;; 起点越界。
    (should-not (typing-agent-completion--fit line (length line) "x" 0))))

(ert-deftest typing-agent-test-completion-plain-text ()
  (let* ((item '(:label "println(String x) : void"
                 :insertText "println"
                 :insertTextFormat 2
                 :textEdit (:newText "println(${1:x});")
                 :additionalTextEdits ((:newText "import java.io.*;"))
                 :command (:command "java.completion.onDidSelect")
                 :data (:pid 1)))
         (candidate (propertize "println(String x) : void"
                                'eglot--lsp-item item))
         (clean (typing-agent-completion--clean-item item))
         (string (typing-agent-completion--insert-string "println" item)))
    (should (equal "println" (typing-agent-completion--plain-text candidate)))
    (should (equal "plain"
                   (typing-agent-completion--plain-text "plain")))
    (should (equal "println" (plist-get clean :insertText)))
    (should-not (plist-get clean :textEdit))
    (should-not (plist-get clean :insertTextFormat))
    (should-not (plist-get clean :command))
    (should-not (plist-get clean :data))
    ;; import 默认开启：additionalTextEdits 保留，选中后随候选一起应用。
    (should (plist-get clean :additionalTextEdits))
    ;; 显式关闭 import 时才清掉 additionalTextEdits，保持逐字符精确。
    (let ((typing-agent-completion-import nil))
      (should-not (plist-get
                   (typing-agent-completion--clean-item item)
                   :additionalTextEdits)))
    (should (equal clean (get-text-property 0 'eglot--lsp-item string)))
    (should (equal "println" (substring-no-properties string)))))

(ert-deftest typing-agent-test-completion-option ()
  (should (eq t (alist-get :completion (typing-agent-engine-parse-options nil))))
  (should-not (alist-get :completion
                         (typing-agent-engine-parse-options
                          '(:options (:completion :false))))))

(ert-deftest typing-agent-test-import-line-p ()
  ;; import 行一次性写入的判定。
  (should (typing-agent-engine--import-line-p "import java.util.List;"))
  (should (typing-agent-engine--import-line-p "import static foo.Bar.baz;"))
  (should (typing-agent-engine--import-line-p "import ("))
  (should (typing-agent-engine--import-line-p "  import com.x.Y;"))
  (should-not (typing-agent-engine--import-line-p "public class A {"))
  (should-not (typing-agent-engine--import-line-p "imports x"))
  (should-not (typing-agent-engine--import-line-p "")))

(ert-deftest typing-agent-test-keycast-event-text ()
  ;; 特殊键与 KeyCastr 自己的显示保持一致。
  (should (equal (typing-agent-keycast--event-text ?a) "a"))
  (should (equal (typing-agent-keycast--event-text ?\s) "␣"))
  (should (equal (typing-agent-keycast--event-text ?\t) "⇥"))
  (should (equal (typing-agent-keycast--event-text ?\r) "⏎"))
  (should (equal (typing-agent-keycast--event-text ?\n) "⏎"))
  (should (equal (typing-agent-keycast--event-text ?\d) "⌫"))
  (should (equal (typing-agent-keycast--event-text ?\e) "⎋"))
  (should (equal (typing-agent-keycast--event-text ?\C-g) "C-g"))
  (should (equal (typing-agent-keycast--event-text 'tab) "⇥"))
  (should (equal (typing-agent-keycast--event-text 'return) "⏎"))
  (should-not (typing-agent-keycast--event-text ?中))
  (dolist (char (string-to-list "中文繁體𠀀，。！？：；（）【】《》“”‘’、—…"))
    (should-not (typing-agent-keycast--event-text char)))
  (dolist (char (string-to-list "aZ09_{}[]();,.!?é"))
    (should (equal (typing-agent-keycast--event-text char)
                   (char-to-string char)))))

(ert-deftest typing-agent-test-keycast-mirror-text ()
  ;; 用真正的数据报 socket 走一遍协议，确认 KeyCastr 收到 JSON 行。
  (let* ((path (make-temp-file "typing-agent-keycast-" nil ".sock"))
         (received nil)
         (typing-agent-keycast-socket path)
         (typing-agent-keycast-enabled t)
         (typing-agent-keycast--process nil)
         (typing-agent-keycast--attempt nil)
         (server nil))
    (unwind-protect
        (progn
          ;; bind 之前必须把 make-temp-file 建出来的普通文件删掉。
          (delete-file path)
          (setq server
                (make-network-process
                 :name "typing-agent-keycast-test"
                 :family 'local :service path :server t :type 'datagram
                 :noquery t :coding 'utf-8-unix
                 :filter (lambda (_process string) (push string received))))
          (typing-agent-keycast-mirror-text "a中文，。 ")
          (typing-agent-keycast-mirror-events (vector ?\r ?中 ?\t))
          (typing-agent-keycast-mirror-events (list ?文 ?！))
          (accept-process-output nil 1.0)
          (let ((payload (apply #'concat (nreverse received))))
            (should (string-match-p "\"text\":\"a\"" payload))
            (should (string-match-p "\"text\":\"␣\"" payload))
            (should (string-match-p "\"text\":\"⏎\"" payload))
            (should (string-match-p "\"text\":\"⇥\"" payload))
            (should (= 4 (length (split-string payload "\n" t))))
            (should-not (string-match-p "[中文，。！]" payload))))
      (when (process-live-p typing-agent-keycast--process)
        (delete-process typing-agent-keycast--process))
      (when (process-live-p server)
        (delete-process server))
      (ignore-errors (delete-file path)))))

(ert-deftest typing-agent-test-keycast-disabled ()
  (let ((typing-agent-keycast-enabled nil)
        (typing-agent-keycast--process nil)
        (typing-agent-keycast--attempt nil))
    (typing-agent-keycast-mirror-text "abc")
    (should-not typing-agent-keycast--process)))

(ert-deftest typing-agent-test-keycast-missing-socket ()
  ;; KeyCastr 没开时静默降级，并且退避期内不反复尝试连接。
  (let* ((path (concat (make-temp-file "typing-agent-keycast-missing-") ".sock"))
         (typing-agent-keycast-socket path)
         (typing-agent-keycast-enabled t)
         (typing-agent-keycast--process nil)
         (typing-agent-keycast--attempt nil))
    (unwind-protect
        (progn
          (should-not (typing-agent-keycast-connected-p))
          (typing-agent-keycast-mirror-text "ab")
          (should-not typing-agent-keycast--process)
          (should (floatp typing-agent-keycast--attempt)))
      (ignore-errors (delete-file path)))))

(provide 'typing-agent-test)
;;; typing-agent-test.el ends here
