(setq
 kill-do-not-save-duplicates t       ;不向kill-ring中加入重复内容
 save-interprogram-paste-before-kill t  ;将系统剪切板的内容放一份到kill-ring中，
 mouse-yank-at-point t
 kill-whole-line t                     ;在行首 C-k 时，同时删除末尾换行符
 kill-read-only-ok t                  ;kill read-only buffer内容时,copy之而不用警告
 kill-ring-max 200                       ;emacs内置剪切板默认保留60份，default 60
 )

;;; 关于没有选中区域,则默认为选中整行的advice
;;;;默认情况下M-w复制一个区域，但是如果没有区域被选中，则复制当前行
(defadvice kill-ring-save (before slickcopy activate compile)
  "When called interactively with no active region, copy a single line instead."
  (interactive
   (if mark-active (list (region-beginning) (region-end))
     (message "已选中当前行!")
     (list (line-beginning-position)
           (line-beginning-position 2)))))

;; "+p 从系统剪切板paste时会调到此处
;; 如果在mac 终端下使用emacs ,则使用pbpaste从clipboard 获取内容
(defadvice gui-backend-get-selection (around get-clip-from-terminal-on-osx activate)
  ad-do-it
  (when (and (equal system-type 'darwin)
             (not (display-graphic-p))
             (not (window-system))
             (equal (ad-get-arg 0) 'CLIPBOARD))
    (let ((default-directory "~/"))
      (setq ad-return-value (shell-command-to-string "pbpaste")))))

;; "+yy 设置内容到系统clipboard
;; 如果在mac 终端下使用emacs ,则使用pbpaste从clipboard 获取内容
(defadvice gui-backend-set-selection (around set-clip-from-terminal-on-osx activate)
  ad-do-it
  ;; (message "%s %s"  (ad-get-arg 0)  (ad-get-arg 1))
  (when (and (equal system-type 'darwin)
             (not (display-graphic-p))
             (not (window-system))
             (equal (ad-get-arg 0) 'CLIPBOARD))
    (let ((process-connection-type nil)   ; ; use pipe
          (default-directory "~/"))
      (let ((proc (start-process "pbcopy" "*Messages*" "pbcopy")))
        (process-send-string proc (ad-get-arg 1))
        (process-send-eof proc)))))


;; (defun evil-paste-from-clipboard ()
;;   "Paste text from system clipboard."
;;   (interactive)
;;   (if (not  (string= major-mode "term-mode"))
;;       (let ((text (evil-paste-from-register ?+)))
;;         (when (> (length text) 0))
;;         (backward-char)
;;         )
;;     (require 'term)
;;     (term-send-raw-string (evil-get-register ?+))))

;; ;; 这里参数跟evil-yank 完全相同， 只是函数里忽略了register 参数，而写死成?+,即使用系统clipboard
;; (evil-define-operator evil-yank-to-clipboard (beg end type register yank-handler)
;;   "Yank text to system clipboard."
;;   :move-point nil
;;   :repeat nil
;;   (interactive "<R><x><y>")
;;   (evil-yank beg end type ?+ yank-handler))

;; (evil-define-operator evil-delete-to-clipboard (beg end type register yank-handler)
;;   "Delete text from BEG to END with TYPE.
;; Save in REGISTER or in the kill-ring with YANK-HANDLER."
;;   (interactive "<R><x><y>")
;;   (evil-delete beg end type ?+ yank-handler))

;; ;; Y不常用故
;; (define-key evil-normal-state-map "Y" 'evil-yank-to-clipboard)
;; (define-key evil-motion-state-map "Y" 'evil-yank-to-clipboard)
;; ;; (vmacs-leader "y" 'evil-yank-to-clipboard)

;; (when (equal system-type 'darwin)
;;   (global-set-key (kbd "s-c") 'evil-yank-to-clipboard) ;等同于 "+y
;;   (global-set-key (kbd "s-x") 'evil-delete-to-clipboard) ;等同于 "+d
;;   (global-set-key (kbd "s-v") 'evil-paste-from-clipboard) ;等同于 "+p
;;   ;; (global-set-key  (kbd "s-c") 'kill-ring-save)
;;   ;; (global-set-key  (kbd "s-v") 'yank)
;;   ;; (global-set-key  (kbd "s-x") 'vmacs-kill-region-or-line)
;;   )

(provide 'conf-evil-clipboard)

;; Local Variables:
;; coding: utf-8
;; End:

;;; conf-clipboard.el ends here.
