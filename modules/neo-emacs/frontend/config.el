;;; neoemacs/frontend/config.el -*- lexical-binding: t; -*-
;;;
(add-hook 'web-mode-hook (lambda ()
                           (rainbow-delimiters-mode)
                           (setq display-line-numbers                       t
                                 lsp-modeline-code-actions-enable           nil
                                 doom-modeline-icon                         nil)))
(add-hook 'js-mode-hook (lambda ()
                          (focus-mode                                       nil)
                          (rainbow-delimiters-mode)
                          (setq display-line-numbers                        t)))

(setq-hook! 'web-mode-hook indent-tabs-mode nil)
(use-package web-mode
  :defer t
  :custom
  (lsp-enable-file-watchers       t)
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

(after! lsp-mode
  ;; 自动开启 lsp
  (add-hook 'vue-mode-hook #'lsp)

  ;; 忽略 Volar 的一些提示（可选）
  (setq lsp-vue-language-server-command '("vue-language-server" "--stdio"))
  ;; 延迟请求，避免超时
  (setq lsp-idle-delay 0.500)
  ;; 禁用不必要的额外文本编辑
  (setq lsp-completion-enable-additional-text-edit nil))
