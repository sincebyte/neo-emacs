;;; neoemacs/rime/config.el -*- lexical-binding: t; -*-

;; (setq rime-user-data-dir             "~/Library/Rime/"                               ;; rime config input method setting
;;       ;; rime-librime-root              (concat doom-user-dir "neoemacs/rime-macos/dist")  ;; emacs-rime/blob/master/INSTALLATION.org
;;       rime-librime-root (concat "" "/opt/homebrew/Cellar/librime/1.15.0")
;;       rime-emacs-module-header-root  "/Applications/Emacs.app/Contents/Resources/include"           ;; for emacs rime, brew do not needed
;;       ;; rime-emacs-module-header-root  "/Applications/Emacs.app/Contents/Resources/include"                          ;; for emacs rime, brew do not needed
;;       )
;; ;; just install emacs first https://rime.im
;; (use-package! rime
;;   :defer t
;;   :config
;;   (setq rime-user-data-dir             "~/Library/Rime")
;;   (setq rime-show-candidate 'minibuffer)
;;   (setq rime-translate-keybindings '("C-n" "C-p" "<left>" "<right>" "<up>" "<down>"))
;;   :custom
;;   (setq rime-librime-root "/opt/homebrew/Cellar/librime/1.15.0/"
;;         rime-emacs-module-header-root  "/Applications/Emacs.app/Contents/Resources/include")
;;   ;; (rime-emacs-module-header-root emacs-module-root)
;;   (default-input-method "rime"))
;; (setq mode-line-mule-info   '((:eval (rime-lighter)))
;;       rime-title "CH"
;;       rime-inline-ascii-trigger 'shift-l
;;       rime-disable-predicates '(rime-predicate-after-alphabet-char-p
;;                                 rime-predicate-space-after-cc-p))


;; ;; 输入法切换按键
;; (global-set-key (kbd "C-,"  ) 'toggle-input-method             )
;; (global-unset-key (kbd "C-;"))
;; (global-set-key (kbd "C-;"  ) nil             )

;; (map! :map (minibuffer-local-map)
;;       "C-," 'toggle-input-method)

;; (defun my/mac-switch-to-english ()
;;   "切换到系统英文输入法"
;;   (call-process "macism" nil 0 nil
;;                 "com.apple.keylayout.ABC"))

;; (defun my/mac-switch-to-chinese ()
;;   "切换到系统中文输入法（Squirrel / Rime）"
;;   (call-process "macism" nil 0 nil
;;                 "im.rime.inputmethod.Squirrel.Hans"))
(defun my/mac-switch-to-abc ()
  (interactive)
  (start-process
   "hs-abc"
   nil
   "hs"
   "-c"
   "hs.keycodes.currentSourceID(\"com.apple.keylayout.ABC\")"))

(defun my/mac-switch-to-rime ()
  (interactive)
  (start-process
   "hs-rime"
   nil
   "hs"
   "-c"
   "hs.keycodes.currentSourceID(\"im.rime.inputmethod.Squirrel.Hans\")"))

(with-eval-after-load 'evil
  (add-hook 'evil-insert-state-entry-hook #'my/mac-switch-to-rime)
  (add-hook 'evil-insert-state-exit-hook #'my/mac-switch-to-abc)
  (add-hook 'minibuffer-setup-hook #'my/mac-switch-to-rime)
  (add-hook 'minibuffer-exit-hook #'my/mac-switch-to-abc))
