;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; To install a package with Doom you must declare them here, run 'doom sync' on
;; the command line, then restart Emacs for the changes to take effect.
;; Alternatively, use M-x doom/reload.
;;
;; WARNING: Disabling core packages listed in ~/.emacs.d/core/packages.el may
;; have nasty side-effects and is not recommended.


;; All of Doom's packages are pinned to a specific commit, and updated from
;; release to release. To un-pin all packages and live on the edge, do:
;(unpin! t)

;; ...but to unpin a single package:
;(unpin! pinned-package)
;; Use it to unpin multiple packages
;(unpin! pinned-package another-pinned-package)


;; To install SOME-PACKAGE from MELPA, ELPA or emacsmirror:
;(package! some-package)

;; To install a package directly from a particular repo, you'll need to specify
;; a `:recipe'. You'll find documentation on what `:recipe' accepts here:
;; https://github.com/raxod502/straight.el#the-recipe-format
;(package! another-package
;  :recipe (:host github :repo "username/repo"))

;; If the package you are trying to install does not contain a PACKAGENAME.el
;; file, or is located in a subdirectory of the repo, you'll need to specify
;; `:files' in the `:recipe':
;(package! this-package
;  :recipe (:host github :repo "username/repo"
;           :files ("some-file.el" "src/lisp/*.el")))

;; If you'd like to disable a package included with Doom, for whatever reason,
;; you can do so here with the `:disable' property:
;(package! builtin-package :disable t)

;; You can override the recipe of a built in package without having to specify
;; all the properties for `:recipe'. These will inherit the rest of its recipe
;; from Doom or MELPA/ELPA/Emacsmirror:
;(package! builtin-package :recipe (:nonrecursive t))
;(package! builtin-package-2 :recipe (:repo "myfork/package"))

;; Specify a `:branch' to install a package from a particular branch or tag.
;; This is required for some packages whose default branch isn't 'master' (which
;; our package manager can't deal with; see raxod502/straight.el#279)
;(package! builtin-package :recipe (:branch "develop"))
(package! lsp-java)
(package! dap-mode)
(package! ejc-sql)
(add-to-list 'load-path "/usr/local/bin")
(after! warnings(add-to-list 'warning-suppress-types '(yasnippet backquote-change)))
;; (package! db
;;  :recipe (:files ("~/.doom.d/myconfig/db.el")))
;; (package! db-work
 ;; :recipe (:files ("~/.doom.d/myconfig/db-work.el")))

;; (package! restclient-jq
;;  :recipe (:files ("~/.doom.d/myconfig/restclient-jq.el")))

;; Add it to load path
;; (require! netease-cloud-music)
;; (add-to-list 'load-path "~/.doom.d/modules/private/ou")
;; (add-to-list 'load-path "~/.emacs.d/myconfig")
;; (package! evil-fcitx
;;  :recipe (:files ("~/.doom.d/myconfig/evil-fcitx.el")))

;; (package! insert-translated-name
;;  :recipe (:files ("~/.doom.d/myconfig/insert-translated-name.el")))

;; (package! evil-fcitx)
;;(package! insert-translated-name)
;; (package! company-box :recipe (:host github :repo "yyoncho/company-box" :branch "size"))

;; (unpin! org-refile)
(package! rime)
(package! jq-mode)
(package! go-translate)
;;(package! google-translate)
(package! zygospore)
;;(package! undo-tree)
;; (package! lsp-pyright)
(package! string-inflection)
(package! company)
(package! ejc-sql)
;; (package! python-mode)
;; (package! ranger)
;; (package! telega)
(package! vterm)
(package! disable-mouse)
(package! general)
(package! org-roam)
;; (package! org-roam-server)
(package! doom-snippets)
(package! yaml-mode)
(package! expand-region)

;;(package! nimbus-theme)
;; (package! company-tabnine)
;; (package! tide)
;; (package! web-mode)
;; (package! meow)
;; (package! ejc-autocomplete)
;; (package! org-html-themify)
;; (package! org-roam
;;   :recipe (:host github :repo "org-roam/org-roam"))

(unpin!   org-roam)
(package! org-roam-ui)
(package! company-tabnine)
(package! indent-guide)
(package! beacon)
(package! yascroll)
