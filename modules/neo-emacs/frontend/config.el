;;; neoemacs/frontend/config.el -*- lexical-binding: t; -*-
;;;
(add-hook 'web-mode-hook (lambda ()
                           (rainbow-delimiters-mode)
                           ;; `doom-modeline-icon'/`lsp-modeline-code-actions-enable'
                           ;; 是全局变量，用 setq 会把所有 buffer 的 icon 一起关掉，
                           ;; 这里只让 web-mode buffer 生效。
                           (setq display-line-numbers t)
                           (setq-local lsp-modeline-code-actions-enable nil
                                       doom-modeline-icon nil)))
(add-hook 'js-mode-hook (lambda ()
                          (focus-mode                                       nil)
                          (rainbow-delimiters-mode)
                          (setq display-line-numbers                        t)))

(setq-hook! 'web-mode-hook indent-tabs-mode nil)

;; `web-mode' 把 `font-lock-defaults' 设成 `('(web-mode-fontify) t)'（注意多了一层
;; quote），它的第 0 级关键字表其实是符号 `quote'。`common/config.el' 里把
;; `font-lock-maximum-decoration' 设成了 nil，即按第 0 级取表，于是 font-lock 会去
;; 求值 `(quote)'，报 “Invalid function: #<subr quote>”。该错误发生在
;; `web-mode-hook' 里首个开启 font-lock 的钩子上，导致 `run-mode-hooks' 中断：
;; 后续的 `emmet-mode'、以及整个 `after-change-major-mode-hook'（corfu、eglot、
;; font-lock、eldoc…）都不再执行，所以 .vue/.html 缓冲区里既没有补全也没有高亮。
;; 这里把关键字表补成标准形状（第 0 级 = 只有一个 web-mode-fontify 匹配器），
;; 效果与上游在 decoration level = t 时完全一致。
(defun my-web-mode-font-lock-defaults-fix ()
  "Fix `web-mode' font-lock keyword table for `font-lock-maximum-decoration' nil."
  (setq font-lock-defaults '(((web-mode-fontify)) t)))

;; 必须排在其它 `web-mode-hook' 之前（DEPTH 为负即靠前），否则等本函数执行时，
;; 前面的钩子已经开启 font-lock 并抛错、中断了整个钩子链。
(add-hook 'web-mode-hook #'my-web-mode-font-lock-defaults-fix -90)
(use-package web-mode
  :defer t
  :custom
  (lsp-enable-file-watchers       nil)
  (web-mode-markup-indent-offset  2)
  (web-mode-css-indent-offset     2)
  (web-mode-code-indent-offset    2))

;; fornt setting
(after! lsp-mode
  ;; 彻底禁用 deno
  (setq lsp-deno-enable nil)
  (setq lsp-clients-deno-enable nil)
  (setq lsp-disabled-clients '(deno-ls)))
(after! css-mode
  (setq css-indent-offset 2))

(defun my-vue-indent-setup ()
  (setq web-mode-markup-indent-offset 2)   ;; template/html
  (setq web-mode-css-indent-offset 2)      ;; style
  (setq web-mode-code-indent-offset 2)     ;; script/js
  (setq indent-tabs-mode nil)              ;; 使用空格
  ;; 额外指定 JS/TS 缩进
  (setq js-indent-level 2)
  (setq typescript-indent-level 2)
  ;; 禁用 electric-indent 避免 o/ O 自动缩进异常
  (electric-indent-local-mode -1))

(add-hook 'web-mode-hook 'my-vue-indent-setup)

;;; Vue
;; `.vue' 在 Doom 里默认走 `web-mode'，而 eglot 只按 major-mode 选择 server。
;; 这里派生一个专用 major mode，避免 html/php 等其它 web-mode 缓冲区也被接到
;; Vue Language Server 上。
(define-derived-mode my-vue-mode web-mode "Vue"
  "Major mode for Vue single-file components, based on `web-mode'.")

(add-to-list 'auto-mode-alist '("\\.vue\\'" . my-vue-mode))

(defun my-vue-typescript-lib-dir ()
  "Volar 的 tsdk 目录：全局 TypeScript 的 lib。"
  (expand-file-name "~/.npm-global/lib/node_modules/typescript/lib"))

(defun my-vue-eglot-init-options ()
  "Vue Language Server 的初始化参数。

`hybridMode' 必须显式关闭：开启时 Volar 会把 TypeScript 请求以
`tsserver/request' 发给 client，而 eglot 不做这层转发，补全会一直挂起。"
  (list :typescript (list :tsdk (my-vue-typescript-lib-dir))
        :vue (list :hybridMode :json-false)))

(after! eglot
  ;; 用 langId=vue 启动 Vue LS；eglot 的 MAJOR-MODES 支持 :language-id。
  (add-to-list 'eglot-server-programs
               (list (list 'my-vue-mode :language-id "vue")
                     "vue-language-server" "--stdio"
                     :initializationOptions (my-vue-eglot-init-options))))

(defun my-vue-eglot-setup ()
  (eglot-ensure))

(add-hook 'my-vue-mode-hook #'my-vue-eglot-setup)
