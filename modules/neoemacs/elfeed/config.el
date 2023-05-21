(use-package! elfeed
  :defer t
  :config
  (setq elfeed-feeds
        '(("https://www.archlinux.org/feeds/news/" archlinux)
          ("https://www.gnome.org/feed/" gnome)
          ("http://nullprogram.com/feed/" nullprog)
          ("https://planet.emacslife.com/atom.xml" emacs community)
          ("https://www.ecb.europa.eu/rss/press.html" economics eu)
          ("https://drewdevault.com/blog/index.xml" drew devault)
          ("https://news.ycombinator.com/rss" ycombinator news)
          ("https://www.phoronix.com/rss.php" phoronix)))
  (define-key evil-normal-state-map (kbd "RET") 'elfeed-search-show-entry))

(map! :ne "; i"     #'eww   )
(map! :ne "SPC o e" #'elfeed)
(map! :ne "SPC o w" (lambda () (interactive) (switch-to-buffer "*eww*")))
