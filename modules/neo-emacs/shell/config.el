(setenv "JAVA_HOME"          "/Users/van/soft/jdk/jbr/Contents/Home" )
(setenv "DYLD_LIBRARY_PATH"  "/Applications/Emacs.app/"              )
(setenv "PATH"       (concat "/Applications/Emacs.app/:" (getenv "PATH"    )))
(add-to-list 'exec-path      "/Applications/Emacs.app/"              )


(map! :n  "SPC r r"  'quickrun-shell      )
(map! :ne "SPC v v" 'projectile-run-vterm )
(map! :ne "SPC v o" 'vterm-send-stop      )
(map! :ne "SPC v s" 'vterm-send-start     )
