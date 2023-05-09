;;; neoemacs/eredis/config.el -*- lexical-binding: t; -*-

;; usage
;; (eredis-print-hash (json-parse-string (eredis-get "identity:user:jwt:30400")))
;; (json--print (eredis-get "center-identity:user:jwt:30400"))

(use-package eredis)

(defun eredis/get (key)
  (eredis-print-hash (json-parse-string (eredis-get key))))

(defun eredis-print-hash (hashtable)
  "Prints the hashtable, each line is key, val"
  (maphash
   (lambda (k v)
     (princ (format "%s: %s" k v))
     (princ "\n"))
   hashtable
   ))
