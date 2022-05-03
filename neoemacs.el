(add-to-list 'load-path          "~/.doom.d/neoemacs"  )   ;; default setting
(add-to-list 'load-path          user-private-dir      )
(add-to-list 'exec-path          pdflatex-exec-path    )
(add-to-list 'exec-path          rg-exec-path          )
(add-to-list 'exec-path          node-bin-dir          )
(setq org-roam-graph-executable  dot-exec-path
      lsp-java-java-path         lsp-java-java-path
      counsel-fzf-cmd            (concat fd-exec-path " --exclude={.git,.idea,.vscode,.sass-cache,node_modules,build,target,classes,out,.local,class} -c never --hidden --follow %s .")
      lsp-java-format-settings-url               (expand-file-name "~/.doom.d/neoemacs/eclipse-codestyle.xml" )
      lsp-java-configuration-maven-user-settings (expand-file-name lsp-maven-path                            ))



;; almost setting
;; (global-disable-mouse-mode)
(blink-cursor-mode   0             )
(tool-bar-mode       0             )
(menu-bar-mode       0             )
(scroll-bar-mode     0             )
(display-time-mode   1             )

(remove-hook 'doom-first-buffer-hook #'global-hl-line-mode)
(custom-set-variables '(x-select-enable-clipboard t))

(set-default 'truncate-lines nil  )
(setq-default treemacs-width 175  )
(defun my/disable-scroll-bars (frame)
  (modify-frame-parameters frame
                           '((vertical-scroll-bars . nil)
                             (horizontal-scroll-bars . nil))))
(defun popup-handler (app-name window-title x y w h)
  (set-frame-position (selected-frame) (+ x 800) (+ y (+ h 600)))
  (unless (zerop w)
    (set-frame-size (selected-frame) 800 200 t))
)
;; Hook your function
(add-hook 'ea-popup-hook 'popup-handler)
(add-hook 'after-make-frame-functions 'my/disable-scroll-bars)

(setq default-frame-alist                        '((top . 30) (left . 50) (height . 39) (width . 100))
      ;; doom-font                               (font-spec :family "Sarasa Fixed SC" :size 18)
      ;; doom-font                               (font-spec :family "Unifont" :size 17)
      frame-title-format                         " "
      gc-cons-threshold                          (* 2 1000 1000)
      auto-save-visited-mode                     nil
      auto-save-default                          nil
      neo-window-width                           70
      display-time-24hr-format                   t
      display-time-day-and-date                  t
      doom-modeline-height                       10
      doom-modeline-bar-width                    2
      doom-modeline-modal-icon                   nil
      doom-modeline-icon                         nil
      doom-modeline-major-mode-icon              nil
      doom-neotree-enable-variable-pitch         t
      neo-show-updir-line                        t
      frame-resize-pixelwise                     nil
      org-roam-v2-ack                            t
      org-confirm-babel-evaluate                 nil
      evil-emacs-state-tag                       "EMACS"
      evil-insert-state-tag                      "INSERT"
      evil-motion-state-tag                      "MOTION"
      evil-normal-state-tag                      "NORMAL"
      evil-operator-state-tag                    "OPERATOR"
      evil-visual-state-tag                      "VISUAL"
      evil-want-Y-yank-to-eol                    t
      company-box-doc-enable                     t
      company-box-scrollbar                      t
      company-tooltip-limit                      12
      ;;company-tooltip-margin                     0.1
      company-tooltip-offset-display             'lines
      org-image-actual-width                     '(300)
      doom-modeline-vcs-max-length               200
      vterm-kill-buffer-on-exit                  t
      neo-window-fixed-size                      nil
      treemacs--width-is-locked                  nil
      org-agenda-files                           (list (concat org-roam-directory "/agenda/GTD.org"))
      plantuml-default-exec-mode                 ( cond ((executable-find "plantuml") 'executable     ))
      plantuml-jar-path                          ( expand-file-name "~/.doom.d/neoemacs/plantuml.jar" )
      org-plantuml-jar-path                      ( expand-file-name "~/.doom.d/neoemacs/plantuml.jar" )
      org-id-track-globally                      t ;; M-x org-id-update-id-locations , org-roam-update-org-id-locations
      lsp-java-format-on-type-enabled            t
      lsp-java-format-comments-enabled           nil
      lsp-completion-enable-additional-text-edit t
      lsp-java-save-actions-organize-imports     t
      lsp-java-autobuild-enabled                 t
      lsp-java-max-concurrent-builds             12
      lsp-java-import-maven-enabled              t
      lsp-java-maven-download-sources            t
      lsp-completion-sort-initial-results        t
      lsp-java-format-on-type-enabled            t
      lsp-inhibit-message                        t
      lsp-java-completion-overwrite              nil
      lsp-modeline-code-actions-enable           nil
      lsp-completion-show-detail                 nil
      lsp-headerline-breadcrumb-enable           nil
      lsp-log-io                                 nil
      read-process-output-max                    (* 1024 1024)           ;; 1mb
      lsp-idle-delay                             0.500
      ejc-result-table-impl                      'ejc-result-mode
      dap-auto-configure-features                '( controls locals )
      doom-modeline-buffer-file-name-style       'truncate-with-project  )
(setq package-archives '(( "gnu"    . "http://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/"   )
                         ( "org-cn" . "http://mirrors.tuna.tsinghua.edu.cn/elpa/org/"   )
                         ( "melpa"  . "http://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/" )))
(package-initialize)
(after! warnings (add-to-list 'warning-suppress-types '(yasnippet backquote-change)))

;; almost package
;; (use-package lsp-mode
;;   :hook ((lsp-mode . lsp-enable-which-key-integration)))
(use-package! yaml-mode)
(use-package! expand-region)

;; 暂时不打开
;; (use-package! company-tabnine
;;   :after company
;;   :when (featurep! :completion company)
;;   :config
;;   (cl-pushnew 'company-tabnine (default-value 'company-backends)))

(use-package! lsp-java
  :config
  (setq lombok-jar-path (expand-file-name "~/.doom.d/neoemacs/lombok.jar"))
  (setq lsp-java-vmargs `(
          , (concat "-javaagent:" lombok-jar-path)
          , "-XX:+UseParallelGC"
          , "-XX:GCTimeRatio=4"
          , "-XX:AdaptiveSizePolicyWeight=90"
          , "-Dsun.zip.disableMemoryMapping=true"
          , "-Xmx2G"
          , "-Xms500m"
          , "-Dosgi.locking=none"))
  (add-hook 'java-mode-hook 'lsp)
  (add-hook 'java-mode-hook 'yascroll-bar-mode)
  (add-hook 'java-mode-hook 'rainbow-delimiters-mode))

(with-eval-after-load 'lsp-mode (setq lsp-modeline-diagnostics-scope :file))
(setq-default indent-tabs-mode nil)
(setq lsp-enable-file-watchers nil)
;; (add-hook 'java-mode-hook #'lsp)

(use-package dap-mode
  :diminish
  :defer t
  :config (setq-local company-backends
          '(dap-ui-repl-company          ))
  :hook   ((lsp-mode  . dap-mode          )
           (dap-mode  . dap-ui-mode       )
           (dap-mode  . dap-tooltip-mode  )
           (java-mode . (lambda()
           (require 'dap-java             )))))
(require      'disable-mouse      )
(use-package! restclient-jq       )
(use-package! jq-mode             )
(use-package! go-translate        )
(use-package! zygospore           )
(use-package! conf-evil-clipboard )
(use-package! string-inflection   )
(use-package! general             )
(use-package! yascroll)
(use-package! ejc-sql :commands ejc-sql-mode ejc-connect :defer t :ensure nil)
(defun k/sql-mode-hook () (ejc-sql-mode t))
(add-hook 'sql-mode-hook 'k/sql-mode-hook)
(add-hook 'sql-mode-hook 'yascroll-bar-mode)

;; almost key set
(map! :nve "; g"     'evil-end-of-line                          )
(map! :nve "; a"     'evil-beginning-of-line                    )
(map! :ne "f"       'evil-avy-goto-char                        )
(map! :ne "SPC l"   'evil-window-right                         )
(map! :ne "C-j"     'evil-scroll-down                          )
(map! :ne "C-k"     'evil-scroll-up                            )
(map! :ne "s-i"     'evil-goto-definition                      )
(map! :ne "C-p"     'evil-scroll-up                            )
(map! :ne "C-n"     'evil-scroll-down                          )
(map! :ne "SPC z"   'counsel-fzf                               )
(map! :ne "SPC v v" 'projectile-run-vterm                      )
(map! :ne "SPC v p" 'vterm-send-stop                           )
(map! :ne "SPC v s" 'vterm-send-start                          )
(map! :ne "SPC v c" 'counsel-rg                                )
(map! :ne "SPC v r" 'lsp-rename                                )
(map! :ne "M-j"     'drag-stuff-down                           )
(map! :ne "M-k"     'drag-stuff-up                             )
(map! :ne "s-;"     'comment-line                              )
(map! :ne "; w"     'save-buffer                               )
(map! :ne "; b"     'switch-to-buffer                          )
(map! :ne "; e"     'ace-window                                )
(map! :ne "; d"     'zygospore-toggle-delete-other-windows     )
(map! :ve "; d"     'zygospore-toggle-delete-other-windows     )
(map! :ne "; f"     'neotree-find                              )
(map! :ne "; h"     'neotree-toggle                            )
(map! :ne "; i"     'lsp-java-organize-imports                 )
; (map! :ne "; c"     'lsp-treemacs-symbols                      )
(map! :ne "; o"     'neotree-projectile-action                 )
(map! :ne "SPC e r" 'neotree-goto-resources-dir                )
;; (map! :ne "; g"     'ejc-show-last-result                      )
;; (map! :ne "; a"     'ranger                                    )
(map! :ne "; s"     'lsp-workspace-restart                     )
(map! :ne "; l"     'org-toggle-narrow-to-subtree              )
(map! :ne "; j"     '+workspace/swap-left                      )
(map! :ne "; ;"     'hide-mode-line-mode                       )
(map! :ne "SPC e c" 'ejc-connect-ivy                           )
(map! :ne "; t"     'go-translate                              )
(map! :ve "; t"     'go-translate                              )
(map! :ne ", n"     'dap-next                                  )
(map! :ne ", b"     'dap-breakpoint-toggle                     )
(map! :ne ", c"     'dap-continue                              )
(map! :ne ", r"     'dap-eval-region                           )
(map! :ne ", a"     'dap-eval-thing-at-point                   )
(map! :ne ", d"     'dap-debug                                 )
(map! :ne ", u"     'dap-ui-repl                               )
;; (map! :ne ", t"     'dap-breakpoint-condition                  )
(map! :ne ", m"     'lsp-java-add-unimplemented-methods        )
(map! :ne "s-d"     'lsp-goto-type-definition                  )
(map! :ve ", f r"   'lsp-format-region                         )
(map! :ne ", f b"   'lsp-format-buffer                         )
(map! :ne "; q"     'quit-window                               )
(map! :ve "; q"     'quit-window                               )
(map! :ne "; x"     'kill-this-buffer                          )
(map! :ne "; e"     'er/expand-region                          )
(map! :ve "; e"     'er/expand-region                          )
(map! :ve "s-x"     'amx                                       )
(map! :ie "s-1"     '+workspace/switch-to-0                    )
(map! :ie "s-2"     '+workspace/switch-to-1                    )
(map! :ie "s-3"     '+workspace/switch-to-2                    )
(map! :ie "s-4"     '+workspace/switch-to-3                    )
(map! :ie "s-5"     '+workspace/switch-to-4                    )
(map! :ne "; r"     'string-inflection-java-style-cycle        )
(map! :ne "; c c"   'comment-line                              )
;; 断词设置，设置以后断词更长
;; (defalias 'forward-evil-word 'forward-evil-symbol)
(global-set-key "\C-xm"       'browse-url-at-point             )
(global-set-key (kbd "<RET>") 'evil-ret                        )
(global-set-key (kbd "C-;"  ) 'toggle-input-method             )
(global-set-key (kbd "s-."  ) 'next-buffer                     )
(global-set-key (kbd "s-,"  ) 'previous-buffer                 )
(global-set-key (kbd "M-i"  ) 'lsp-goto-implementation         )
(global-set-key (kbd "M-o"  ) 'lsp-java-open-super-implementation)
(global-set-key (kbd "M-d"  ) 'lsp-goto-type-definition        )
(global-set-key (kbd "M-s"  ) 'lsp-treemacs-symbols            )
(global-set-key (kbd "M-t"  ) 'lsp-treemacs-references         )
(general-def 'insert "C-h"    'delete-backward-char            )
(general-def 'insert vterm-mode-map "C-h" 'vterm-send-C-h      )
(keyboard-translate ?\C-h ?\C-?)

;; gc setting
(defmacro k-time (&rest body) `(let ((time (current-time))) ,@body (float-time (time-since time))))
(defvar k-gc-timer (run-with-idle-timer 15 t 'garbage-collect  ))

;; use project root
(setq counsel-fzf-dir-function
(lambda ()
  (let ((d (locate-dominating-file default-directory ".git")))
    (if (or (null d)
      (equal (expand-file-name d)
        (expand-file-name "~/")))
  default-directory d))))

;; set org mode
(org-babel-do-load-languages
  'org-babel-load-languages
  '((emacs-lisp . nil )
    (org        . t   )
    (plantuml   . t   )))


;; just install emacs first https://rime.im
(use-package! rime
  :config
  (setq rime-show-candidate 'minibuffer)
  :custom
  (rime-emacs-module-header-root emacs-module-root)
  (default-input-method "rime"))
  (setq mode-line-mule-info   '((:eval (rime-lighter)))
      gts-translate-list      '(("en" "zh"))
      rime-disable-predicates '(
         rime-predicate-current-uppercase-letter-p
         rime-predicate-space-after-cc-p)
      gts-default-translator   (gts-translator
       :picker (gts-prompt-picker)
       :engines (list (gts-google-engine) (gts-google-rpc-engine))
       :render (gts-buffer-render)))
;; translate
(defun go-translate ()
  (interactive)
  (gts-translate (gts-translator
                  :picker  (gts-noprompt-picker :texter (gts-current-or-selection-texter) :single t)
                  :engines (gts-google-rpc-engine)
                  :render  (gts-buffer-render))))

;; ejc-connect ivy
(defun ejc-connect-ivy ()
  (interactive)
  (let* ((conn-list        (mapcar 'car ejc-connections)            )
         (conn-statistics  (ejc-load-conn-statistics)               )
         (conn-list-sorted (-sort (lambda (c1 c2)
          (> (or (lax-plist-get conn-statistics c1) 0)
             (or (lax-plist-get conn-statistics c2) 0))) conn-list) ))
    (ivy-read "DataBase connection name: " conn-list-sorted
              :keymap    ivy-minibuffer-map
              :preselect (car conn-list-sorted)
              :action    #'ejc-connect)))

(add-hook 'ejc-sql-connected-hook
          (lambda ()
            (ejc-set-column-width-limit 50)
            (ejc-set-use-unicode t)))

;; git diff line in modeline
(defadvice vc-git-mode-line-string (after plus-minus (file) compile activate)
  "Show the information of git diff on modeline."
(setq ad-return-value
(concat (propertize ad-return-value 'face '(:foreground "white" :weight bold))
        " "
        (let ((plus-minus (vc-git--run-command-string file "diff" "--numstat" "--")))
                (if (and plus-minus
                (string-match "^\\([0-9]+\\)\t\\([0-9]+\\)\t" plus-minus))
                (concat
                (propertize (format "+%s," (match-string 1 plus-minus)) 'face '(:foreground "green3"))
                (propertize (format "-%s"  (match-string 2 plus-minus)) 'face '(:foreground "#50fa7b")))
                (propertize "√" 'face '(:foreground "green3" :weight bold)))) "")))

;; Define a function to connect to a server
(defun some-serv ()
  (lambda ()
  (interactive)
  (erc :server "irc.libera.chat"
       :port   "6697")))

;;number-region
(defun number-region (start end)
  (interactive "r")
  (let* ((count 1)
     (indent-region-function (lambda (start end)
                   (save-excursion
                     (setq end (copy-marker end))
                     (goto-char start)
                     (while (< (point) end)
                       (or (and (bolp) (eolp))
                       (insert (format "%d " count))
                       (setq count (1+ count)))
                       (forward-line 1))
                     (move-marker end nil)))))
    (indent-region start end)))

;; goto resources
(defun neotree-goto-resources-dir ()
  (interactive)
  (let ((d (locate-dominating-file default-directory "resources")))
    (neotree-dir d)))


(use-package! websocket
    :after org-roam)
(use-package! org-roam-ui
    :after org-roam ;; or :after org
    :defer t
    :config
    (setq org-roam-ui-sync-theme t
          org-roam-ui-follow t
          org-roam-ui-update-on-save t
          org-roam-ui-open-on-start t))
(add-hook 'org-mode-hook '+org/close-all-folds)
(add-hook 'org-mode-hook 'yascroll-bar-mode)


;; (beacon-mode 1)

;; (setq minimap-minimum-width 5)
;; (setq minimap-window-location 'right)
;; (minimap-mode 0)
;;(use-package! indent-guide)
;;(setq indent-guide-char "|")
;;(indent-guide-global-mode)
;;(custom-set-faces '(indent-guide-face ((t (:foreground "grey43" :background "#171717")))))
(defun config-font-size (en-size cn-size)
  (setq doom-font (font-spec
                   :family "Operator Mono"
                   :size en-size))
  (set-face-attribute 'default nil :font
                      (format "%s:pixelsize=%d" "Operator Mono" en-size))
  (if (display-graphic-p)
      (dolist (charset '(kana han cjk-misc bopomofo))
        (set-fontset-font (frame-parameter nil 'font) charset
                          (font-spec :family "等距更纱黑体 Slab SC" :size cn-size)))))
(config-font-size 15 15)



;; Useful configuration
;; (setq lsp-java-jdt-download-url "https://download.eclipse.org/jdtls/milestones/1.1.2/jdt-language-server-1.1.2-202105191944.tar.gz")
;; (setq lsp-java-jdt-download-url "http://localhost/html/jdt-language-server-1.7.0-202112161541.tar.gz")

;; install mactex https://www.tug.org/mactex/
;;
(require 'ox-latex)
(add-to-list 'org-latex-classes
             '("org-article"
               "\\documentclass[11pt,a4paper]{article}
                \\usepackage[UTF8]{ctex}
                \\usepackage{graphicx}
                \\usepackage{xcolor}
                \\usepackage{xeCJK}
                \\usepackage{fixltx2e}
                \\usepackage{longtable}
                \\usepackage{float}
                \\usepackage{tikz}
                \\usepackage{wrapfig}
                \\usepackage{latexsym,amssymb,amsmath}
                \\usepackage{textcomp}
                \\usepackage{marvosym}
                \\usepackage{textcomp}
                \\usepackage{latexsym}
                \\usepackage{natbib}
                \\usepackage{geometry}
                \\usepackage{color}
                \\usepackage{listings}
                \\usepackage{cmap}
                \\definecolor{mygreen}{rgb}{0,0.6,0}
                \\definecolor{mygray}{rgb}{0.5,0.5,0.5}
                \\definecolor{mymauve}{rgb}{0.58,0,0.82}
                \\lstset{ %
                        frame=trbl,
                        backgroundcolor=\\color{white},                         % choose the background color
                        basicstyle=\\等距更纱黑体\ Slab\ SC\\scriptsize,        % size of fonts used for the code
                        breaklines=true,                                        % automatic line breaking only at whitespace
                        captionpos=b,                                           % sets the caption-position to bottom
                        commentstyle=\\color{mygreen},                          % comment style
                        escapeinside={\\%*}{*)},                                % if you want to add LaTeX within your code
                        keywordstyle=\\color{blue},                             % keyword style
                        stringstyle=\\color{mymauve},                           % string literal style
                }
                [PACKAGES]
                [EXTRA]"
                ("\\section{%s}"       . "\\section*{%s}"       )
                ("\\subsection{%s}"    . "\\subsection*{%s}"    )
                ("\\subsubsection{%s}" . "\\subsubsection*{%s}" )
                ("\\paragraph{%s}"     . "\\paragraph*{%s}"     )
                ("\\subparagraph{%s}"  . "\\subparagraph*{%s}"  )))
;; Latex导出代码设置 , brew install pygments
(setq org-latex-pdf-process '("xelatex -interaction nonstopmode %f" "xelatex -interaction nonstopmode %f")
      org-latex-listings         t
      org-export-latex-listings  t
      org-latex-hyperref-template "\\hypersetup{\n pdfauthor={%a},\n pdftitle={%t},\n pdfkeywords={%k},\n pdfsubject={%d},\n colorlinks=true,\n linkcolor=black\n}\n")
(add-to-list 'org-latex-packages-alist '("" "listings"))
(add-to-list 'org-latex-packages-alist '("" "color"))

;; (setq org-dnd-use-package t)
;; (require 'ox-dnd)

;; vterm custom setting
(defun create-terminal-home ()
  (interactive)
  (+workspace/new "vterm home")
  (+vterm/here t)
)
(map! :ne ", t"     'create-terminal-home                  )

(setenv "XMLLINT_INDENT" "    ")
(use-package xml-format
  :demand t
  :after nxml-mode)


(provide 'neoemacs)
