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
  (web-mode-markup-indent-offset 2)
  (web-mode-css-indent-offset 2)
  (web-mode-code-indent-offset 2))

;; fornt setting
(after! lsp-mode
  ;; 彻底禁用 deno
  (setq lsp-deno-enable nil)
  (setq lsp-clients-deno-enable nil)
  (setq lsp-disabled-clients '(deno-ls)))
(after! css-mode
  (setq css-indent-offset 2))
