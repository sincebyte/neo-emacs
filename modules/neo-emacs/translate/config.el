;;; neoemacs/translate/config.el -*- lexical-binding: t; -*-

(use-package! go-translate :defer t               )

(map! :ne "; t"     'gt-do-translate )
(map! :ve "; t"     'gt-do-translate )
;; (map! :ne "; y"     'gt-start gbuffer)
;;(map! :ne "; y"     'gt-start gt-buffer)
;; (map! :ne "; y"     'gt-go-buffer-translate)

;; (map! :ne "; y"     'gt-do-translate-buffer     )

(map! :after go-translate
      :map evil-normal-state-map
      "q" nil)

(after! go-translate
  (setq gt-langs '(en zh))
  (setq gt-preset-translators
        `((default . ,(gt-translator
                       :taker   (gt-taker :text 'word :pick 'paragraph)
                       :engines (list (gt-youdao-dict-engine))
                       :render  (gt-render)))
          (gbuffer . ,(gt-translator
                       :taker   (gt-taker :text 'word :pick 'paragraph)
                       :engines (list (gt-youdao-dict-engine))
                       :render  (gt-buffer-render))))))
