;; -*- no-byte-compile: t; -*-
;;; neo-emacs/eglot/packages.el

;; Doom 的 (lsp +eglot) 会从 ELPA 再装一份 eglot/jsonrpc。
;; Emacs 29+ 已内置，两套并存时 mode-line 等会重复注册。
;; 强制只用内置版本，不再经 straight 安装。
(package! eglot :built-in t)
(package! jsonrpc :built-in t)
