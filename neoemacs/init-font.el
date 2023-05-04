;;; init-font.el --- Dired customisations -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:
;;; base on https://gist.github.com/coldnew/7398835

(setq emacs-font-size-pair '(19 . 20))
(setq en-font "victor Mono"
      cn-font "LXGW WenKai Mono")
(setq en-font-size (car emacs-font-size-pair)
      cn-font-size (cdr emacs-font-size-pair))

(defun config-font-size (en-size cn-size)
  (setq doom-font (font-spec
                   ;; :family "Operator Mono"
                   ;; :family "Share Tech Mono"
                   :family en-font
                   ;; :family "Xanh Mono"
                   :size en-size))
  (set-face-attribute 'default nil :font
                      ;; (format "%s:pixelsize=%d" "Operator Mono" en-size))
                      ;; (format "%s:pixelsize=%d" "Share Tech Mono" en-size))
                      (format "%s:pixelsize=%d" en-font en-size))
                      ;; (format "%s:pixelsize=%d" "Xanh Mono" en-size))
  (if (display-graphic-p)
      (dolist (charset '(kana han cjk-misc bopomofo))
        (set-fontset-font (frame-parameter nil 'font) charset
                          (font-spec :family cn-font :size cn-size)))))
;; (config-font-size 17 18)
(config-font-size (default-value 'en-font-size) (default-value 'cn-font-size))

(defvar emacs-english-font nil
  "The font name of English.")

(defvar emacs-cjk-font nil
  "The font name for CJK.")

(defvar emacs-font-size-pair nil
  "Default font size pair for (english . chinese)")

(defvar emacs-font-size-pair-list nil
  "This list is used to store matching (englis . chinese) font-size.")

(defun font-exist-p (fontname)
  "test if this font is exist or not."
  (if (or (not fontname) (string= fontname ""))
      nil
    (if (not (x-list-fonts fontname))
        nil t)))

(defun set-font (english chinese size-pair)
  "Setup emacs English and Chinese font on x window-system."
  (if (font-exist-p english)
      (set-frame-font (format "%s:pixelsize=%d" english (car size-pair)) t))

  (if (font-exist-p chinese)
      (dolist (charset '(kana han symbol cjk-misc bopomofo))
        (set-fontset-font (frame-parameter nil 'font) charset
                          (font-spec :family chinese :size (cdr size-pair))))))

(defun emacs-step-font-size (step)
  "Increase/Decrease emacs's font size."
  (let ((scale-steps emacs-font-size-pair-list))
    (if (< step 0) (setq scale-steps (reverse scale-steps)))
    (setq emacs-font-size-pair
          (or (cadr (member emacs-font-size-pair scale-steps))
              emacs-font-size-pair))
    (when emacs-font-size-pair
      (message "emacs font size set to %.1f" (car emacs-font-size-pair))
      (set-font emacs-english-font emacs-cjk-font emacs-font-size-pair))))

(defun increase-emacs-font-size ()
  "Decrease emacs's font-size acording emacs-font-size-pair-list."
  (interactive) (emacs-step-font-size 1))

(defun decrease-emacs-font-size ()
  "Increase emacs's font-size acording emacs-font-size-pair-list."
  (interactive) (emacs-step-font-size -1))

(setq list-faces-sample-text
      (concat
       "ABCDEFTHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz\n"
       "11223344556677889900       壹貳參肆伍陸柒捌玖零"))

(when window-system
  ;; setup change size font, base on emacs-font-size-pair-list
  (global-set-key (kbd "C-M-=") 'increase-emacs-font-size)
  (global-set-key (kbd "C-M--") 'decrease-emacs-font-size)

  ;; setup default english font and cjk font
  ;; (setq emacs-english-font "Operator Mono")
  ;; (setq emacs-english-font "Share Tech Mono")
  (setq emacs-english-font en-font)
  ;; (setq emacs-english-font "Xanh Mono")
  (setq emacs-cjk-font cn-font)
  ;; (setq emacs-font-size-pair '(17 . 18))
  ;; (setq emacs-font-size-pair-list '(( 17 . 18) ))
  ;; (setq emacs-font-size-pair (en-font-size . cn-font-size))
  ;;(setq emacs-font-size-pair '(en-font-size . cn-font-size))
  ;;(setq emacs-font-size-pair '((default-value 'en-font-size) . (default-value 'cn-font-size)))
  ;;(setq emacs-font-size-pair-list '(( 19 . 20)))
  ;;(setq emacs-font-size-pair-list '((default-value 'en-font-size) . (default-value 'cn-font-size)))
  ;; Setup font size based on emacs-font-size-pair
  (set-font emacs-english-font emacs-cjk-font emacs-font-size-pair))

(after! doom-themes
  (setq doom-neotree-enable-variable-pitch nil))
(setq doom-variable-pitch-font (font-spec :family "victor Mono"))

(provide 'init-font)
;;; init-font.el ends here
