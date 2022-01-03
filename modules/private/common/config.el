;; (custom-set-faces '(hl-line ((t (:background "#222")))))
(defun doom-dashboard-widget-banner ()
 (let ((point (point)))
   (mapc (lambda (line)
           (insert (propertize (+doom-dashboard--center +doom-dashboard--width line)
                               'face 'doom-dashboard-banner) " ")
           (insert "\n"))
'("███╗   ██╗███████╗ ██████╗    ███████╗███╗   ███╗ █████╗  ██████╗███████╗   "
  "████╗  ██║██╔════╝██╔═══██╗   ██╔════╝████╗ ████║██╔══██╗██╔════╝██╔════╝   "
  "██╔██╗ ██║█████╗  ██║   ██║   █████╗  ██╔████╔██║███████║██║     ███████╗   "
  "██║╚██╗██║██╔══╝  ██║   ██║   ██╔══╝  ██║╚██╔╝██║██╔══██║██║     ╚════██║   "
  "██║ ╚████║███████╗╚██████╔╝██╗███████╗██║ ╚═╝ ██║██║  ██║╚██████╗███████║██╗"
  "╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚═╝"))))
(defun doom-dashboard-widget-footer () (insert ""))


;; key for marco
(map! :ne "SPC i n" 'marco-java-new)
(map! :ne "SPC i t" 'marco-insert-java-return)
(map! :ne "SPC d d" 'kill-other-buffer)

(fset 'marco-java-new
   [?b ?v ?e ?y ?A ?  escape escape ?p ?\; ?r ?A ?  ?= ?  ?n ?e ?w ?  escape escape ?p ?a ?\( ?\) ?\; escape escape ?\; ?w])
(fset 'marco-insert-java-return
   (kmacro-lambda-form [?\s-i ?v ?F ?  ?f escape ?w ?v ?e ?y ?\s-, ?0 ?P ?a ?  ?\s-v ?  ?= ?  escape ?b ?b ?V ?, ?f ?r escape ?\; ?r ?b] 0 "%d"))
(defun kill-other-buffer ()
  (interactive)
  (dolist (buffer (delq (current-buffer) (buffer-list))) (kill-buffer buffer)))
