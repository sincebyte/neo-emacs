;;; neoemacs/translate/config.el -*- lexical-binding: t; -*-

(use-package! gt :defer t               )
(map! :ne "; t"     'gt-translate )
(map! :ve "; t"     'gt-translate )

(after! gt
  (setq gt-langs '(en zh))
  (setq gt-default-translator
      (gt-translator :engines (gt-youdao-dict-engine)
                     :render (list (gt-insert-render  :if 'not-word )
                                   (gt-posframe-pop-render :if 'word     )))))
