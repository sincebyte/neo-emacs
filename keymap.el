;;; keymap.el -*- lexical-binding: t; -*-
                                        ;
(after! dired
  (map! :map dired-mode-map
        :n "c" nil
        "c" nil))
(after! dired
  (map! :map dired-mode-map
        :n "c" #'dired-create-empty-file))

(map! :leader :n "o t" nil)
(map! :leader :n "o t" #'my/vterm-with-dir-and-file-name)
(map! :leader :desc "Open terminal" "o t" nil)
(map! :leader :desc "Open terminal" "o t" #'shell/openAndResetCursor)
(map! :i "s-y"  nil)
(map! :i "s-y"  #'yank-from-kill-ring)
