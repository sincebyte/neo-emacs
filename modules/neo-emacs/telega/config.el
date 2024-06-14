(setq telega-server-libs-prefix "/opt/homebrew/opt/tdlib")
(use-package telega
  :commands (telega)
  :defer t
  :init
  (setq telega-proxies (list '(:server "127.0.0.1" :port 10886 :enable t :type (:@type "proxyTypeSocks5"))))
  (setq telega-chat-show-avatars nil)
  ;;(setq telega-avatar-text-function )
  ;;  (setq telega-avatar-factors-alist
  ;;        '((1 . (0.7 . 0.1))
  ;;         (2 . (0.7 . 0.1)))
  )
