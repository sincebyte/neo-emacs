;;; dotsk.el --- Babel Functions for dot            -*- lexical-binding: t; -*-

;; Copyright (C) 2009-2022 Free Software Foundation, Inc.

;; Author: Eric Schulte
;; Maintainer: Justin Abrahms <justin@abrah.ms>
;; Keywords: literate programming, reproducible research
;; URL: https://orgmode.org

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Org-Babel support for evaluating dot source code.
;;
;; For information on dot see https://www.graphviz.org/
;;
;; This differs from most standard languages in that
;;
;; 1) there is no such thing as a "session" in dot
;;
;; 2) we are generally only going to return results of type "file"
;;
;; 3) we are adding the "file" and "cmdline" header arguments
;;
;; 4) there are no variables (at least for now)

;;; Code:

(require 'org-macs)
(org-assert-version)
(defvar org-babel-default-header-args:dotsk
  '((:results . "file") (:exports . "results"))
  "Default arguments to use when evaluating a dot source block.")

(defun org-babel-expand-body:dotsk (body params)
  "Expand BODY according to PARAMS, return the expanded body."
  (let ((vars (org-babel--get-vars params)))
    (mapc
     (lambda (pair)
       (let ((name (symbol-name (car pair)))
	     (value (cdr pair)))
	 (setq body
	       (replace-regexp-in-string
		(concat "$" (regexp-quote name))
		(if (stringp value) value (format "%S" value))
		body
		t
		t))))
     vars)
    body))

(defun org-babel-execute:dotsk (body params)
  " This function is called by `org-babel-execute-src-block'."
  (let* ((out-file (cdr (or (assq :file params)
			    (error "You need to specify a :file parameter"))))
	 (cmdline (or (cdr (assq :cmdline params))))
	 (cmd (or (cdr (assq :cmd params)) (concat "node " doom-user-dir "neoemacs/sketchviz/sketch.js")))
	 (coding-system-for-read 'utf-8) ;use utf-8 with sub-processes
	 (coding-system-for-write 'utf-8)
	 (in-file (org-babel-temp-file "dotsk-")))
    (with-temp-file in-file
      (insert (org-babel-expand-body:dotsk body params)))
    (org-babel-eval
     (concat cmd
	     " " (org-babel-process-file-name in-file)
	     " " cmdline
	     " " (org-babel-process-file-name out-file)) "")
    nil)) ;; signal that output has already been written to file

(defun org-babel-prep-session:dotsk (_session _params)
  "Return an error because Dot does not support sessions."
  (error "Dot does not support sessions"))

(provide 'dotsk)
