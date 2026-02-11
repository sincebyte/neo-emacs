;;; $DOOMDIR/modules/neo-emacs/opencode/config.el -*- lexical-binding: t; -*-

;; Opencode Configuration
;;
;; Opencode is a powerful AI agent orchestration system for Emacs that provides
;; seamless integration with LLMs, MCP servers, and various development tools.
;; This configuration sets up opencode for optimal use in the neo-emacs environment.

(use-package opencode
  :ensure t
  :init
  ;; Enable opencode global minor mode if desired
  ;; (opencode-mode 1)
  
  :config
  ;; Configure basic opencode settings
  (setq opencode-enable-auto-sync t)
  
  ;; Set default model if needed
  ;; (setq opencode-default-model "gpt-4")
  
  ;; Configure MCP servers (if any are available)
  ;; For example, if you have context7 API key configured:
  ;; (setq opencode-mcp-servers
  ;;       '(("context7" .
  ;;          '((transport . "http")
  ;;            (url . "https://mcp.context7.com/mcp")
  ;;            (headers . (("CONTEXT7_API_KEY" . "your-key-here")))))))
  
  ;; Additional configuration can go here
  (message "Opencode configuration loaded"))

;; Setup beautify effects: hide mode-line and adjust window size
(defun opencode-setup-beautify ()
  "Setup美化效果：隐藏mode-line并调整窗口大小"
  (hide-mode-line-mode)
  (run-with-timer 0.1 nil
                  (lambda ()
                    (condition-case nil
                        (let ((desired-width 60))
                          (when (window-parent)
                            (window-resize (selected-window) (- desired-width (window-total-width)) t)))
                      (error nil)))))
(add-hook 'agent-shell-mode-hook (lambda () (hide-mode-line-mode)))
(add-hook 'agent-shell-completion-mode-hook 'opencode-setup-beautify)

(defun open-opencode-session-right ()
  "Open a new opencode session in a new window on the right with width 60."
  (interactive)
  (let* ((current-win (selected-window))
         (split-width-threshold nil)  ; 确保垂直分割
         (split-height-threshold 0)   ; 确保垂直分割优先
         (right-window (split-window-right 60)))
    (select-window right-window)
    (agent-shell-opencode-start-agent)
    ;; 切换到新创建的 opencode 会话窗口，然后应用美化设置
    (run-with-timer 0.2 nil 
                    (lambda ()
                      (when (window-live-p right-window)
                        (select-window right-window)
                        (opencode-setup-beautify))))))

(add-hook 'doom-switch-window-hook
          (lambda (&optional frame)
            (let ((current-buffer (window-buffer (selected-window))))
              (with-current-buffer current-buffer
                (when (or (eq major-mode 'OpenCode)
                          (string-match-p "OpenCode" (symbol-name major-mode)))
                  (opencode-setup-beautify))))))

 ;; Redefine opencode-insert-logo to also print agent name and current model
 (defun opencode-insert-logo ()
   "Insert the opencode logo with the current agent and model name."
   (let ((logo '("░█▀█░█▀█░█▀▀░█▀█░█▀▀░█▀█░█▀▄░█▀▀░"
                 "░█░█░█▀▀░█▀▀░█░█░█░░░█░█░█░█░█▀▀░"
                 "░▀▀▀░▀░░░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀▀░░▀▀▀░")))
     (cl-loop for line in logo
              do
              (opencode--output (propertize line 'face 'shadow))
              (opencode--output "\n"))
     (when opencode-session-agent
       (let-alist opencode-session-agent
         (opencode--output (propertize (format "Active Agent: %s\n" .name) 'face 'font-lock-function-name-face))
         ;; Add current model name if available
         (let ((model-info (opencode--current-model)))
           (when (and model-info (alist-get 'name model-info))
             (opencode--output (propertize (format "Current Model: %s" (alist-get 'name model-info))
                                         'face 'font-lock-type-face))))))
     (opencode--output "\n")))

  ;; Alternative function that forces the session to open in the right-side window
  (defun open-opencode-session-in-right-window ()
    "Force opencode session to start in a right-side window."
    (interactive)
    (let* ((initial-window (selected-window))
           (main-width (window-total-width))
           (target-width 60)
           (left-width (- main-width target-width))
           (left-window initial-window))
      ;; Split the window horizontally, keeping the left window at calculated width
      (delete-other-windows)
      (split-window-horizontally left-width)
      (other-window 1)  ; Move to the newly created right window
      ;; Start opencode session in the right Apply
      (setq agent-shell-show-welcome-message nil)
      (agent-shell-opencode-start-agent)
      ;; window beautify settings in a more delayed manner to ensure setup completes
      (run-with-timer 0.3 nil
                      (lambda ()
                        (when (derived-mode-p 'opencode-mode)
                          (opencode-setup-beautify))))))

 ;; Optional: Set up key bindings for opencode functionality
 (map! :nv "SPC d a" 'open-opencode-session-in-right-window)
