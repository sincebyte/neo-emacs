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
(add-to-list 'auto-mode-alist '("\\.redis\\'" . clutch-redis-mode))
(map! :after clutch
      :map clutch-mode-map
      :n "SPC e l" #'clutch-connect)
(map! :after clutch
      :map clutch-mode-map
      :vn "?" #'clutch-dispatch)
(defun my-clutch-sql-strip-line-trailing-comment (line)
  "Strip trailing `--` comment from LINE, respecting single-quoted strings."
  (let ((pos 0)
        (len (length line))
        (comment-start nil))
    (while (and (< pos len) (not comment-start))
      (if-let* ((skip (clutch-db-sql-skip-literal-or-comment line pos)))
          (if (and (= (aref line pos) ?-)
                   (< (1+ pos) len)
                   (= (aref line (1+ pos)) ?-))
              (setq comment-start pos)
            (setq pos skip))
        (setq pos (1+ pos))))
    (if comment-start
        (string-trim-right (substring line 0 comment-start))
      line)))

(defun my-clutch-sql-filter-comments (text)
  "Remove SQL `--` comments from TEXT.
Strips trailing line comments and drops comment-only or blank lines."
  (string-join
   (seq-filter
    (lambda (line)
      (not (string-empty-p (string-trim line))))
    (mapcar #'my-clutch-sql-strip-line-trailing-comment
            (split-string text "\n")))
   "\n"))

(defun my-clutch-exec-xml-inner ()
  "Execute SQL inside the XML tag at point, ignoring `--` comments."
  (interactive)
  (let ((sql (save-excursion
               (re-search-backward "<[^/][^>]*>")
               (search-forward ">")
               (let ((beg (point)))
                 (re-search-forward "</[^>]+>")
                 (string-trim
                  (my-clutch-sql-filter-comments
                   (buffer-substring-no-properties beg (match-beginning 0))))))))
    (when (string-empty-p sql)
      (user-error "No SQL in tag (comments filtered)"))
    (clutch--ensure-connection)
    (clutch-execute sql)
    (when-let* ((win (clutch--result-window)))
      (select-window win))))
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
