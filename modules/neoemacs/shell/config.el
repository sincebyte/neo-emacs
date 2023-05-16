;;; neoemacs/shell/config.el -*- lexical-binding: t; -*-
;; envirment setting
(setenv "JAVA_8_HOME"   "/Users/van/soft/jdk/zulu8.58.0.13-ca-jdk8.0.312-macosx_aarch64/zulu-8.jdk/Contents/Home" )
(setenv "JAVA_HOME"     "/Users/van/soft/jdk/jbr/Contents/Home"                                                   )
(setenv "JAVA_17_HOME"  "/Users/van/soft/jdk/zulu17.40.19-ca-fx-jdk17.0.6-macosx_aarch64"                         )
(add-to-list 'exec-path "/opt/homebrew/bin//sbcl"                                                                 )

;; key map
(map! :n "SPC r r"  'quickrun-shell                        )
(map! :ne "SPC v v" 'projectile-run-vterm                  )
(map! :ne "SPC v o" 'vterm-send-stop                       )
(map! :ne "SPC v s" 'vterm-send-start                      )
(map! :n  "SPC v e" (lambda () (interactive)
                (switch-to-buffer "*eshell-quickrun*"))    )
(general-def 'insert vterm-mode-map "C-h" 'vterm-send-C-h  )
