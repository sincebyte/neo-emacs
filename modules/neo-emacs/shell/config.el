(setenv "JAVA_HOME"     "/Users/van/soft/jdk/jbr/Contents/Home"                                                   )
(add-to-list 'exec-path "/opt/homebrew/bin//"                                                                 )

(map! :n  "SPC r r"  'quickrun-shell      )
(map! :ne "SPC v v" 'projectile-run-vterm )
(map! :ne "SPC v o" 'vterm-send-stop      )
(map! :ne "SPC v s" 'vterm-send-start     )
