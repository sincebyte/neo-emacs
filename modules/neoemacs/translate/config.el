;;; neoemacs/translate/config.el -*- lexical-binding: t; -*-

(use-package! go-translate                )

(map! :ne "; t"     'gts-do-translate                          )
(map! :ve "; t"     'gts-do-translate                          )

(map! :after go-translate
      :map evil-normal-state-map
      "q" nil)

(after! go-translate
 (setq gts-translate-list '(("en" "zh")))
 (setq gts-default-translator
 (gts-translator
 :picker  (gts-prompt-picker)
 :engines (list (gts-google-engine))
 :render  (gts-buffer-render)))
 :map gts-buffer-local-map "q" #'+popup/quit-window)
