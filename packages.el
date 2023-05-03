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
(add-to-list 'load-path "/usr/local/bin")
(after! warnings(add-to-list 'warning-suppress-types '(yasnippet backquote-change)))
(unpin!   org-roam          )
(package! org-roam          )
(package! org-roam-ui       )
(package! xml-format        )
(package! org-fragtog       )
(package! org-appear        )
(package! tree-sitter       )
(package! eredis            )
(package! shrface           )
(package! lsp-java          )
(package! rime              )
(package! jq-mode           )
(package! zygospore         )
(package! undo-tree         )
(package! company           )
(package! ejc-sql           )
(package! vterm             )
(package! general           )
(package! doom-snippets     )
(package! yaml-mode         )
(package! expand-region     )
(package! go-translate      )
(package! ob-sql-mode       )
(package! string-inflection )
(package! tree-sitter-langs )
(package! auto-complete     )

;; (package! ejc-sql    :recipe (:host github :repo "vanniuner/ejc-sql"         :branch "master" ))
(package! bookmark+  :recipe (:host github :repo "emacsmirror/bookmark-plus" :branch "master" ))
(package! org-appear :recipe (:host github :repo "awth13/org-appear"         :branch "master" ))

;; 禁用的包
(package! mml           :disable t)
(package! semantic      :disable t)
(package! log-edit      :disable t)
(package! browse-url    :disable t)
(package! dap-java      :disable t)

(unpin! lsp-mode lsp-java)
