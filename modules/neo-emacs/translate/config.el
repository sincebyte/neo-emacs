;;; neoemacs/translate/config.el -*- lexical-binding: t; -*-

(use-package! gt :defer t               )

                                        ;(setq gt-langs '(en zh))
                                        ;(setq gt-default-translator (gt-translator :engines (gt-youdao-dict-engine)))
(map! :ne "; t"     'gt-translate )
(map! :ve "; t"     'gt-translate )
;; (map! :ne "; y"     'gt-start gbuffer)
;;(map! :ne "; y"     'gt-start gt-buffer)
;; (map! :ne "; y"     'gt-go-buffer-translate)

;; (map! :ne "; y"     'gt-do-translate-buffer     )

(map! :after gt 
      :map evil-normal-state-map
      "q" nil)

(after! gt
  (setq gt-langs '(en zh))
  (setq gt-default-translator (gt-translator :engines (gt-youdao-dict-engine)))
  (setq gt-preset-translators
        `((default . ,(gt-translator
                       :taker   (gt-taker :text 'word :pick 'paragraph)
                       :engines (list (gt-youdao-dict-engine))
                       :render  (gt-render)))
          (gbuffer . ,(gt-translator
                       :taker   (gt-taker :text 'word :pick 'paragraph)
                       :engines (list (gt-youdao-dict-engine))
                       :render  (gt-buffer-render))))))
