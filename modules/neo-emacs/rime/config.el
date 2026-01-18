;;; neoemacs/rime/config.el -*- lexical-binding: t; -*-
(defun my/mac-switch-to-abc ()
  (interactive)
  (start-process "hs-abc" nil "hs" "-c" "hs.keycodes.currentSourceID(\"com.apple.keylayout.ABC\")"))

;; (defun my/mac-switch-to-rime ()
;;   (interactive)
;;   (start-process "hs-abc" nil "hs" "-c" "hs.keycodes.currentSourceID(\"com.apple.keylayout.ABC\")")
;;   (start-process "hs-rime" nil "hs" "-c" "hs.keycodes.currentSourceID(\"im.rime.inputmethod.Squirrel.Hans\")"))
(defun my/mac-switch-to-rime ()
  (interactive)
  (start-process "hs-abc" nil "hs" "-c" "hs.keycodes.currentSourceID(\"com.apple.keylayout.ABC\")")
  (run-at-time 0.1 nil (lambda ()
     (start-process "hs-rime" nil "hs" "-c" "hs.keycodes.currentSourceID(\"im.rime.inputmethod.Squirrel.Hans\")"))))

(defun my/switch-input-based-on-prev-char ()
  "根据光标前一个字符决定输入法。
如果前一个字符是中文或全角中文符号，切换到 Rime；否则切换到 ABC。"
  (let ((prev-char (char-before)))
    (if (and prev-char
             (or (and (>= prev-char #x4E00)   ;; 中文
                      (<= prev-char #x9FFF))
                 (and (>= prev-char #x3000)   ;; 中文标点和符号
                      (<= prev-char #x303F))
                 (and (>= prev-char #xFF00)   ;; 全角字符
                      (<= prev-char #xFFEF))))
        (my/mac-switch-to-rime)
      (my/mac-switch-to-abc))))

(with-eval-after-load 'evil
  (add-hook 'focus-in-hook #'my/mac-switch-to-abc)
  (add-hook 'evil-insert-state-entry-hook #'my/switch-input-based-on-prev-char)
  (add-hook 'evil-insert-state-exit-hook #'my/mac-switch-to-abc)
  (add-hook 'minibuffer-setup-hook #'my/mac-switch-to-abc)
  (add-hook 'minibuffer-exit-hook #'my/mac-switch-to-abc))

