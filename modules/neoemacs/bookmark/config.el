;;; neoemacs/bookmark/config.el -*- lexical-binding: t; -*-
;;;
(use-package bookmark+
  :defer t
  :after bookmark
  :init (setq-default bookmark-save-flag 1)
        (setq bookmark-default-file (concat org-roam-directory "/emacs/command/doom/config/bookmark")))
