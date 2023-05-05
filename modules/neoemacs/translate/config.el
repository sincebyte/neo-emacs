;;; neoemacs/translate/config.el -*- lexical-binding: t; -*-

(use-package! go-translate                )

(map! :ne "; t"     'gts-do-translate                          )
(map! :ve "; t"     'gts-do-translate                          )

;; translate
;; (defun go-translate ()
;;   (interactive)
;;   (gts-translate (gts-translator
;;                   :picker  (gts-noprompt-picker :texter (gts-current-or-selection-texter) :single t)
;;                   :engines (gts-google-rpc-engine)
;;                   :render  (gts-buffer-render))))
(setq gts-default-translator (gts-translator
       :picker (gts-prompt-picker)
       :engines (list (gts-bing-engine))
       :render (gts-buffer-render))
      gts-translate-list     '(("en" "zh")))
