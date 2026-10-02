;;; neoemacs/rime/config.el -*- lexical-binding: t; -*-
;; 直接调用鼠须管（Squirrel / Rime）的命令行切换 Rime 自身的 ascii_mode，
;; 不再经由 Hammerspoon（hs）去切换系统输入源：
;;   英文 = --ascii  （Rime 的 ASCII 直通，等价于原来的系统 ABC）
;;   中文 = --nascii （Rime 正常中文输入）
;; 系统里现在只保留 Rime 一个输入源，所以链路是 Emacs → Squirrel CLI，更短。
;;
;; 注意：Squirrel CLI 作用于「当前激活的输入会话」，Emacs 在前台时即为 Emacs 的会话。

(defvar my/squirrel-cli "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
  "Squirrel 命令行可执行文件的路径。")

(defun my/rime-switch-to-ascii ()
  "切换到 Rime 英文（ASCII）模式。"
  (interactive)
  (start-process "rime-ascii" nil my/squirrel-cli "--ascii"))

(defun my/rime-switch-to-chinese ()
  "切换到 Rime 中文模式。"
  (interactive)
  (start-process "rime-chinese" nil my/squirrel-cli "--nascii"))

;; 兼容旧函数名（历史配置 / 其它模块可能引用）
(defalias 'my/mac-switch-to-abc #'my/rime-switch-to-ascii)
(defalias 'my/mac-switch-to-rime #'my/rime-switch-to-chinese)

(defun my/switch-input-based-on-prev-char ()
  "根据光标前一个字符决定输入法。
如果前一个字符是中文或全角中文符号，切换到 Rime 中文；否则切换到 Rime 英文（ASCII）。"
  (let ((prev-char (char-before)))
    (if (and prev-char
             (or (and (>= prev-char #x4E00)   ;; 中文
                      (<= prev-char #x9FFF))
                 (and (>= prev-char #x3000)   ;; 中文标点和符号
                      (<= prev-char #x303F))
                 (and (>= prev-char #xFF00)   ;; 全角字符
                      (<= prev-char #xFFEF))))
        (my/rime-switch-to-chinese)
      (my/rime-switch-to-ascii))))

(with-eval-after-load 'evil
  (add-hook 'focus-in-hook #'my/rime-switch-to-ascii)
  (add-hook 'evil-insert-state-entry-hook #'my/switch-input-based-on-prev-char)
  (add-hook 'evil-insert-state-exit-hook #'my/rime-switch-to-ascii)
  (add-hook 'minibuffer-setup-hook #'my/rime-switch-to-ascii)
  (add-hook 'minibuffer-exit-hook #'my/rime-switch-to-ascii))
