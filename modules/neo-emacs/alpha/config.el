;;; module/alpha/config.el -*- lexical-binding: t; -*-

;; (setq frame-title-format nil)

(setq kaolin-themes-underline nil)
(defun synchronize-theme ()
  (setq hour (string-to-number (substring (current-time-string) 11 13)))
  (if (member hour (number-sequence 0 0))
      (setq   now '(kaolin-light))
    (setq   now '(kaolin-bubblegum)))
  (if (eq now custom-enabled-themes)
      (print (current-time-string))
    (setq custom-enabled-themes now)
    (if (member hour (number-sequence 0 0))
        (load-theme 'kaolin-light t)
      (load-theme 'kaolin-bubblegum t))))
;; (run-with-timer 0 3600 'synchronize-theme)
;; (load-theme 'kaolin-light t)

(use-package transwin
  :config
  (setq transwin--record-toggle-frame-transparency 80)
  (setq transwin-delta-alpha 5)
  (setq transwin-parameter-alpha 'alpha-background))

;; (setq highlight-indent-guides-auto-enabled nil)
;;(set-face-foreground 'highlight-indent-guides-character-face "dimgray")
(setq highlight-indent-guides-responsive 'stack)
