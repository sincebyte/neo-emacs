;;; $DOOMDIR/modules/neo-emacs/agentshell/config.el -*- lexical-binding: t; -*-

;; Opencode Configuration
;;
;; Opencode is a powerful AI agent orchestration system for Emacs that provides
;; seamless integration with LLMs, MCP servers, and various development tools.
;; This configuration sets up opencode for optimal use in the neo-emacs environment.

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
  (open-opencode-session-in-right-window))

(defun open-cursor-session-right ()
  "Open a new cursor session in a new window on the right with width 60."
  (interactive)
  (open-cursor-session-in-right-window))

(add-hook 'doom-switch-window-hook
          (lambda (&optional frame)
            (let ((current-buffer (window-buffer (selected-window))))
              (with-current-buffer current-buffer
                (when (or (eq major-mode 'OpenCode)
                          (string-match-p "OpenCode" (symbol-name major-mode)))
                  (opencode-setup-beautify))))))


  ;; Alternative function that forces the session to open in the right-side window
  (defun open-opencode-session-in-right-window ()
    "Force opencode session to start in a right-side window."
    (interactive)
    (setq agent-shell-thought-process-expand-by-default t)
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
      (setq agent-shell-session-strategy 'new)
      (agent-shell-opencode-start-agent)
      ;; window beautify settings in a more delayed manner to ensure setup completes
      (run-with-timer 0.3 nil
                      (lambda ()
                        (when (derived-mode-p 'opencode-mode)
                          (opencode-setup-beautify))))))

  ;; Alternative function that forces the cursor agent session to open in the right-side window
  (defun open-cursor-session-in-right-window ()
    "Force cursor agent session to start in a right-side window."
    (interactive)
    (setq agent-shell-thought-process-expand-by-default t)
    (let* ((initial-window (selected-window))
           (main-width (window-total-width))
           (target-width 60)
           (left-width (- main-width target-width))
           (left-window initial-window))
      ;; Split the window horizontally, keeping the left window at calculated width
      (delete-other-windows)
      (split-window-horizontally left-width)
      (other-window 1)  ; Move to the newly created right window
      ;; Start cursor agent session in the right window
      (setq agent-shell-show-welcome-message nil)
      (setq agent-shell-session-strategy 'new)
      ;; (setq agent-shell-cursor-acp-command '("cursor-agent-acp" "-t" "120000"))
      (agent-shell-cursor-start-agent)
      ;; Apply window beautify settings after the agent buffer finishes initializing
      (run-with-timer 0.3 nil
                      (lambda ()
                        (opencode-setup-beautify)))))
;; Optional: Set up key bindings for opencode functionality
(map! :nv "SPC d a" 'open-opencode-session-in-right-window)
(map! :nv "SPC d c" 'open-cursor-session-in-right-window)
