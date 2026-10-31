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
(require 'typing-agent-completion)
(require 'typing-agent-validator)
(require 'typing-agent-diff)
(require 'typing-agent-engine)
(require 'typing-agent-server)

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

(ert-deftest typing-agent-test-humanizer-typo-map ()
  (should (typing-agent-humanizer-typo-char ?a))
  (should-not (typing-agent-humanizer-typo-char ?中))
  (should-not (typing-agent-humanizer-typo-char ?\n)))

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
    (should-not (plist-get clean :additionalTextEdits))
    (should-not (plist-get clean :command))
    (should-not (plist-get clean :data))
    (should (equal clean (get-text-property 0 'eglot--lsp-item string)))
    (should (equal "println" (substring-no-properties string)))))

(ert-deftest typing-agent-test-completion-option ()
  (should (eq t (alist-get :completion (typing-agent-engine-parse-options nil))))
  (should-not (alist-get :completion
                         (typing-agent-engine-parse-options
                          '(:options (:completion :false))))))

(provide 'typing-agent-test)
;;; typing-agent-test.el ends here
