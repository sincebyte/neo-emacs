;;; db-work --- database client
;;; Commentary:
;;; database client
;;; Code:
(use-package! ejc-sql
  ;;; doc
  :commands ejc-sql-mode ejc-connect
  :config

  (setq clomacs-httpd-default-port 18090)

  (ejc-create-connection "local-mysql5.7"
                         :classpath      "~/.m2/repository/mysql/mysql-connector-java/8.0.17/mysql-connector-java-8.0.17.jar"
                         :connection-uri "jdbc:mysql://localhost:3306/spring?useSSL=false&user=root&password=root&characterEncoding=utf8"
                         :separator      "</?\.*>" )
  )
;; set proxy
(defun convert-to-regex (str)
  (let* ((joined (replace-regexp-in-string "," "\\\\|" str))
         (wrapped (concat "^\\(" joined "\\)")))
    wrapped))
;; (setq url-proxy-services `(("http" ."vpn.local.com:10887")
;;                            ("https" ."vpn.local.com:10887")
;;                            ("no_proxy" . ,(convert-to-regex ".*aliyun.com,192.168.0.0/16,137.239.155.184"))))
(provide 'db-work)
;;; db-work.el ends here
