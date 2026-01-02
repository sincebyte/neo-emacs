;;; neoemacs/rime/config.el -*- lexical-binding: t; -*-
(defun my/mac-switch-to-abc ()
  (interactive)
  (call-process "hs" nil nil nil "-c" "hs.keycodes.currentSourceID(\"com.apple.keylayout.ABC\")"))

(defun my/mac-switch-to-rime ()
  (interactive)
  (call-process "hs" nil nil nil "-c" "hs.keycodes.currentSourceID(\"im.rime.inputmethod.Squirrel.Hans\")"))

(with-eval-after-load 'evil
  (add-hook 'evil-insert-state-entry-hook #'my/mac-switch-to-rime)
  (add-hook 'evil-insert-state-exit-hook #'my/mac-switch-to-abc)
  (add-hook 'minibuffer-setup-hook #'my/mac-switch-to-rime)
  (add-hook 'minibuffer-exit-hook #'my/mac-switch-to-abc))
