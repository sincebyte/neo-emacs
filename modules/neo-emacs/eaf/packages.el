;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/modules/neo-emacs/eaf/packages.el

(package! eaf
  :recipe (:host github
           :repo "emacs-eaf/emacs-application-framework"
           :branch "master"
           :files ("*.el" "*.json" "*.py" "core" "app")))

(package! eaf-browser
  :recipe (:host github
           :repo "emacs-eaf/eaf-browser"
           :branch "master"
           :files (:defaults "*.py" "dependencies.json" "easylist.txt" "aria2-ng" "node_modules")))