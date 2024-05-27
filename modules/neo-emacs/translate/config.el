;;; neoemacs/translate/config.el -*- lexical-binding: t; -*-

(use-package! go-translate :defer t               )

(map! :ne "; t"     'gt-do-translate                          )
(map! :ve "; t"     'gt-do-translate                          )

(map! :after go-translate
      :map evil-normal-state-map
      "q" nil)

(after! go-translate
  (setq gt-langs '(en zh))
  (setq gt-default-translator
        (gt-translator
         :taker   (gt-taker :text 'word :pick 'paragraph)
         :engines (list (gt-youdao-dict-engine))
         :render  (gt-render))))

;; open 4 workspace on startup
(setq +workspaces-main " SSH")
(defun open-my-workspaces ()
  (interactive)
  (+workspace/new " IDE")
  (+workspace/new " GPT")
  (+workspace/new " SQL")
  (+workspace/new " HTTP")
  (+workspace/new "󱗃 ORG")
  )
(add-hook 'window-setup-hook #'open-my-workspaces)
