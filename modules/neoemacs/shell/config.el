;;; neoemacs/shell/config.el -*- lexical-binding: t; -*-
;; envirment setting
(setenv "SHELL"         "/usr/local/bin/fish")
(setenv "JAVA_8_HOME"   "/Users/van/soft/jdk/zulu8.58.0.13-ca-jdk8.0.312-macosx_aarch64/zulu-8.jdk/Contents/Home" )
(setenv "JAVA_HOME"     "/Users/van/soft/jdk/jbr/Contents/Home"                                                   )
(setenv "JAVA_17_HOME"  "/Users/van/soft/jdk/zulu17.40.19-ca-fx-jdk17.0.6-macosx_aarch64"                         )
(setenv "OJAVA_17_HOME" "/Users/van/soft/jdk/jdk-17.0.6.jdk/Contents/Home"                                       )
(setenv "JAVA_19_HOME"  "/Users/van/soft/jdk/zulu19.30.1/zulu-19.jdk/Contents/Home"                               )
(setenv "HOTSWAP_OPTS"  "-XX:HotswapAgent=fatjar -Xlog:redefine+class*=info"                                      )
(add-to-list 'exec-path "/opt/homebrew/bin//"                                                                 )

;; key map
(map! :n  "SPC r r"  'quickrun-shell      )
(map! :ne "SPC v v" 'projectile-run-vterm )
(map! :ne "SPC v o" 'vterm-send-stop      )
(map! :ne "SPC v s" 'vterm-send-start     )
(map! :n  "SPC e e" (lambda () (interactive)
                (switch-to-buffer "*eshell-quickrun*")
                (neotree-hide)
                (zygospore-delete-other-window)
                (evil-normal-state)
                (evil-goto-line)))
(map! :n  "SPC v e" (lambda () (interactive)
                (switch-to-buffer "*eshell-quickrun*")
                (evil-normal-state)))
(general-def 'insert vterm-mode-map "C-h" 'vterm-send-C-h  )

;; (defvar-keymap eshell-prompt-mode-map
;;                 "C-k" #'evil-scroll-up
;;                 "C-j" #'evil-scroll-down )

(map! :after eshell
      :map  eshell-prompt-mode-map
      :nv "C-k" nil
      :nv "C-j" nil)
(map! :after eshell
      :map  eshell-prompt-mode-map
      :nv "C-k"     #'evil-scroll-up
      :nv "C-j"     #'evil-scroll-down )
