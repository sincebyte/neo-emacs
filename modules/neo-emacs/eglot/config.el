;;; neoemacs/eglot/config.el -*- lexical-binding: t; -*-
;;;
(setenv "XMLLINT_INDENT" "    ")
(use-package xml-format
  :demand t
  :defer t
  :after nxml-mode)

(use-package kind-icon
  :ensure t
  :after corfu
  :custom
  (kind-icon-blend-background t)
  :config
  (setq kind-icon-use-icons  nil
        kind-icon-blend-background nil
        corfu-count          7    )
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

(after! corfu
  (corfu-popupinfo-mode -1)              ; 强制禁用
  (set-face-attribute 'corfu-current nil :weight 'normal)
  (set-face-attribute 'corfu-default nil :background (face-background 'corfu-border nil t))
  (set-face-attribute 'corfu-border nil :background (face-background 'org-mode-line-clock nil t))
  (add-to-list 'corfu--frame-parameters '(vertical-scroll-bars . nil))
  (setq corfu-popupinfo-delay nil        ; 禁止延迟触发
        corfu-popupinfo-hide t           ; 隐藏可能残留的弹窗
        corfu-auto-delay          0.1
        corfu-auto-prefix         1
        corfu-right-margin-width  0.3
        corfu-border-width        2
        corfu-auto                t
        corfu-preselect           'first
        corfu-bar-width           0.5
        corfu-quit-at-boundary    nil
        corfu-quit-no-match       nil
        corfu-popupinfo-max-width 0      ; 确保弹窗尺寸为零
        corfu-popupinfo-max-height 0)
  (custom-set-faces!
    '(corfu-current :background "#2C3946" :foreground "#7BB6E2" :weight bold))
  (define-key corfu-map (kbd "<escape>") nil))

(with-eval-after-load 'vertico
  (keymap-set vertico-map "C-j" #'vertico-next)
  (keymap-set vertico-map "C-k" #'vertico-previous))

(setq-default flymake-no-changes-timeout 30)

(add-hook 'java-ts-mode-hook #'eglot-ensure)
(add-hook 'java-mode-hook #'eglot-ensure)

;; ;; ;; java key setting
(map! :nve "; c"     'comment-line                        )
(map! :ne  "; r"     'string-inflection-java-style-cycle  )
(map! :ne "SPC c I"  #'eglot-find-implementation )
(map! :map global-map "s-n" nil)
(unbind-key "c f" doom-leader-map)
(map! :after eglot
      :map eglot-mode-map
      :n "SPC f b" #'eglot-format-buffer
      :v "SPC c f" #'eglot-format
      :n "; i"     #'eglot-code-action-organize-imports
      :n "SPC t s" #'eglot)

(after! eglot
  (define-key doom-leader-map (kbd "c f") #'eglot-format))
