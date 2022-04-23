;; (custom-set-faces '(hl-line ((t (:background "#222")))))
(defun doom-dashboard-widget-banner ()
 (let ((point (point)))
   (mapc (lambda (line)
           (insert (propertize (+doom-dashboard--center +doom-dashboard--width line)
                               'face 'doom-dashboard-banner) " ")
           (insert "\n"))
  '("|¯¯\\|¯¯|/¯x¯¯\\ /¯¯¯¯¯\\ /¯x¯¯\\|¯¯\\/¯¯¯| /¯¯¯¯|/¯¯¯¯\\ /¯¯¯¯¯/ "
    "|     '| (\\__/|| x   || (\\__/|      '|/    !||(\\__/|\\ __¯¯¯\\"
    "|__|\\__|\\____\\ \\_____/ \\____\\|._|\\/||/__/¯|_|\\_____\\ /_____/"))))

;; '("███╗   ██╗███████╗ ██████╗    ███████╗███╗   ███╗ █████╗  ██████╗███████╗   "
;;   "████╗  ██║██╔════╝██╔═══██╗   ██╔════╝████╗ ████║██╔══██╗██╔════╝██╔════╝   "
;;   "██╔██╗ ██║█████╗  ██║   ██║   █████╗  ██╔████╔██║███████║██║     ███████╗   "
;;   "██║╚██╗██║██╔══╝  ██║   ██║   ██╔══╝  ██║╚██╔╝██║██╔══██║██║     ╚════██║   "
;;   "██║ ╚████║███████╗╚██████╔╝██╗███████╗██║ ╚═╝ ██║██║  ██║╚██████╗███████║██╗"
;;   "╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚═╝"))))
(defun doom-dashboard-widget-footer () (insert ""))


;; key for marco
(map! :ne "SPC i n" 'marco-java-new)
(map! :ne "SPC i t" 'marco-insert-java-return)
(map! :ne "SPC d d" 'kill-other-buffer)
(map! :ne "SPC d q" 'ejc-table-queryvis)

(defun kill-other-buffer ()
  (interactive)
  (dolist (buffer (delq (current-buffer) (buffer-list))) (kill-buffer buffer)))

;; java new 对象，使用方法在，光标位于某类开始
(fset 'marco-java-new
   [?b ?v ?e ?y ?A ?  escape escape ?p ?\; ?r ?A ?  ?= ?  ?n ?e ?w ?  escape escape ?p ?a ?\( ?\) ?\; escape escape ?\; ?w])

;; 补全java函数返回的结果，使用方法：在lsp-java模式下将光标位于函数开始（此宏兼容性欠佳）
(fset 'marco-insert-java-return
   (kmacro-lambda-form [?\s-i ?v ?F ?  ?f escape ?w ?v ?e ?y ?\s-, ?0 ?P ?a ?  ?\s-v ?  ?= ?  escape ?b ?b ?V ?, ?f ?r escape ?\; ?r ?b] 0 "%d"))

;; 获取表格的queryvis, 使用方法：在ejc-sql模式下光标移动至表名上
(fset 'ejc-table-queryvis
   (kmacro-lambda-form [?\s-x ?e ?j ?c ?- ?d ?e ?s ?c ?r ?i ?b ?e ?- ?t ?a ?b ?l ?e return return ?  ?w ?l ?  ?t ?r ?j ?j ?j ?j ?V ?G ?: ?s ?/ ?| ?. ?+ ?\\ ?n ?/ ?  ?/ ?g left left backspace ?, return ?V ?: ?s ?/ ?\\ ?s ?+ ?/ ?  ?/ ?g return ?i ?\( escape ?$ ?a ?\C-? ?\C-? ?\) escape ?0 ?k ?k ?k ?k ?w ?w ?v ?e ?y ?j ?j ?j ?j ?0 ?P ?0 ?V ?y ?  ?w ?h ?o ?\s-v escape ?\; ?w ?k ?\; ?d] 0 "%d"))
