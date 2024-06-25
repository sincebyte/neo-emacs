;;; neoemacs/sql/config.el -*- lexical-binding: t; -*-

(use-package! ejc-sql     :defer t
              :commands ejc-sql-mode ejc-connect      )
;; (use-package! ob-sql-mode :defer t)

(setq ejc-result-table-impl                      'ejc-result-mode)

(map! :ne "SPC e c" 'ejc-connect                           )
;; (map! :ne "SPC d q" 'ejc-table-queryvis                        )

(defun k/sql-mode-hook ()
  (ejc-sql-mode t)
  (yas-minor-mode-on))

(add-hook 'sql-mode-hook 'k/sql-mode-hook)

(add-hook 'ejc-sql-connected-hook
          (lambda ()
            (ejc-set-column-width-limit 150)
            (ejc-set-fetch-size 120)
            (ejc-set-use-unicode t)))

(defun sql/indent-tabs-mode ()
  (setq indent-tabs-mode nil))
(add-hook 'sql-mode-hook #'sql/indent-tabs-mode)
