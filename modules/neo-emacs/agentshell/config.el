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

;;; Two-row session header
;; Emacs header lines cannot contain multiple text rows.  Use the tab line
;; for agent/model/mode and leave project/activity in the header line.
(defun opencode-shell--split-header (&rest _)
  "Split the native text header before its project name.
Keep the native rendering/cache and heartbeat, including clickable menus.
The project name is followed by the checkout's git branch."
  (when (and (derived-mode-p 'agent-shell-mode)
             (eq agent-shell-header-style 'text)
             (stringp header-line-format))
    (opencode-shell--refresh-branch)
    (when-let* ((project-start
                (text-property-any 0 (length header-line-format)
                                   'font-lock-face 'agent-shell-session-directory
                                   header-line-format)))
      (let* ((top (substring header-line-format 0 (max 0 (- project-start 3))))
             (project-end (next-single-property-change
                           project-start 'font-lock-face header-line-format
                           (length header-line-format)))
             (bottom (concat " "
                             (substring header-line-format
                                        project-start project-end)
                             (opencode-shell--branch-label)
                             (substring header-line-format project-end)))
             (position 0))
        ;; Native menus are bound to header-line events.  Adapt copies for
        ;; the tab line without modifying the cached header's keymaps.
        (while (< position (length top))
          (let ((end (next-single-property-change position 'local-map top
                                                  (length top)))
                (map (get-text-property position 'local-map top)))
            (when map
              (let ((copy (copy-keymap map)))
                (define-key copy [tab-line] (lookup-key map [header-line]))
                (put-text-property position end 'local-map copy top)))
            (setq position end)))
        (setq-local tab-line-format (list top))
        (setq-local header-line-format bottom)))))

;;; Branch beside the project name
;; The second header row starts with the project name.  Show the checkout's
;; git branch right after it, separated by the same arrow the header uses
;; elsewhere, so a session's working branch is visible at a glance.

(defface opencode-shell-branch
  '((t :inherit font-lock-function-name-face))
  "Face for the git branch shown in the agent-shell session header."
  :group 'agent-shell)

(defconst opencode-shell--branch-refresh-interval 1.0
  "Seconds between git branch re-reads while the header is repainted.")

(defvar-local opencode-shell--branch nil
  "Git branch of this shell's `default-directory', or nil outside git.")

(defvar-local opencode-shell--branch-checked nil
  "Value of `float-time' when `opencode-shell--branch' was last read.")

(defun opencode-shell--git-dir (directory)
  "Return the git directory governing DIRECTORY, or nil outside a checkout.
Remote directories are skipped: the header must not touch TRAMP."
  (unless (file-remote-p directory)
    (when-let* ((root (locate-dominating-file directory ".git")))
      (let ((dotgit (expand-file-name ".git" root)))
        (cond
         ((file-directory-p dotgit) dotgit)
         ;; A worktree or submodule keeps `.git' as a file pointing at the
         ;; real git directory.
         ((file-readable-p dotgit)
          (with-temp-buffer
            (insert-file-contents dotgit)
            (goto-char (point-min))
            (when (looking-at "gitdir:[ \t]*\\(.+\\)[ \t]*$")
              (expand-file-name (match-string 1) root)))))))))

(defun opencode-shell--git-branch (&optional directory)
  "Return the branch checked out in DIRECTORY.
Fall back to the abbreviated commit for a detached HEAD, and nil outside
git.  `.git/HEAD' is read directly instead of shelling out, so this stays
cheap enough for the header's update path."
  (when-let* ((gitdir (opencode-shell--git-dir (or directory default-directory)))
              (head (expand-file-name "HEAD" gitdir))
              ((file-readable-p head)))
    (with-temp-buffer
      (insert-file-contents head)
      (goto-char (point-min))
      (cond
       ((looking-at "ref:[ \t]*refs/heads/\\([^ \t\r\n]+\\)")
        (match-string 1))
       ((looking-at "\\([[:xdigit:]]\\{7\\}\\)[[:xdigit:]]*")
        (match-string 1))))))

(defun opencode-shell--refresh-branch (&optional force)
  "Re-read this shell's git branch.
Return non-nil when the branch changed.  Unless FORCE, read at most once
per `opencode-shell--branch-refresh-interval' so heartbeat ticks drawing
the busy indicator do not hit the file system on every beat."
  (when (or force
            (null opencode-shell--branch-checked)
            (>= (- (float-time) opencode-shell--branch-checked)
                opencode-shell--branch-refresh-interval))
    (setq opencode-shell--branch-checked (float-time))
    (let ((branch (opencode-shell--git-branch default-directory)))
      (unless (equal branch opencode-shell--branch)
        (setq opencode-shell--branch branch)
        t))))

(defun opencode-shell--branch-label ()
  "Return the branch separator drawn after the project name in the header."
  (when opencode-shell--branch
    (concat " ➤ " (propertize opencode-shell--branch
                              'font-lock-face 'opencode-shell-branch))))

(defun opencode-shell--shell-for-header (window)
  "Return the agent-shell buffer WINDOW's header belongs to, or nil.
WINDOW is the transcript itself (`agent-shell-mode') or the fixed input
below it (`opencode-compose-mode')."
  (let ((buffer (window-buffer window)))
    (with-current-buffer buffer
      (cond
       ((derived-mode-p 'agent-shell-mode) buffer)
       ((derived-mode-p 'opencode-compose-mode)
        (when-let* ((transcript
                     (window-parameter window 'opencode-compose-transcript)))
          (when (window-live-p transcript)
            (window-buffer transcript))))))))

(defun opencode-shell--sync-header-branch (&rest _)
  "Repaint a visible session header when its checkout's branch changed.
Runs on window selection, so switching branch in Magit and returning to
the session shows the new branch without waiting for agent activity."
  (when-let* ((shell (opencode-shell--shell-for-header (selected-window))))
    (with-current-buffer shell
      (when (and (derived-mode-p 'agent-shell-mode)
                 (opencode-shell--refresh-branch))
        (agent-shell--update-header-and-mode-line)))))

(defun opencode-shell--header-faces ()
  "Match the two session header rows to the same face."
  (require 'face-remap)
  (face-remap-add-relative 'tab-line 'header-line))

(after! agent-shell
  (advice-add 'agent-shell--update-header-and-mode-line :after
              #'opencode-shell--split-header)
  (add-hook 'agent-shell-mode-hook #'opencode-shell--header-faces)
  ;; `window-selection-change-functions' exists since Emacs 30.
  (when (boundp 'window-selection-change-functions)
    (add-hook 'window-selection-change-functions
              #'opencode-shell--sync-header-branch)))

(defcustom opencode-shell-window-width 55
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
(declare-function evil-local-set-key "evil-core" (state key def))
(declare-function evil-initialize-local-keymaps "evil-core" ())
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
    (define-key map (kbd "TAB") #'opencode-compose-cycle-session-mode)
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

;; `$DOOMDIR/config.el' binds TAB to `yas-expand' in `evil-insert-state-map'.
;; Evil's state keymaps take precedence over major mode keymaps, so binding TAB
;; in `opencode-compose-mode-map' alone would never fire in insert state.  Set
;; the binding buffer-locally in the compose buffer instead, leaving every
;; other buffer's TAB untouched.
(defun opencode-compose--bind-mode-switch-key ()
  "Make TAB cycle the session mode in the current compose buffer."
  (when (require 'evil nil t)
    (unless (and (boundp 'evil-insert-state-local-map)
                 (keymapp evil-insert-state-local-map))
      (evil-initialize-local-keymaps))
    (evil-local-set-key 'insert (kbd "TAB")
                        #'opencode-compose-cycle-session-mode)))

(define-derived-mode opencode-compose-mode fundamental-mode "Agent Input"
  "Edit agent-shell prompts in a fixed bottom window."
  (opencode-compose--decorate)
  (opencode-compose--bind-mode-switch-key)
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

;;; Follow the transcript while a reply streams
;; The transcript and the input are different windows, and a window keeps its
;; own point, so nothing follows output the way a prompt typed straight into
;; the transcript would: shell-maker's auto-scroll check (`eobp' plus the end
;; visible in the window) fails for the transcript window, and its window
;; point never advances as text arrives, so a sent message and the reply it
;; starts land below whatever the window last showed.  Sending a prompt arms
;; following explicitly: the transcript is scrolled to its end and every new
;; chunk is coalesced into the same scroll.  Scrolling the window away from
;; the end that was last shown stops the follow instead of fighting the user.

(defconst opencode-compose--follow-delay 0.05
  "Seconds to coalesce streaming updates before scrolling the transcript.")

(defvar-local opencode-compose--following nil
  "Non-nil when new output should keep the transcript at its end.")

(defvar-local opencode-compose--follow-timer nil
  "Pending debounced transcript scroll for this shell buffer.")

(defvar-local opencode-compose--follow-anchor nil
  "Marker left visible by the last follow scroll.
Following is still wanted while the windows show this position, so a window
that no longer does was scrolled away by the user.")

(defun opencode-compose--transcript-windows (shell)
  "Return the windows on SHELL's frame that show SHELL's transcript.
Windows on other frames are skipped: selecting one would switch frames
behind the user's back."
  (when-let* ((shown (get-buffer-window shell t))
              (frame (window-frame shown)))
    (get-buffer-window-list shell 'no-mini frame)))

(defun opencode-compose--scroll-transcript-to-end (&optional shell)
  "Scroll SHELL's transcript windows down to the newest line.
SHELL defaults to this input window's session.  Point is left at the end of
the transcript, which is also recorded as the follow anchor."
  (let ((shell (or shell opencode-compose--shell)))
    (when (and (buffer-live-p shell)
               (with-current-buffer shell (derived-mode-p 'agent-shell-mode)))
      (with-current-buffer shell
        (dolist (window (opencode-compose--transcript-windows shell))
          (with-selected-window window
            (goto-char (point-max))
            (recenter -1)))
        (unless (markerp opencode-compose--follow-anchor)
          (setq opencode-compose--follow-anchor (make-marker)))
        (set-marker opencode-compose--follow-anchor (point-max))))))

(defun opencode-compose--transcript-at-anchor-p (windows)
  "Return non-nil when every window in WINDOWS still shows the follow anchor."
  (let ((anchor opencode-compose--follow-anchor))
    (or (not (markerp anchor))
        (not (marker-buffer anchor))
        (seq-every-p (lambda (window)
                       ;; Asked while narrowed, the check can signal
                       ;; `args-out-of-range'; read that as scrolled away.
                       (ignore-errors
                         (pos-visible-in-window-p anchor window)))
                     windows))))

(defun opencode-compose--follow-now (shell)
  "Keep SHELL's transcript at its end, or stop following after a scroll back."
  (when (buffer-live-p shell)
    (with-current-buffer shell
      (setq opencode-compose--follow-timer nil)
      (when (and opencode-compose--following
                 (derived-mode-p 'agent-shell-mode)
                 (buffer-live-p opencode-compose--buffer))
        (let ((windows (opencode-compose--transcript-windows shell)))
          (cond
           ((null windows) nil)
           ((opencode-compose--transcript-at-anchor-p windows)
            (opencode-compose--scroll-transcript-to-end shell))
           (t
            (setq opencode-compose--following nil))))))))

(defun opencode-compose--output-changed (&rest _)
  "Schedule a transcript scroll after output changed."
  (when (and opencode-compose--following
             (buffer-live-p opencode-compose--buffer))
    (unless (timerp opencode-compose--follow-timer)
      (setq opencode-compose--follow-timer
            (run-at-time opencode-compose--follow-delay nil
                         #'opencode-compose--follow-now (current-buffer))))))

(defun opencode-compose--follow-transcript (&rest _)
  "Arm following and scroll this shell's transcript after a prompt is sent."
  (when (and (derived-mode-p 'agent-shell-mode)
             (buffer-local-value 'opencode-compose--buffer (current-buffer)))
    (setq opencode-compose--following t)
    (when (timerp opencode-compose--follow-timer)
      (cancel-timer opencode-compose--follow-timer)
      (setq opencode-compose--follow-timer nil))
    (opencode-compose--scroll-transcript-to-end (current-buffer))))

(after! agent-shell
  ;; Reloading this file must not stack the advice on every evaluation.
  (unless (advice-member-p #'opencode-compose--follow-transcript
                           'agent-shell-submit)
    (advice-add 'agent-shell-submit :after
                #'opencode-compose--follow-transcript)))

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
  (add-hook 'after-change-functions #'opencode-compose--output-changed nil t)
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
      (add-hook 'after-change-functions #'opencode-compose--output-changed nil t)
      (add-hook 'shell-maker-finish-output-hook #'opencode-compose--refresh nil t))))
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (derived-mode-p 'opencode-compose-mode)
      (opencode-compose--decorate)
      (opencode-compose--bind-mode-switch-key))))
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
;; 光标在 agent-shell 面板（会话窗口 `agent-shell-mode' 或其下方的输入窗口
;; `opencode-compose-mode'）里时，`; d' 收起整个侧边面板：删掉这两个窗口
;; （buffer 保留），回到面板左边的窗口，之后还能再用 `; d' 把面板贴回来。
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

(defun opencode--agent-shell-panel-transcript (window)
  "Return the agent-shell transcript window of WINDOW, or nil.
WINDOW may be the transcript itself (`agent-shell-mode') or the fixed
input window shown below it (`opencode-compose-mode')."
  (with-current-buffer (window-buffer window)
    (cond
     ((derived-mode-p 'agent-shell-mode) window)
     ((derived-mode-p 'opencode-compose-mode)
      (when-let* ((transcript
                   (window-parameter window 'opencode-compose-transcript)))
        (when (and (window-live-p transcript)
                   (with-current-buffer (window-buffer transcript)
                     (derived-mode-p 'agent-shell-mode)))
          transcript))))))

(defun opencode--close-agent-shell-panel ()
  "Close the agent-shell panel around the selected window.
Delete the transcript window and its fixed input window, but keep their
buffers alive so `; d' can show the panel again.  Select the window to
the left of the panel.  Return non-nil when a panel was closed."
  (when-let* ((transcript
               (opencode--agent-shell-panel-transcript (selected-window)))
              (frame (window-frame transcript)))
    (let* ((input (opencode--compose-window transcript))
           (panel (delq nil (list transcript input)))
           (others (seq-remove (lambda (window) (memq window panel))
                               (window-list frame 'no-minibuffer))))
      ;; A panel that covers the whole frame cannot be closed by deleting
      ;; windows; leave that case to the maximize/restore command below.
      (when others
        (let ((target (or (window-in-direction 'left transcript)
                          (car others))))
          (dolist (window panel)
            ;; A dedicated window refuses to be deleted.
            (set-window-dedicated-p window nil)
            (when (window-live-p window)
              (delete-window window)))
          (when (window-live-p target)
            (select-window target))
          t)))))

(defun opencode-toggle-maximize-or-agent-shell ()
  "Toggle the window layout, preferring the current project's agent-shell.
Inside an agent-shell panel (the transcript or its input window) close
that panel and return to the window beside it.  With a single window in
the frame and an agent-shell buffer for the current project, split
left/right and show that shell on the right.  Otherwise behave like
`zygospore-toggle-delete-other-windows': maximize the current window, or
restore the layout before maximizing."
  (interactive)
  (cond
   ((opencode--close-agent-shell-panel))
   ((and (one-window-p t)
         (not (derived-mode-p 'agent-shell-mode))
         (not (derived-mode-p 'opencode-compose-mode)))
    (if-let* ((shell (opencode--project-shell-buffer)))
        (opencode--show-shell-in-right-window shell)
      (zygospore-toggle-delete-other-windows)))
   (t
    (zygospore-toggle-delete-other-windows))))
