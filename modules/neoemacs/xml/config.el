;;; neoemacs/xml/config.el -*- lexical-binding: t; -*-
;;
;; environment variable controls the indentation. The value is 4 spaces
(setenv "XMLLINT_INDENT" "    ")
(use-package xml-format
  :demand t
  :defer t
  :after nxml-mode)
