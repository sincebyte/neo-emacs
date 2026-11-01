;;; typing-agent-completion-test.el --- 补全选择回归测试 -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'corfu)
(require 'typing-agent-completion)
(require 'typing-agent-engine)

(ert-deftest typing-agent-completion-test-implicit-accept-real-key ()
  ;; 对照组重现 Corfu 在普通按键前提交 setId；保护组只输入 s。
  (dolist (protected '(nil t))
    (save-window-excursion
      (with-temp-buffer
        (switch-to-buffer (current-buffer))
        (insert ".")
        (setq-local corfu-preview-current 'insert)
        (let ((corfu--index 1)
              (corfu--preselect 0)
              (corfu--total 2)
              (corfu--base "")
              (corfu--candidates '("other" "setId("))
              (completion-in-region--data (list (copy-marker 2) (copy-marker 2 t)))
              (typing-agent-keycast-enabled nil))
          (unwind-protect
              (progn
                (when protected (typing-agent--quiesce-buffer))
                (add-hook 'pre-command-hook #'corfu--prepare nil t)
                ;; 保留真实 pre-command、替换文本和按键；只隔离会话退出回调。
                (cl-letf (((symbol-function 'corfu--done) #'ignore))
                  (typing-agent-evil-send-char ?s))
                (should (equal (buffer-string)
                               (if protected ".s" ".setId(s"))))
            (remove-hook 'pre-command-hook #'corfu--prepare t)
            (when protected
              (typing-agent--restore-buffer)
              (should (eq corfu-preview-current 'insert)))))))))

(ert-deftest typing-agent-completion-test-restore-settings ()
  (dolist (local '(nil t))
    (with-temp-buffer
      (when local
        (setq-local corfu-preview-current 'insert)
        (setq-local corfu-auto t))
      (let ((preview corfu-preview-current)
            (auto corfu-auto))
        (typing-agent--quiesce-buffer)
        (typing-agent--quiesce-buffer)
        (should-not corfu-preview-current)
        (should-not corfu-auto)
        (typing-agent--restore-buffer)
        (should (eq preview corfu-preview-current))
        (should (eq auto corfu-auto))
        (should (eq local (local-variable-p 'corfu-preview-current)))
        (should (eq local (local-variable-p 'corfu-auto)))))))

(ert-deftest typing-agent-completion-test-line-corruption-stops-before-next-line ()
  (with-temp-buffer
    (insert ".setId(setName(\"楼栋\")")
    (let ((state (list :lines '(".setName(\"楼栋\")" "next")
                       :index 0 :start (copy-marker 1))))
      (should-error (typing-agent-engine--lines-finish-line nil state)
                    :type 'typing-agent-verify-error)
      (should (= 0 (plist-get state :index))))))

(defun typing-agent-completion-test--candidate (text)
  "构造写入 TEXT 的 Eglot 候选。"
  (propertize text 'eglot--lsp-item (list :insertText text)))

(ert-deftest typing-agent-completion-test-navigate-and-insert ()
  (with-temp-buffer
    (insert "repo.f")
    (let* ((completion-in-region-mode t)
           (completion-in-region--data (list 6 7))
           (corfu--index -1)
           (corfu--preselect -1)
           (corfu--total 3)
           (corfu--input '("f" . 1))
           (corfu--base "")
           (corfu--metadata '(metadata))
           (corfu--hilit #'identity)
           (corfu--scroll 0)
           (corfu-preview-current nil)
           (corfu--candidates
            (mapcar #'typing-agent-completion-test--candidate
                    '("find" "findAll" "findById")))
           (events nil)
           (rendered-indices nil)
           (inserted nil))
      ;; 使用真实导航、exhibit 和候选排版，只替换最终窗口绘制。
      (cl-letf (((symbol-function 'corfu--popup-show)
                 (lambda (_pos _margin _width _lines &optional index &rest _)
                   (push index rendered-indices)))
                ((symbol-function 'typing-agent-keycast-mirror-event)
                 (lambda (event) (push event events)))
                ((symbol-function 'typing-agent-completion--select)
                 (lambda (plain _item beg)
                   (setq inserted plain)
                   (delete-region beg (point))
                   (insert plain))))
        (dotimes (_ 3)
          (should (eq 'navigating
                      (plist-get (typing-agent-completion-inspect
                                  "repo.findById(id)") :status)))
          (should (equal (buffer-string) "repo.f")))
        (let ((result (typing-agent-completion-inspect "repo.findById(id)")))
          (should (eq 'selected (plist-get result :status)))
          (should (= 13 (plist-get result :char-index)))
          (should (equal inserted "findById"))
          (should (equal (buffer-string) "repo.findById"))
          (should (equal (reverse rendered-indices) '(0 1 2)))
          (should (equal events '(down down down))))))))

(ert-deftest typing-agent-completion-test-first-ranked-match ()
  (with-temp-buffer
    (insert "repo.f")
    (let ((completion-in-region-mode t)
          (completion-in-region--data (list 6 7))
          (corfu--index 0)
          (corfu--candidates
           (mapcar #'typing-agent-completion-test--candidate
                   '("findById" "findById"))))
      (cl-letf (((symbol-function 'typing-agent-completion--select)
                 (lambda (_plain item _beg)
                   (should (eq item (typing-agent-completion--item
                                     (car corfu--candidates)))))))
        (should (eq 'selected
                    (plist-get (typing-agent-completion-inspect
                                "repo.findById(id)") :status))))
      (should (equal (buffer-string) "repo.f")))))

(ert-deftest typing-agent-completion-test-no-target ()
  (with-temp-buffer
    (insert "repo.f")
    (let ((completion-in-region-mode t)
          (completion-in-region--data (list 6 7))
          (corfu--index 0)
          (corfu--candidates
           (mapcar #'typing-agent-completion-test--candidate
                   '("find" "findAll"))))
     (should (eq 'rejected 
                  (plist-get (typing-agent-completion-inspect
                              "repo.findById(id)") :status)))
      (should (equal (buffer-string) "repo.f")))))

(ert-deftest typing-agent-completion-test-refresh-existing-session ()
  (require 'corfu-auto)
  (with-temp-buffer
    (insert "repo.f")
    (let ((completion-in-region-mode t)
          (completion-at-point-functions '(ignore))
          (events nil))
      (cl-letf (((symbol-function 'corfu-quit)
                 (lambda ()
                   (setq completion-in-region-mode nil)
                   (push 'quit events)))
                ((symbol-function 'eglot--capf-session-flush)
                 (lambda (&rest _) (push 'flush events)))
                ((symbol-function 'corfu-auto--complete-deferred)
                 (lambda (&rest _)
                   (should-not completion-in-region-mode)
                   (should (equal completion-at-point-functions
                                  '(eglot-completion-at-point)))
                   (should (= corfu-auto-prefix 1))
                   (push 'query events))))
        (typing-agent-completion-trigger)
        (should (equal (reverse events) '(quit flush query)))
        (should (equal completion-at-point-functions '(ignore)))))))

(ert-deftest typing-agent-completion-test-dot-without-stale-key-event ()
  (require 'corfu-auto)
  (with-temp-buffer
    (insert "repo.")
    (let ((completion-in-region-mode nil)
          (last-command-event ?x))
      (cl-letf (((symbol-function 'eglot--capf-session-flush) #'ignore)
                ((symbol-function 'corfu-auto--complete-deferred)
                 (lambda (&rest _) (should (= corfu-auto-prefix 0)))))
        (typing-agent-completion-trigger)))))

(ert-deftest typing-agent-completion-test-selection-threshold ()
  (with-temp-buffer
    (insert "repo.f")
    (let ((completion-in-region-mode t)
          (completion-in-region--data (list 6 7))
          (corfu--index 0)
          (corfu--candidates
           (mapcar #'typing-agent-completion-test--candidate
                    '("findAll" "find" "foo" "far" "format" "findById"))))
      (should (eq 'multiple
                  (plist-get (typing-agent-completion-inspect
                              "repo.findById(id)") :status)))
      (setq corfu--candidates (cdr corfu--candidates)
            corfu--index 4)
      (cl-letf (((symbol-function 'typing-agent-completion--select) #'ignore))
        (should (eq 'selected
                    (plist-get (typing-agent-completion-inspect
                                "repo.findById(id)") :status)))))))

(ert-deftest typing-agent-completion-test-top-five-navigation ()
  ;; 候选总数大于五，逐一覆盖前五项和两个导航方向。
  (dotimes (target-index 5)
    (dolist (initial-index '(-1 6))
      (with-temp-buffer
        (insert "repo.f")
        (let* ((completion-in-region-mode t)
               (completion-in-region--data (list 6 7))
               (corfu--index initial-index)
               (corfu--candidates
                (mapcar #'typing-agent-completion-test--candidate
                        '("find" "findAll" "foo" "far" "format" "filter" "fetch")))
               (events nil))
          (setf (nth target-index corfu--candidates)
                (typing-agent-completion-test--candidate "findById"))
          (cl-letf (((symbol-function 'corfu-next)
                     (lambda () (cl-incf corfu--index)))
                    ((symbol-function 'corfu-previous)
                     (lambda () (cl-decf corfu--index)))
                    ((symbol-function 'corfu--exhibit) #'ignore)
                    ((symbol-function 'typing-agent-keycast-mirror-event)
                     (lambda (event) (push event events)))
                    ((symbol-function 'typing-agent-completion--select)
                     (lambda (plain _item beg)
                       (should (= corfu--index target-index))
                       (delete-region beg (point))
                       (insert plain))))
            (dotimes (_ (abs (- initial-index target-index)))
              (should (eq 'navigating
                          (plist-get (typing-agent-completion-inspect
                                      "repo.findById(id)") :status)))
              (should (equal (buffer-string) "repo.f")))
            (let ((result (typing-agent-completion-inspect "repo.findById(id)")))
              (should (eq 'selected (plist-get result :status)))
              (should (= 13 (plist-get result :char-index)))
              (should (equal (buffer-string) "repo.findById")))
            (should (equal events
                           (make-list (abs (- initial-index target-index))
                                      (if (< initial-index target-index)
                                          'down 'up))))))))))

(provide 'typing-agent-completion-test)
;;; typing-agent-completion-test.el ends here
