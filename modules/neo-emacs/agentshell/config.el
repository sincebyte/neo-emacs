;;; $DOOMDIR/modules/neo-emacs/agentshell/config.el -*- lexical-binding: t; -*-

;; Opencode Configuration
;;
;; Opencode is a powerful AI agent orchestration system for Emacs that provides
;; seamless integration with LLMs, MCP servers, and various development tools.
;; This configuration sets up opencode for optimal use in the neo-emacs environment.

;;; 打开 agent-shell 时不自动带入光标所在行
;; `agent-shell-context-sources' 默认是 (files region error line)，其中 `line`
;; 会让 `agent-shell' 的 DWIM 把光标所在整行（连同文件名和行号）自动插入输入框，
;; 看起来就像"打开时复制了光标处的内容"。这里去掉 `line'。
;; 保留的源：files（dired/图片）、region（显式选区）、error（光标处诊断）。
;; 如果希望彻底关闭自动上下文，直接设为 nil 即可。
(after! agent-shell
  (setq agent-shell-context-sources '(files region error)))

(defcustom opencode-shell-window-width 60
  "Width in columns of an agent-shell window shown beside its project."
  :type 'integer
  :group 'agent-shell)

;; Setup beautify effects: hide mode-line and adjust window size
(defun opencode-setup-beautify ()
  "Setup美化效果：隐藏mode-line并调整窗口大小"
  (unless (derived-mode-p 'opencode-compose-mode)
  (setq-local mode-line-format nil)
  (run-with-timer 0.1 nil
                  (lambda ()
                    (condition-case nil
                        (let ((desired-width opencode-shell-window-width))
                          (when (window-parent)
                            (window-resize (selected-window) (- desired-width (window-total-width)) t)))
                      (error nil))))))
(add-hook 'agent-shell-mode-hook (lambda () (interactive) (setq-local mode-line-format nil)))
(add-hook 'agent-shell-completion-mode-hook 'opencode-setup-beautify)

;;; Fixed compose window for agent-shell
;; The transcript and the input must be different windows: scrolling one must
;; never move the other.  Keep the real comint prompt as the submission API.

(declare-function agent-shell--prompt-input-start "agent-shell-prompt" ())
(declare-function agent-shell--live-input-prompt-p "agent-shell-prompt" (prompt))
(declare-function agent-shell-submit "agent-shell" (&optional arg))
(declare-function agent-shell-chat--relabel "agent-shell-chat-mode" ())
(declare-function agent-shell-set-session-model "agent-shell" (&optional on-success))
(declare-function agent-shell-set-session-mode "agent-shell" (&optional on-success))
(declare-function agent-shell-set-session-thought-level "agent-shell" (&optional on-success))
(declare-function agent-shell-set-session-config-option "agent-shell" ())
(declare-function agent-shell-cycle-session-mode "agent-shell" ())
(declare-function agent-shell-interrupt "agent-shell" ())
(declare-function agent-shell-project-buffers "agent-shell" ())
(declare-function zygospore-toggle-delete-other-windows "zygospore" ())
(require 'subr-x)
(require 'seq)
(require 'comint)
(defvar comint-last-prompt)
(defvar agent-shell-prompt-bar-mode)
(defvar-local opencode-compose--shell nil)
(defvar-local opencode-compose--buffer nil)
(defvar-local opencode-compose--hidden-prompt nil)
(defvar-local opencode-compose--decorated nil)

(defvar opencode-compose-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'opencode-compose-submit)
    (define-key map (kbd "C-c C-c") #'opencode-compose-submit)
    (define-key map (kbd "S-<return>") #'newline)
    (define-key map (kbd "C-j") #'newline)
    (define-key map (kbd "C-c C-o") #'opencode-compose-transcript)
    (define-key map (kbd "C-c C-v") #'opencode-compose-set-session-model)
    (define-key map (kbd "C-c C-m") #'opencode-compose-set-session-mode)
    (define-key map (kbd "C-c C-t") #'opencode-compose-set-session-thought-level)
    (define-key map (kbd "C-c C-s") #'opencode-compose-set-session-config-option)
    (define-key map (kbd "C-<tab>") #'opencode-compose-cycle-session-mode)
    (define-key map (kbd "C-c C-k") #'opencode-compose-interrupt)
    (define-key map (kbd "M-RET") #'opencode-compose-submit-override)
    (define-key map (kbd "M-<return>") #'opencode-compose-submit-override)
    map)
  "Keys for the fixed agent-shell input window.")

(defun opencode-compose--rule ()
  "Fill the entire decoration row, including margins and fringe width.
Redisplay selects the window whose header/mode line it is formatting.
Overfill slightly and let redisplay clip at the window's right edge."
  (propertize (make-string (+ 2 (window-total-width)) ?─) 'face 'shadow))

(defun opencode-compose--ensure-rules (&optional window)
  "Restore both decorations before WINDOW is painted, without resizing it."
  (when (or (null window) (window-live-p window))
    (with-current-buffer (if window (window-buffer window) (current-buffer))
      (when (derived-mode-p 'opencode-compose-mode)
        (let ((format '(:eval (opencode-compose--rule))))
          (unless (equal header-line-format format)
            (setq-local header-line-format format))
          (unless (equal mode-line-format format)
            (setq-local mode-line-format format))
          (unless (equal mode-line-window-selected-format format)
            (setq-local mode-line-window-selected-format format)))))))

;; This runs for visible input windows even when another buffer is selected.
;; Repair decorations before painting, not on the next input command/timer.
(add-hook 'pre-redisplay-functions #'opencode-compose--ensure-rules t)

(define-derived-mode opencode-compose-mode fundamental-mode "Agent Input"
  "Edit agent-shell prompts in a fixed bottom window."
  (opencode-compose--decorate)
  (setq-local truncate-lines nil)
  (setq-local show-trailing-whitespace nil))

(defun opencode-compose--setup-completion ()
  "Complete files and commands from the compose buffer's shell."
  (require 'agent-shell-completion)
  (setq-local agent-shell-completion--shell-buffer opencode-compose--shell)
  (setq-local default-directory
              (buffer-local-value 'default-directory opencode-compose--shell))
  (agent-shell-completion-mode 1)
  (corfu-mode 1))

(defun opencode-compose--corfu-popup (original pos &rest args)
  "Keep Corfu anchored when the compose completion start scrolls offscreen.
Use point as a fallback.  If redisplay still yields no position, hide the
popup until the next update rather than passing nil coordinates to Corfu."
  (if (or pos (not (derived-mode-p 'opencode-compose-mode)))
      (apply original pos args)
    (redisplay t)
    (if-let* ((position (posn-at-point (point))))
        (apply original position args)
      (corfu--popup-hide))))

(with-eval-after-load 'corfu
  (advice-add 'corfu--popup-show :around #'opencode-compose--corfu-popup))

(defun opencode-compose--decorate ()
  "Draw boundaries outside editable text and resize after draft edits."
  (setq-local opencode-compose--decorated t)
  (setq-local header-line-format '(:eval (opencode-compose--rule)))
  (setq-local mode-line-format '(:eval (opencode-compose--rule)))
  (setq-local mode-line-window-selected-format mode-line-format)
  (setq-local face-remapping-alist
              '((header-line (:inherit default))
                (mode-line (:inherit default))
                (mode-line-inactive (:inherit default))))
  (add-hook 'after-change-functions #'opencode-compose--draft-changed nil t)
  (remove-hook 'post-command-hook #'opencode-compose--draft-changed t))

(defun opencode-compose--draft-changed (&rest _)
  "Fit the input after insertion, deletion, paste or undo."
  (opencode-compose--resize))

(with-eval-after-load 'evil
  (evil-set-initial-state 'opencode-compose-mode 'insert))

(defun opencode-compose--reset ()
  "Restore a three-row input between two rules."
  (erase-buffer)
  (when-let* ((window (get-buffer-window (current-buffer) t)))
    (set-window-start window (point-min))
    (set-window-point window (point))))

(defun opencode-compose--input ()
  "Return the editable draft; rules are window decorations."
  (string-trim (buffer-substring-no-properties (point-min) (point-max))))

(defun opencode-compose--resize (&optional _frame)
  "Fit visible drafts, including wrapped lines, into their input windows."
  (dolist (buffer (buffer-list))
    (when (and (buffer-live-p buffer)
               (with-current-buffer buffer (derived-mode-p 'opencode-compose-mode))
               (get-buffer-window buffer t))
      (dolist (window (get-buffer-window-list buffer nil t))
        (when-let* ((transcript (window-parameter window 'opencode-compose-transcript))
                    ((window-live-p transcript)))
          (with-current-buffer buffer
            (opencode-compose--ensure-rules window)
            (let ((window-size-fixed nil)
                  (window-min-height 1)
                  (fit-window-to-buffer-horizontally nil))
              (let* ((lines (max 1 (count-screen-lines
                                   (point-min) (point-max) t window)))
                     (limit (max 3 (- (+ (window-total-height window)
                                        (window-total-height transcript))
                                     3)))
                     (height (min limit (+ lines 2)))
                     (delta (- height (window-total-height window))))
                (unless (zerop delta)
                  (let ((allowed (window-resizable window delta nil t)))
                    (unless (zerop allowed)
                      (window-resize window allowed nil t)))))
              (when (<= (count-screen-lines (point-min) (point-max) t window)
                        (window-body-height window))
                (set-window-start window (point-min))))))))))

(add-hook 'window-size-change-functions #'opencode-compose--resize)

(defun opencode-compose--in-shell (command)
  "Run the agent-shell COMMAND for this input window's session."
  (unless (buffer-live-p opencode-compose--shell)
    (user-error "Agent-shell session is gone"))
  (with-current-buffer opencode-compose--shell
    (call-interactively command)))

(defun opencode-compose-set-session-model ()
  "Select a model for the current agent-shell session."
  (interactive)
  (opencode-compose--in-shell #'agent-shell-set-session-model))

(defun opencode-compose-set-session-mode ()
  "Select a session mode for the current agent-shell session."
  (interactive)
  (opencode-compose--in-shell #'agent-shell-set-session-mode))

(defun opencode-compose-set-session-thought-level ()
  "Select a thought level for the current agent-shell session."
  (interactive)
  (opencode-compose--in-shell #'agent-shell-set-session-thought-level))

(defun opencode-compose-set-session-config-option ()
  "Set an option for the current agent-shell session."
  (interactive)
  (opencode-compose--in-shell #'agent-shell-set-session-config-option))

(defun opencode-compose-cycle-session-mode ()
  "Cycle the current agent-shell session mode."
  (interactive)
  (opencode-compose--in-shell #'agent-shell-cycle-session-mode))

(defun opencode-compose-interrupt ()
  "Interrupt the current agent-shell request."
  (interactive)
  (opencode-compose--in-shell #'agent-shell-interrupt))

(defun opencode-compose-submit-override ()
  "Send using agent-shell's busy-agent override route."
  (interactive)
  (opencode-compose-submit '(4)))

(defun opencode-compose--hide-prompt ()
  "Hide only the live comint prompt in the transcript window."
  (when (derived-mode-p 'agent-shell-mode)
    (let ((start (and comint-last-prompt
                      (agent-shell--live-input-prompt-p comint-last-prompt)
                      (marker-position (car comint-last-prompt)))))
      (if (and start (< start (point-max)))
          (progn
            (unless (and (overlayp opencode-compose--hidden-prompt)
                         (overlay-buffer opencode-compose--hidden-prompt))
              (setq opencode-compose--hidden-prompt
                    (make-overlay start (point-max) nil nil t))
              (overlay-put opencode-compose--hidden-prompt 'display "")
              (overlay-put opencode-compose--hidden-prompt 'priority 2000))
            (unless (and (= start (overlay-start opencode-compose--hidden-prompt))
                         (= (point-max) (overlay-end opencode-compose--hidden-prompt)))
              (move-overlay opencode-compose--hidden-prompt start (point-max))))
        (when (overlayp opencode-compose--hidden-prompt)
          (delete-overlay opencode-compose--hidden-prompt)
          (setq opencode-compose--hidden-prompt nil))))))

(defun opencode-compose--refresh (&rest _)
  "Keep the shell's hidden input out of the scrolling transcript."
  (when (and (derived-mode-p 'agent-shell-mode) opencode-compose--buffer)
    (opencode-compose--hide-prompt)))

(defun opencode-compose--show (shell &optional transcript-window background)
  "Create a separate fixed input window below SHELL's transcript window."
  (when-let* ((window (or transcript-window (get-buffer-window shell t))))
    (with-current-buffer shell
      (setq-local agent-shell-prompt-bar-mode t)
      (when (bound-and-true-p agent-shell-chat-mode)
        (agent-shell-chat--relabel))
      (opencode-compose--hide-prompt))
    (when (and (not (window-parameter window 'opencode-compose-transcript))
               (>= (window-total-height window) (+ window-min-height 3))
               (not (seq-some (lambda (candidate)
                              (eq (window-parameter candidate 'opencode-compose-transcript)
                                  window))
                             (window-list (window-frame window) 'no-minibuffer))))
      (let* ((existing (buffer-local-value 'opencode-compose--buffer shell))
             (input (if (buffer-live-p existing) existing
                      (generate-new-buffer (format " *Input: %s*" (buffer-name shell)))))
             (bottom (with-selected-window window
                       (let ((window-min-height 1))
                         (split-window window -3 'below)))))
        (unless (buffer-live-p existing)
          (with-current-buffer input
            (opencode-compose-mode)
            (setq-local opencode-compose--shell shell)
            (opencode-compose--reset)))
        (with-current-buffer input
          (opencode-compose--setup-completion))
        (with-current-buffer shell (setq-local opencode-compose--buffer input))
        (set-window-buffer bottom input)
        (set-window-parameter bottom 'opencode-compose-transcript window)
        (set-window-dedicated-p bottom nil)
        (with-current-buffer input (setq-local window-size-fixed 'height))
        (unless background (select-window bottom))
        (set-window-start bottom (with-current-buffer input (point-min)))
        (set-window-point bottom (with-current-buffer input (point)))))))

(defvar opencode-compose--layout-timer nil)
(defvar opencode-compose--syncing nil)

(defun opencode-compose--sync-layout ()
  "Restore visible session pairs without resetting drafts or stealing focus."
  (setq opencode-compose--layout-timer nil)
  (dolist (frame (frame-list))
    ;; Remove legacy duplicate shell slots directly below the real composer.
    ;; Restrict cleanup to the same column and the old three-row input slot.
    (dolist (input-window (window-list frame 'no-minibuffer))
      (with-current-buffer (window-buffer input-window)
        (when (derived-mode-p 'opencode-compose-mode)
          (let ((shell opencode-compose--shell)
                (edges (window-edges input-window)))
            (dolist (candidate (window-list frame 'no-minibuffer))
              (let ((other (window-edges candidate)))
                (when (and (eq (window-buffer candidate) shell)
                           (= (window-total-height candidate) 3)
                           (= (nth 0 edges) (nth 0 other))
                           (= (nth 2 edges) (nth 2 other))
                           (= (nth 3 edges) (nth 1 other)))
                  (when (eq candidate (selected-window))
                    (select-window input-window))
                  (delete-window candidate))))))))
    (dolist (window (window-list frame 'no-minibuffer))
      (when (window-live-p window)
        (with-current-buffer (window-buffer window)
          (if (derived-mode-p 'opencode-compose-mode)
              (let ((shell opencode-compose--shell)
                    (transcript (window-parameter window 'opencode-compose-transcript)))
                (cond
                 ((and (buffer-live-p shell) (window-live-p transcript)
                       (eq (window-buffer transcript) shell))
                  nil)
                 ;; The transcript was replaced with an unrelated buffer.
                 ((or (not (buffer-live-p shell)) (window-live-p transcript))
                  (if (one-window-p t frame)
                      (progn
                        (set-window-dedicated-p window nil)
                        (set-window-buffer window (other-buffer (current-buffer) t)))
                    (delete-window window)))
                 ;; Maximizing the composer deleted its transcript window.
                 (t
                  (let ((focused (eq window (selected-window))))
                    (set-window-dedicated-p window nil)
                    (set-window-buffer window shell)
                    (set-window-parameter window 'opencode-compose-transcript nil)
                    (opencode-compose--show shell window (not focused))))))
            ;; Switching buffers in the input slot must not turn that tiny
            ;; slot into a second transcript and recursively split it.
            (when-let* ((transcript (window-parameter window 'opencode-compose-transcript)))
              (if (and (derived-mode-p 'agent-shell-mode)
                       (window-live-p transcript)
                       (eq (window-buffer transcript) (current-buffer))
                       (buffer-live-p opencode-compose--buffer))
                  (set-window-buffer window opencode-compose--buffer)
                ;; Keep the slot identity across unrelated buffer switches.
                ;; Otherwise the next sync creates a second input window.
                (unless (window-live-p transcript)
                  (set-window-parameter window 'opencode-compose-transcript nil))))))))
    (dolist (window (window-list frame 'no-minibuffer))
      (with-current-buffer (window-buffer window)
        (when (and (derived-mode-p 'agent-shell-mode)
                   (> (window-total-height window) (+ window-min-height 3)))
          (opencode-compose--show (current-buffer) window t)))))
  (opencode-compose--resize))

(defun opencode-compose--schedule-layout (&rest _)
  "Finish layout changes synchronously before redisplay can show old slots.
Keep the historical name for callbacks already installed in live sessions."
  (unless opencode-compose--syncing
    (let ((opencode-compose--syncing t)
          (inhibit-redisplay t))
      (when (timerp opencode-compose--layout-timer)
        (cancel-timer opencode-compose--layout-timer))
      (setq opencode-compose--layout-timer nil)
      (opencode-compose--sync-layout))))

(add-hook 'window-configuration-change-hook #'opencode-compose--schedule-layout)
(add-hook 'window-buffer-change-functions #'opencode-compose--schedule-layout 90)
(add-hook 'doom-switch-buffer-hook #'opencode-compose--schedule-layout 90)

(defun opencode-compose-submit (&optional override)
  "Send the compose text through agent-shell's native submission path.
With prefix OVERRIDE, use the busy-agent override route."
  (interactive "P")
  (unless (and (buffer-live-p opencode-compose--shell)
               (derived-mode-p 'opencode-compose-mode))
    (user-error "No agent-shell input is active"))
   (let ((text (opencode-compose--input))
        (shell opencode-compose--shell))
    (when (string-empty-p text)
      (user-error "Input is empty"))
    (with-current-buffer shell
      (unless (agent-shell--prompt-input-start)
        (user-error "Agent-shell prompt is not ready"))
      (let ((inhibit-read-only t))
        (save-excursion
          (goto-char (point-max))
          (insert text)))
      (condition-case err
          (agent-shell-submit override)
        (error
         (when-let* ((start (agent-shell--prompt-input-start)))
           (let ((inhibit-read-only t))
             (delete-region start (point-max))))
         (signal (car err) (cdr err)))))
    (let ((inhibit-read-only t))
      (opencode-compose--reset))))

(defun opencode-compose-transcript ()
  "Select the scrolling transcript above this input."
  (interactive)
  (when-let* ((window (and (buffer-live-p opencode-compose--shell)
                           (get-buffer-window opencode-compose--shell t))))
    (select-window window)))

(defun opencode-compose--setup ()
  "Open the fixed input when agent-shell becomes visible."
  (opencode-compose--schedule-layout)
  (add-hook 'after-change-functions #'opencode-compose--refresh nil t)
  (add-hook 'shell-maker-finish-output-hook #'opencode-compose--refresh nil t))

(add-hook 'agent-shell-mode-hook #'opencode-compose--setup)

;; Reconnect preserved drafts and refresh hooks when reloading this file.
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (and (derived-mode-p 'opencode-compose-mode)
               (not opencode-compose--decorated))
      ;; Migrate the old literal rules without trimming the user's draft.
      (let ((inhibit-modification-hooks t))
        (save-excursion
          (goto-char (point-max))
          (when (save-excursion (beginning-of-line) (looking-at-p "─+$"))
            (delete-region (max (point-min) (1- (line-beginning-position))) (point-max)))
          (goto-char (point-min))
          (when (looking-at "─+\n")
            (delete-region (point-min) (match-end 0)))))
      (opencode-compose--decorate))
    (when (and (derived-mode-p 'opencode-compose-mode)
               (buffer-live-p opencode-compose--shell))
      (let ((input buffer))
        (with-current-buffer opencode-compose--shell
          (unless (buffer-live-p opencode-compose--buffer)
            (setq-local opencode-compose--buffer input)))))
    (when (derived-mode-p 'agent-shell-mode)
      (add-hook 'after-change-functions #'opencode-compose--refresh nil t)
      (add-hook 'shell-maker-finish-output-hook #'opencode-compose--refresh nil t))))
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (derived-mode-p 'opencode-compose-mode)
      (opencode-compose--decorate))))
(opencode-compose--schedule-layout)

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
                 (when (and (not (derived-mode-p 'opencode-compose-mode))
                            (or (eq major-mode 'OpenCode)
                                (string-match-p "OpenCode" (symbol-name major-mode))))
                  (opencode-setup-beautify))))))


  ;; Alternative function that forces the session to open in the right-side window
  (defun open-opencode-session-in-right-window ()
    "Force opencode session to start in a right-side window."
    (interactive)
    (setq agent-shell-thought-process-expand-by-default t)
    (let* ((initial-window (selected-window))
           (main-width (window-total-width))
           (target-width opencode-shell-window-width)
           (left-width (- main-width target-width))
           (left-window initial-window))
      ;; Split the window horizontally, keeping the left window at calculated width
      (delete-other-windows)
      (split-window-horizontally left-width)
      (other-window 1)  ; Move to the newly created right window
      ;; Start opencode session in the right Apply
      (setq agent-shell-show-welcome-message nil)
      (setq agent-shell-session-strategy 'new)
      (setq agent-shell-header-style 'text)
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
           (target-width opencode-shell-window-width)
           (left-width (- main-width target-width))
           (left-window initial-window))
      ;; Split the window horizontally, keeping the left window at calculated width
      (delete-other-windows)
      (split-window-horizontally left-width)
      (other-window 1)  ; Move to the newly created right window
      ;; Start cursor agent session in the right window
      (setq agent-shell-show-welcome-message nil)
      (setq agent-shell-session-strategy 'new)
      (setq agent-shell-header-style 'text)
      ;; (setq agent-shell-cursor-acp-command '("cursor-agent-acp" "-t" "120000"))
      (agent-shell-cursor-start-agent)
      ;; Apply window beautify settings after the agent buffer finishes initializing
      (run-with-timer 0.3 nil
                      (lambda ()
                        (opencode-setup-beautify)))))
;; Optional: Set up key bindings for opencode functionality
(map! :nv "SPC d a" 'open-opencode-session-in-right-window)
(map! :nv "SPC d c" 'open-cursor-session-in-right-window)

;;; 智能 `; d' 窗口布局
;; 单窗口时，如果当前 buffer 所属 project 已经有 agent-shell，就左右分屏并把
;; agent-shell 放到右侧（宽度用 `opencode-shell-window-width'，即 agent-shell
;; 定义的 60 列）；否则保持原逻辑：最大化当前窗口 / 恢复上一次的窗口布局。

(defun opencode--project-shell-buffer ()
  "Return the most recently used agent-shell buffer of the current project."
  (require 'agent-shell nil t)
  (when (fboundp 'agent-shell-project-buffers)
    ;; A buffer outside any project must never break the plain maximize command.
    (ignore-errors
      (seq-find #'buffer-live-p (agent-shell-project-buffers)))))

(defun opencode--compose-window (transcript)
  "Return the agent input window paired with TRANSCRIPT window."
  (seq-find (lambda (window)
              (eq (window-parameter window 'opencode-compose-transcript)
                  transcript))
            (window-list (window-frame transcript) 'no-minibuffer)))

(defun opencode--show-shell-in-right-window (shell)
  "Display SHELL in a new right window `opencode-shell-window-width' wide."
  (let* ((main (selected-window))
         (width (max window-min-width
                     (min opencode-shell-window-width
                          (- (window-total-width main) window-min-width 1))))
         (right (split-window main (- width) 'right)))
    (set-window-buffer right shell)
    (select-window right)
    ;; Let agent-shell rebuild the transcript/input pair in the new window.
    (opencode-compose--schedule-layout)
    (when-let* ((input (opencode--compose-window right)))
      (select-window input))))

(defun opencode-toggle-maximize-or-agent-shell ()
  "Toggle the window layout, preferring the current project's agent-shell.
With a single window in the frame and an agent-shell buffer for the
current project, split left/right and show that shell on the right.
Otherwise behave like `zygospore-toggle-delete-other-windows': maximize
the current window, or restore the layout before maximizing."
  (interactive)
  (let ((shell (and (one-window-p t)
                    (not (derived-mode-p 'agent-shell-mode))
                    (not (derived-mode-p 'opencode-compose-mode))
                    (opencode--project-shell-buffer))))
    (if shell
        (opencode--show-shell-in-right-window shell)
      (zygospore-toggle-delete-other-windows))))
