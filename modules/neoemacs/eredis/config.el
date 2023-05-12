;;; neoemacs/eredis/config.el -*- lexical-binding: t; -*-

;; usage
;; (eredis-print-hash (json-parse-string (eredis-get "identity:user:jwt:30400")))
;; (json--print (eredis-get "center-identity:user:jwt:30400"))

(use-package eredis)

(defun eredis/get (key)
  (eredis-print-hash (json-parse-string (eredis-get key)))
  (princ (format "***SUCCESS GET*** %s" key)) (comint-previous-input 1))

(defun eredis-print-hash (hashtable)
  "Prints the hashtable, each line is key, val"
  (if (typep hashtable 'hash-table)
    (maphash (lambda (k v) (princ (format "%s: %s\n" k v))) hashtable)
    (princ hashtable)))
