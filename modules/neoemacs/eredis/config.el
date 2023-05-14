;;; neoemacs/eredis/config.el -*- lexical-binding: t; -*-

;; usage
;; (eredis-print-hash (json-parse-string (eredis-get "identity:user:jwt:30400")))
;; (json--print (eredis-get "center-identity:user:jwt:30400"))

(use-package eredis)

(defun redis/keys (keys)
  (eredis-keys keys))

(defun redis/get (key)
  (let ((timebegin (current-time))
        (redisvalue (eredis-get key)))
    (if redisvalue
    (eredis-print-hash (json-parse-string redisvalue))
    (princ "not exist"))
    (princ (format "\n***SUCCESS GET*** %s" key))
    (format "duration %s s" (time-convert (time-subtract (current-time) timebegin) 'integer))))

(defun eredis-print-hash (hashtable)
  "Prints the hashtable, each line is key, val"
  (if (typep hashtable 'hash-table)
    (maphash (lambda (k v) (princ (format "%s: %s\n" k v))) hashtable)
    (princ hashtable)))
