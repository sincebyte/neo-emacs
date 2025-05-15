;;; keymap.el -*- lexical-binding: t; -*-
                                        ;
(after! dired
  (map! :map dired-mode-map
        :n "c" nil
        "c" nil))
(after! dired
  (map! :map dired-mode-map
        :n "c" #'dired-create-empty-file))

(map! :leader :n "o T" nil)
(map! :leader :n "o T" #'my/vterm-with-dir-and-file-name)
(map! :leader :desc "Open terminal" "o t" nil)
(map! :leader :desc "Open terminal" "o t" #'shell/openAndResetCursor)
