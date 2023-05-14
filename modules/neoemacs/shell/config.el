;;; neoemacs/shell/config.el -*- lexical-binding: t; -*-
(setenv "JAVA_HOME" "/Users/van/soft/jbr/Contents/Home"        )
(add-to-list 'exec-path          "/opt/homebrew/bin//sbcl"     )

(map! :n "SPC r r"  'quickrun-shell                            )
(map! :ne "SPC v v" 'projectile-run-vterm                      )
(map! :ne "SPC v o" 'vterm-send-stop                           )
(map! :ne "SPC v s" 'vterm-send-start                          )
(general-def 'insert vterm-mode-map "C-h" 'vterm-send-C-h      )
