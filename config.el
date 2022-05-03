;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
(setq rg-exec-path                "/opt/homebrew/bin/rg"                                   ;; rg            exec path
      fd-exec-path                "/opt/homebrew/bin/fd"                                   ;; fd            exec path
      dot-exec-path               "/opt/homebrew/bin/dot"                                  ;; dot           exec path
      pdflatex-exec-path          "/Library/TeX/texbin/pdflatex"                           ;; pdflatex      exec path
      lsp-maven-path              "~/.m2/settings.xml"                                     ;; maven setting path
      org-directory               "~/org/"                                                 ;; org           root path
      org-roam-directory          "~/org/org-roam"                                         ;; org roam      root path
      lsp-java-java-path          (concat (getenv "JAVA_HOME") "/bin/java")                ;; java11        exec path
      node-bin-dir                "~/soft/node-v16.14.0/bin"                               ;; node home
      user-private-dir            "~/org/org-roam/command/doom/config/"                    ;; user private dir
      ;;doom-font                   (font-spec :family "等距更纱黑体 Slab SC" :size 16)      ;; font setting
      display-line-numbers-type   nil                                                      ;; show line number 'relative
      rime-user-data-dir          "~/Library/Rime/"                                        ;; rime config input method setting
      rime-librime-root           "~/.doom.d/neoemacs/rime-macos/dist"                     ;; emacs-rime/blob/master/INSTALLATION.org
      emacs-module-root           "/opt/homebrew/opt/emacs-plus@28/include"                ;; emcas exec path
      lsp-java-jdt-download-url   "http://1.117.167.195/download/jdt-language-server-1.6.0-202111261512.tar.gz" ;; jdt-server URL,with tencent cloud speed up
)

;; default core setting
(add-to-list  'load-path "~/.doom.d"  )
(load-theme   'doom-badger t          ) ;; set theme
(use-package! neoemacs                ) ;; neo-emacs main config
(setq ejc-set-use-unicode t)
(use-package! dap-java-config        )
(use-package! db-work                 )
;; (use-package pulsing-cursor
;;    :config (pulsing-cursor-mode +1))


;; for ejc-sql query detail
(defvar ejc-results-detail-buffer nil
  "The results detail buffer.")

(defun goto-result-detail ()
  (interactive)
  (let ((list-data (split-string (buffer-substring-no-properties (line-beginning-position) (line-end-position)) " | " ))
        (max-head-length 0)
        (c-point (point))
        (list-head (split-string (buffer-substring-no-properties 1 (search-backward "\n" nil t (- (string-to-number(elt (split-string (what-line) " ") 1 )) 1 ) )) " | ")) )
        ;; (line-head (buffer-substring-no-properties 1 239)))
    (goto-char c-point)
  (when (not (and ejc-results-detail-buffer (buffer-live-p ejc-results-detail-buffer)))
    (setq ejc-results-detail-buffer (get-buffer-create "*ejc-results-detail-buffer*"))
  (with-current-buffer ejc-results-detail-buffer (ejc-result-mode)))
  ;; (print (string-to-number(elt (split-string (what-line) " ") 1 )))
  ;; (print (search-backward "\n" nil t (- (string-to-number(elt (split-string (what-line) " ") 1 )) 1 ) ))
  (switch-to-buffer ejc-results-detail-buffer)
  (erase-buffer)
  (cl-loop
   for element in list-head
   do (if (< max-head-length (length element))
          (setq max-head-length (length element))))
  (cl-loop
    for i from 0 to (- (length list-head) 1)
    do (with-current-buffer ejc-results-detail-buffer (insert
        (elt list-head i)
        (string-join (make-list (- max-head-length (length (elt list-head i)) ) " ") "")
        "| " (elt list-data i) "\n"))
   )))
