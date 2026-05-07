;;; neoemacs/sql/config.el -*- lexical-binding: t; -*-

(map! :ne "SPC e c" 'clutch-connect                           )

(defun k/sql-mode-hook ()
  (yas-minor-mode-on))

(add-hook 'sql-mode-hook 'k/sql-mode-hook)

(defun sql/indent-tabs-mode ()
  (setq indent-tabs-mode nil))
(add-hook 'sql-mode-hook #'sql/indent-tabs-mode)

(setq clutch-connect-timeout-seconds 10
      clutch-read-idle-timeout-seconds 30
      clutch-query-timeout-seconds 20
      clutch-result-max-rows 100
      clutch-jdbc-rpc-timeout-seconds 15)
(add-to-list 'auto-mode-alist '("\\.sql\\'" . clutch-mode))
(map! :after clutch
      :map clutch-mode-map
      :n "SPC e l" #'clutch-connect)
(map! :after clutch
      :map clutch-mode-map
      :vn "?" #'clutch-dispatch)
(defun my-clutch-exec-xml-inner ()
  (interactive)
  (save-excursion
    (re-search-backward "<[^/][^>]*>")
    (search-forward ">")
    (let ((beg (point)))
      (re-search-forward "</[^>]+>")
      (clutch-execute-region beg (match-beginning 0))))
      (other-window 1))
(map! :after clutch
      :map clutch-mode-map
      :n "C-c C-c" #'my-clutch-exec-xml-inner)
(map! :after clutch
      :map clutch-result-mode-map
      :vn "RET" #'clutch-result-open-record)
(map! :after clutch
      :map clutch-result-mode-map
      :vn "?" #'clutch-result-dispatch)
(map! :after clutch
      :map clutch-record-mode-map
      :n "n" #'clutch-record-next-row)
(map! :after clutch
      :map clutch-record-mode-map
      :n "N" #'clutch-record-prev-row)
