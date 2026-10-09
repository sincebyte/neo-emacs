;;; neoemacs/modelinexp/config.el -*- lexical-binding: t; -*-
;;(use-package doom-modeline
;;  :init
;;  (setq doom-modeline-height 20))

(setq
 doom-modeline-modal-icon                   nil
 doom-modeline-icon                         t
 doom-modeline-time-icon                    nil
 doom-modeline-lsp-icon                     nil
 doom-modeline-major-mode-icon              t
 doom-modeline-buffer-encoding              t
 doom-modeline-lsp                          nil
 doom-modeline-modal                        t
 doom-modeline-vcs-max-length               200
 doom-modeline-buffer-file-name-style       'buffer-name
 doom-modeline-continuous-word-count-modes  '(java-mode)
 doom-modeline-enable-word-count            t  )

;; doom-modeline 和 eglot (Emacs 29+) 各自都会向 mode-line-misc-info 注册
;; eglot--managed-mode 条目，形成重复。移除全部，后续 eglot 会自行添加。
;; 同时覆盖 doom-modeline-override-eglot 使其只移除不添加，防止变量监视器
;; (doom-modeline-battery) 触发时重新添加条目。
(after! doom-modeline
  (remove-hook 'eglot-managed-mode-hook #'doom-modeline-override-eglot)
  (remove-hook 'doom-modeline-mode-hook #'doom-modeline-override-eglot)
  (defun doom-modeline-override-eglot ()
    (setq mode-line-misc-info
          (cl-remove-if
           (lambda (elt) (eq (car-safe elt) 'eglot--managed-mode))
           mode-line-misc-info)))
  (setq minor-mode-alist
        (cl-remove-if
         (lambda (elt)
           (eq (car-safe elt) 'eglot--managed-mode))
         minor-mode-alist))
  (doom-modeline-override-eglot))

(with-eval-after-load 'which-key
  (set-face-attribute 'which-key-key-face nil :family "IBM Plex Mono")
  (set-face-attribute 'which-key-command-description-face nil :family "IBM Plex Mono")
  (set-face-attribute 'which-key-separator-face nil :family "IBM Plex Mono"))


(defun color-alpha (color alpha &optional bg)
  "返回 COLOR 按 ALPHA 混合到 BG（默认黑色）的标准 #RRGGBB 颜色，可用于 Emacs face。"
  (let* ((bg (or bg "#000000"))
         ;; 如果 color 已经是 #RRGGBB，就手动解析
         (parse-hex
          (lambda (hex)
            (list (/ (string-to-number (substring hex 1 3) 16) 255.0)
                  (/ (string-to-number (substring hex 3 5) 16) 255.0)
                  (/ (string-to-number (substring hex 5 7) 16) 255.0))))
         (fg-rgb (funcall parse-hex color))
         (bg-rgb (funcall parse-hex bg))
         ;; 混合每个通道
         (r (+ (* alpha (nth 0 fg-rgb)) (* (- 1 alpha) (nth 0 bg-rgb))))
         (g (+ (* alpha (nth 1 fg-rgb)) (* (- 1 alpha) (nth 1 bg-rgb))))
         (b (+ (* alpha (nth 2 fg-rgb)) (* (- 1 alpha) (nth 2 bg-rgb)))))
    ;; 转回 #RRGGBB
    (format "#%02x%02x%02x"
            (floor (* r 255))
            (floor (* g 255))
            (floor (* b 255)))))

(defvar my/modeline-glyphs-alpha-fallback 0.65
  "预混合 Powerline 分隔符时使用的兜底 alpha（glass 尚未应用时）。
应等于 lr-macos-glass 中 max(alpha-background, glyphs-min-alpha)，
也就是非默认 glyph 背景（含 modeline segment）真正使用的 alpha。
注意：不是 `alpha-background'，而是 `ns-alpha-glyphs-alpha'。")

(defun my/modeline-glyphs-enabled-p ()
  "mode line 现在由 Emacs 补丁单独保持不透明，Powerline 分隔符直接用实色即可。
补丁 ~/.config/emacs-plus/ns-glass-effect.patch 按 glyph row 的 `mode_line_p'
判断：mode line 的 glyph 背景始终以 alpha=1 绘制，其余地方照常透明。
因此这里固定返回 nil，不做预混合。"
  nil)

(defun my/modeline-glyphs-alpha ()
  "返回当前 frame 用于非默认 glyph 背景（含 modeline segment）的 alpha。
Powerline 分隔符是不透明 XPM 图片，必须用这个 alpha 预混合，才能和半透明的
segment 背景颜色对齐；若 glyph 背景不透明（未启用 ns-alpha-glyphs）则返回 1。"
  (if (not (my/modeline-glyphs-enabled-p))
      1.0
    (let ((glyph (frame-parameter nil 'ns-alpha-glyphs-alpha))
          (base  (frame-parameter nil 'alpha-background)))
      (cond (glyph glyph)
            (base (if (boundp 'salih/ns-alpha-glyphs-min-alpha)
                      (max base salih/ns-alpha-glyphs-min-alpha)
                    base))
            (t my/modeline-glyphs-alpha-fallback)))))

(defun my/modeline-alpha (face attr)
  "取 FACE 的 ATTR 颜色，按当前 glyph 背景 alpha 预混合后返回。
用于 Powerline 分隔符：分隔符是图片、以不透明方式绘制，而 segment 背景会被
透明补丁按 glyph alpha 混合，所以必须让分隔符颜色等于\"混合后的实色\"。"
  (let* ((color (and (facep face) (face-attribute face attr nil t)))
         (alpha (my/modeline-glyphs-alpha))
         (bg (or (face-background 'default) "#000000")))
    (if (and (stringp color)
             (string-match-p "\\`#[0-9a-fA-F]\\{6\\}\\'" color)
             (< alpha 1.0))          ; alpha=1 时原样返回，避免浮点取整 +/-1
        (color-alpha color alpha bg)
      color)))

(defconst my/modeline-alpha-faces
  '((doom-modeline-buffer-file-alpha        . doom-modeline-buffer-file)
    (doom-modeline-evil-normal-alpha-state  . doom-modeline-evil-normal-state)
    (doom-modeline-evil-insert-alpha-state  . doom-modeline-evil-insert-state)
    (doom-modeline-evil-visual-alpha-state  . doom-modeline-evil-visual-state)
    (doom-modeline-evil-replace-alpha-state . doom-modeline-evil-replace-state)
    (doom-modeline-evil-motion-alpha-state  . doom-modeline-evil-motion-state)
    (doom-modeline-major-mode-alpha         . doom-modeline-major-mode-state)
    (doom-modeline-git-alpha                . doom-modeline-git-state)
    (doom-modeline-time-alpha               . doom-modeline-time-state)
    (doom-modeline-mode-line-alpha          . mode-line))
  "Powerline 专用 `-alpha' face 及其对应的 segment face。")

(defun my/refresh-modeline-alpha-faces ()
  "按当前 glass alpha 重算 Powerline 分隔符 face 颜色。"
  (when (facep 'doom-modeline)
    (dolist (pair my/modeline-alpha-faces)
      (let ((face (car pair))
            (color (my/modeline-alpha (cdr pair) :background)))
        (unless (facep face) (make-face face))   ; set-face-attribute 不会自动建 face
        (set-face-attribute face nil
                            :inherit 'doom-modeline
                            ;; 颜色算不出来时传 nil 同样会告警，回退到 `unspecified'
                            :background (or (and (stringp color) color) 'unspecified)
                            :foreground "black"
                            :weight 'bold)))))

;; glass 参数一变（切 preset / 调 alpha），立刻重算分隔符颜色
(with-eval-after-load 'lr-macos-glass
  (dolist (fn '(salih/--apply-glass salih/toggle-glass salih/set-glass
                salih/set-glass-style salih/set-glass-glyph-alpha))
    (advice-add fn :after (lambda (&rest _) (my/refresh-modeline-alpha-faces))))
  (my/refresh-modeline-alpha-faces))

;;; 按"相邻段色差最大"自动给 modeline 各段挑主题颜色 ---------------------
;; 颜色全部取自主题 face（`my/modeline-color-faces'），不写死十六进制；
;; 每次加载主题时重新计算，具体会选中哪个 face 不固定——换主题也能自适应。
(defvar my/modeline-color-faces
  '(font-lock-variable-name-face   ; 蓝紫（默认作为 NORMAL 的锚点）
    font-lock-string-face          ; 绿
    font-lock-type-face            ; 棕
    font-lock-warning-face         ; 琥珀
    font-lock-keyword-face         ; 青
    font-lock-builtin-face         ; 浅青
    font-lock-constant-face        ; 藕荷
    font-lock-preprocessor-face    ; 紫
    error                          ; 红
    show-paren-match)              ; 薄荷
  "候选主题 face。modeline 各段的颜色从这里按色差自动挑选。
想扩宽可选色，往这个列表里加 face 即可（取它们的 :foreground 作为颜色）。
列表顺序在同分时也作为优先级。")

(defvar my/modeline-preferred-normal
  '(font-lock-variable-name-face)
  "NORMAL 段优先使用的主题 face，按顺序取第一个存在的。
留空则不锚定，完全交给算法挑。这里写的是主题 face（主题变量），不是写死颜色。")

(defvar my/modeline-role-faces
  '((major . font-lock-keyword-face)         ; 右侧 Org / major-mode → 青
    (git   . font-lock-warning-face)         ; 右侧 master / git 分支 → 琥珀
    (time  . font-lock-variable-name-face))  ; 右侧 时间 → 蓝紫
  "右侧三段固定的主题 face（用户选的 3 号的右侧配色）。
这些角色不参与自动挑色，直接用这里指定的主题 face 取色；
写成主题 face（主题变量），不写死颜色。留空则右侧也交给算法自动挑。")

(defconst my/modeline-segment-adjacency
  '((normal   filename visual insert)          ; NORMAL / git 分支
    (filename normal visual insert replace motion) ; 文件名挨着任意 evil 状态
    (visual   normal filename)                 ; major-mode(Org)
    (insert   normal filename)                 ; 时间
    (replace  filename)
    (motion   filename))
  "各颜色角色之间的\"相邻\"关系：这些段会直接贴在一起，
所以它们的颜色必须尽量拉开。")

(defvar my/modeline-colors nil
  "`my/modeline-update-colors' 算出的 (角色 . 颜色) 表，供段与分隔符取用。")

(defun my/modeline--face-color (face)
  "取 FACE 的前景色（主题变量）；取不到或不合法时返回 nil。"
  (let ((c (and (facep face) (face-foreground face nil t))))
    (and (stringp c)
         (string-match-p "\\`#[0-9a-fA-F]\\{6\\}\\'" c)
         c)))

(defun my/modeline--hex->rgb (color)
  "把 \"#RRGGBB\" 转成 `color-distance' 要的 (R G B) 列表（0-65535）。"
  (when (and (stringp color)
             (string-match-p "\\`#[0-9a-fA-F]\\{6\\}\\'" color))
    (list (* 257 (string-to-number (substring color 1 3) 16))
          (* 257 (string-to-number (substring color 3 5) 16))
          (* 257 (string-to-number (substring color 5 7) 16)))))

(defun my/modeline--color-distance (a b)
  "A、B 两色的感知距离。用整数 RGB 调 `color-distance'，解析失败返回 0。"
  (let ((ra (my/modeline--hex->rgb a))
        (rb (my/modeline--hex->rgb b)))
    (if (and ra rb)
        (condition-case nil (color-distance ra rb) (error 0))
      0)))

(defun my/modeline--greedy-colors (cands roles)
  "候选不足/过多时的兜底：按相邻关系贪心挑色。CANDS 为 (FACE . COLOR)。"
  (let (assigned used)
    (dolist (role roles)
      (let* ((avoid (delq nil (mapcar (lambda (r) (cdr (assq r assigned)))
                                      (cdr (assq role my/modeline-segment-adjacency)))))
             (best nil) (bd -1))
        (dolist (c cands)
          (unless (member (cdr c) used)
            (let ((d (if avoid
                         (cl-loop for x in avoid minimize (my/modeline--color-distance (cdr c) x))
                       0)))
              (when (> d bd) (setq best c bd d)))))
        (unless best (setq best (car cands)))
        (push (cons role (cdr best)) assigned)
        (push (cdr best) used)))
    (nreverse assigned)))

(defun my/modeline-update-colors ()
  "按\"相邻段色差最大\"从 `my/modeline-color-faces' 给各角色挑颜色。
最大化\"最小相邻色差\"，结果存入 `my/modeline-colors'。
颜色全部来自主题 face，每次加载主题都重算，所以挑中哪个 face 不写死。
若 `my/modeline-preferred-normal' 里的 face 存在，则 NORMAL 段用它作锚点，
其余段再按色差自动挑。"
  (let* ((cands (cl-remove-duplicates
                 (delq nil (mapcar (lambda (f)
                                     (let ((c (my/modeline--face-color f)))
                                       (and c (cons f c))))
                                   my/modeline-color-faces))
                 :key #'cdr :test #'string=))
         (roles '(normal filename visual insert replace motion))
         (n (length cands))
         (anchor-color (cl-loop for f in my/modeline-preferred-normal
                                for c = (cdr (assq f cands))
                                when c return c))
         (anchor-idx (and anchor-color
                          (cl-position anchor-color cands :key #'cdr :test #'string=)))
         (role-pos (cl-loop for r in roles for i from 0 collect (cons r i)))
         (pair-pos (cl-loop for cell in my/modeline-segment-adjacency
                            append (cl-loop for nb in (cdr cell)
                                            collect (cons (cdr (assq (car cell) role-pos))
                                                          (cdr (assq nb role-pos)))))))
    (if (or (< n (length roles))
            (and (null anchor-idx) (> n 8)))
        ;; 候选太少，或（未锚定时）太多：不枚举，贪心兜底
        (setq my/modeline-colors (my/modeline--greedy-colors cands roles))
      ;; 预计算 n×n 色差矩阵，枚举分配时只查表，避免重复算距离
      (let ((mat (make-vector (* n n) 0)))
        (cl-loop for i below n do
                 (cl-loop for j below n do
                          (aset mat (+ (* i n) j)
                                (if (= i j) 0
                                  (my/modeline--color-distance
                                   (cdr (nth i cands)) (cdr (nth j cands)))))))
        ;; 给各角色选不同颜色，最大化"最小相邻色差"；锚点时先钉住 NORMAL。
        ;; 直接递归到目标深度，并对每个叶子只做查表。
        (let ((best nil) (best-score -1) (v (make-vector (length roles) 0)))
          (when anchor-idx (aset v 0 anchor-idx))   ; v[0] 固定是 normal
          (cl-labels ((search (remaining depth)
                        (if (= depth (length roles))
                            (let ((score (cl-loop for (p . q) in pair-pos
                                                  minimize (aref mat (+ (* (aref v p) n)
                                                                        (aref v q))))))
                              (when (> score best-score)
                                (setq best-score score best (append v nil))))
                          (dolist (i remaining)
                            (aset v depth i)
                            (search (remove i remaining) (1+ depth))))))
            (search (if anchor-idx
                        (remove anchor-idx (number-sequence 0 (1- n)))
                      (number-sequence 0 (1- n)))
                    (if anchor-idx 1 0)))
          (when best
            (setq my/modeline-colors
                  (cl-mapcar #'cons roles
                             (mapcar (lambda (i) (cdr (nth i cands))) best))))))
    ;; 右侧三段用固定配色（`my/modeline-role-faces'），不参与上面的自动挑色。
    (dolist (cell my/modeline-role-faces)
      (let ((color (my/modeline--face-color (cdr cell))))
        (when color
          (setf (alist-get (car cell) my/modeline-colors) color))))
    my/modeline-colors)))

(defun my/modeline-role-color (role)
  "取 ROLE 对应的主题颜色；没算出来时回退到 string face 的颜色。"
  (or (cdr (assq role my/modeline-colors))
      (my/modeline--face-color 'font-lock-string-face)
      (face-foreground 'default nil t)))

(defun my/create-modeline-fontset ()
  (create-fontset-from-fontset-spec
   "-*-JetBrains Mono-normal-*-*-*-17-*-*-*-*-*-fontset-modeline,
   han:-*-Noto Serif CJK SC-bold-*-*-*-16-*-*-*-*-*-*,
   cjk-misc:-*-Noto Serif CJK SC-bold-*-*-*-16-*-*-*-*-*-*"))

(defun my/create-modeline-big-fontset ()
  (create-fontset-from-fontset-spec
   "-*-JetBrains Mono-normal-*-*-*-20-*-*-*-*-*-fontset-modeline,
   han:-*-Noto Serif CJK SC-bold-*-*-*-19-*-*-*-*-*-*,
   cjk-misc:-*-Noto Serif CJK SC-bold-*-*-*-19-*-*-*-*-*-*"))
(add-hook 'doom-load-theme-hook
(lambda ()
(with-eval-after-load 'doom-modeline
  ;; 主题一变，重新按"相邻段色差最大"挑一遍各段颜色
  (my/modeline-update-colors)
  ;(let ((highlight-foreground (face-attribute 'org-date-selected :foreground))
  ;      (highlight-background (face-attribute 'org-date-selected :background)))
  ;  (custom-set-faces  '(indent-bars-face                  ((t (:family "Kode Mono" ))))
  ;                     `(+workspace-tab-selected-face      ((t (:family "IBM Plex Mono" :box nil :foreground "black" :background ,highlight-foreground :weight bold))))
  ;                     '(+workspace-tab-face               ((t (:family "IBM Plex Mono" :box nil :weight bold))))))

  ;(set-face-attribute 'doom-modeline-time nil
  ;                    :foreground (face-attribute 'org-level-2 :foreground nil t)
  ;                    :background (face-attribute 'doom-modeline-evil-insert-state :foreground nil t)
  ;                    :weight 'bold)


  (set-face-attribute 'doom-modeline-buffer-file nil
                      :fontset (my/create-modeline-fontset)
                      :foreground "black"
                      :background (my/modeline-role-color 'filename)
                      :weight 'bold)
  (set-face-attribute 'doom-modeline-buffer-modified nil
                      :fontset (my/create-modeline-fontset)
                      :foreground "#45556C"
                      :background (my/modeline-role-color 'filename)
                      :weight 'bold)
  (defface doom-modeline-buffer-file-alpha
    '((t :inherit doom-modeline))
    "group doc"
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-buffer-file-alpha nil
                    :background (my/modeline-alpha 'doom-modeline-buffer-file :background)
                    :foreground "black"
                    :weight 'bold)

  (set-face-attribute 'doom-modeline-panel nil
                    :inherit 'doom-modeline
                    :foreground "#68f3ca"
                    ;; `set-face-attribute' 不再接受 nil，必须显式用 `unspecified'
                    ;; （否则启动时告警：nil value is invalid）。
                    :background 'unspecified)

  (set-face-attribute 'doom-modeline-evil-normal-state nil
                    :inherit 'doom-modeline
                    :background (my/modeline-role-color 'normal)
                    :foreground "black"
                    :weight 'bold)
  (defface doom-modeline-evil-normal-alpha-state
    '((t :inherit doom-modeline))
    "group doc"
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-evil-normal-alpha-state nil
                    :background (my/modeline-alpha 'doom-modeline-evil-normal-state :background)
                    :foreground "black"
                    :weight 'bold)

  (set-face-attribute 'doom-modeline-evil-insert-state nil
                      :inherit 'doom-modeline
                      :background (my/modeline-role-color 'insert)
                      :foreground "black"
                      :weight 'bold)
  (defface doom-modeline-evil-insert-alpha-state
    '((t :inherit doom-modeline))
    "group doc"
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-evil-insert-alpha-state nil
                    :background (my/modeline-alpha 'doom-modeline-evil-insert-state :background)
                    :foreground "black"
                    :weight 'bold)

  (set-face-attribute 'doom-modeline-evil-visual-state nil
                      :inherit 'doom-modeline
                      :foreground "black"
                      :background (my/modeline-role-color 'visual)
                      :weight 'bold)
  (defface doom-modeline-evil-visual-alpha-state
    '((t :inherit doom-modeline))
    "group doc"
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-evil-visual-alpha-state nil
                    :background (my/modeline-alpha 'doom-modeline-evil-visual-state :background)
                    :foreground "black"
                    :weight 'bold)

  (set-face-attribute 'doom-modeline-evil-replace-state nil
                      :inherit 'doom-modeline
                      :background (my/modeline-role-color 'replace)
                      :foreground "black"
                      :weight 'bold)
  (defface doom-modeline-evil-replace-alpha-state
    '((t :inherit doom-modeline))
    "group doc"
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-evil-replace-alpha-state nil
                    :background (my/modeline-alpha 'doom-modeline-evil-replace-state :background)
                    :foreground "black"
                    :weight 'bold)

  (set-face-attribute 'doom-modeline-evil-motion-state nil
                      :inherit 'doom-modeline
                      :background (my/modeline-role-color 'motion)
                      :foreground "black"
                      :weight 'bold)
  (defface doom-modeline-evil-motion-alpha-state
    '((t :inherit doom-modeline))
    "group doc"
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-evil-motion-alpha-state nil
                    :background (my/modeline-alpha 'doom-modeline-evil-motion-state :background)
                    :foreground "black"
                    :weight 'bold)

  ;; 右侧三段独立配色（来自用户选的 3 号的右侧），不再与左侧 evil 状态共用颜色。
  (defface doom-modeline-major-mode-state
    '((t :inherit doom-modeline))
    "group doc"
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-major-mode-state nil
                    :inherit 'doom-modeline
                    :background (my/modeline-role-color 'major)
                    :foreground "black"
                    :weight 'bold)
  (defface doom-modeline-major-mode-alpha
    '((t :inherit doom-modeline))
    "group doc"
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-major-mode-alpha nil
                    :background (my/modeline-alpha 'doom-modeline-major-mode-state :background)
                    :foreground "black"
                    :weight 'bold)

  (defface doom-modeline-git-state
    '((t :inherit doom-modeline))
    "group doc"
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-git-state nil
                    :inherit 'doom-modeline
                    :background (my/modeline-role-color 'git)
                    :foreground "black"
                    :weight 'bold)
  (defface doom-modeline-git-alpha
    '((t :inherit doom-modeline))
    "group doc"
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-git-alpha nil
                    :background (my/modeline-alpha 'doom-modeline-git-state :background)
                    :foreground "black"
                    :weight 'bold)

  (defface doom-modeline-time-state
    '((t :inherit doom-modeline))
    "group doc"
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-time-state nil
                    :inherit 'doom-modeline
                    :background (my/modeline-role-color 'time)
                    :foreground "black"
                    :weight 'bold)
  (defface doom-modeline-time-alpha
    '((t :inherit doom-modeline))
    "group doc"
    :group 'doom-modeline)
  (set-face-attribute 'doom-modeline-time-alpha nil
                    :background (my/modeline-alpha 'doom-modeline-time-state :background)
                    :foreground "black"
                    :weight 'bold)

  (my/refresh-modeline-alpha-faces)
  (fresh/modelineconfig)
  (add-hook '+workspace-new-hook #'fresh/modelineconfig)
  )))

;;; 关闭 modeline 上的所有鼠标行为 ---------------------------------------
;; mode-line 各段字符串会带 help-echo(悬浮提示)/mouse-face(悬浮高亮)/
;; local-map & keymap(鼠标点击)/pointer(手型光标) 等文本属性, 鼠标移上去会
;; 弹提示、变高亮、还能点击。这里在 doom-modeline 生成 mode-line 段的唯一
;; 入口 `doom-modeline--prepare-segments' 上做 :around 处理, 把每个段求值结果
;; 里的鼠标属性递归剥掉, 只保留 face/display 等绘制属性。内置段
;; (buffer-encoding 等)与自定义段(my-major-mode 等)因此一次全部生效, 且不受
;; `fresh/modelineconfig' 反复重定义段的影响。
(defun my/modeline-strip-mouse (value)
  "递归移除 VALUE 上所有鼠标相关文本属性, 保留 face/display 等绘制属性。"
  (cond
   ((stringp value)
    (condition-case nil
        (remove-text-properties
         0 (length value)
         '(help-echo nil mouse-face nil local-map nil keymap nil
           pointer nil mouse-1 nil mouse-2 nil mouse-3 nil)
         value)
      (error nil))
    value)
   ((consp value)
    (dolist (elt value) (my/modeline-strip-mouse elt))
    value)
   (t value)))

(defun my/modeline--prepare-segments-strip (orig segments)
  "让每个 mode-line 段求值后都经过 `my/modeline-strip-mouse'。"
  (mapcar
   (lambda (form)
     (cond
      ((and (consp form) (eq (car form) :eval))
       (list :eval (list 'my/modeline-strip-mouse (cadr form))))
      ((stringp form)
       (my/modeline-strip-mouse form))
      (t form)))
   (funcall orig segments)))

(after! doom-modeline
  (unless (advice-member-p #'my/modeline--prepare-segments-strip
                           'doom-modeline--prepare-segments)
    (advice-add 'doom-modeline--prepare-segments
                :around #'my/modeline--prepare-segments-strip))
  ;; 内置 modeline 在上面 advice 安装前就已定义, 这里重新生成所有已注册的
  ;; modeline, 让既有定义也走一遍上面的包装。
  (dolist (def doom-modeline--modelines)
    (when (cdr def)
      (doom-modeline-def-modeline (car def) (cadr def) (caddr def)))))

; available value of separator
;; arrow, arrow, arrow, arrow, arrow, arrow, wave, arrow, and nil.
(defun fresh/modelineconfig ()
  (doom-modeline-def-segment my-segment
    "My custom segment "
    (let ((face
           (if (doom-modeline--active)
               (cond
                ((eq evil-state 'normal)   'doom-modeline-evil-normal-state)
                ((eq evil-state 'insert)   'doom-modeline-evil-insert-state)
                ((eq evil-state 'visual)   'doom-modeline-evil-visual-state)
                ((eq evil-state 'replace)  'doom-modeline-evil-replace-state)
                ((eq evil-state 'motion)   'doom-modeline-evil-motion-state)
                (t                         'doom-modeline-evil-normal-state))
             'doom-modeline-evil-normal-state))
          (charc
           (cond
            ((eq evil-state 'normal)  " NORMAL ")
            ((eq evil-state 'insert)  " INSERT ")
            ((eq evil-state 'visual)  " VISUAL ")
            ((eq evil-state 'replace) " REPLACE ")
            ((eq evil-state 'emacs)   " EMACS ")
            ((eq evil-state 'motion)  " MOTION ")
            (t " EMACS "))))
      (concat
       (propertize (concat "" charc "") 'face face))))
  (doom-modeline-def-segment powerline-evil-right
    "Insert a Powerline separator into the Doom Modeline."
    (let* ((separator 'arrow) ;; 获取当前分隔符
           (separator-fn (intern (format "powerline-%s-%s"
                                         separator
                                         (cdr powerline-default-separator-dir))))) ;; 获取分隔符函数
      (propertize " " 'display (funcall separator-fn
                                        (if (doom-modeline--active)
                                            (cond
                                             ((eq evil-state 'normal)   'doom-modeline-evil-normal-alpha-state)
                                             ((eq evil-state 'insert)   'doom-modeline-evil-insert-alpha-state)
                                             ((eq evil-state 'visual)   'doom-modeline-evil-visual-alpha-state)
                                             ((eq evil-state 'replace)  'doom-modeline-evil-replace-alpha-state)
                                             ((eq evil-state 'motion)   'doom-modeline-evil-motion-alpha-state)
                                             (t                         'doom-modeline-evil-normal-alpha-state))
                                          'doom-modeline-evil-normal-alpha-state)
                                        'doom-modeline-mode-line-alpha ))))

  ;; 直接从 evil-state 段过渡到文件名段：只用一个箭头。
  ;; 原来的 `powerline-evil-right' + `powerline-filename-right-1' 会在中间
  ;; 露出 mode-line 底色，形成一个箭头形状的空白；这里把目标 face 直接设成
  ;; `doom-modeline-buffer-file-alpha'，让两个色块无缝衔接。
  (doom-modeline-def-segment powerline-evil-filename-right
    "Powerline separator from the evil-state segment straight into the buffer-file segment."
    (propertize " " 'display
                (powerline-arrow-left
                 (if (doom-modeline--active)
                     (cond
                      ((eq evil-state 'normal)   'doom-modeline-evil-normal-alpha-state)
                      ((eq evil-state 'insert)   'doom-modeline-evil-insert-alpha-state)
                      ((eq evil-state 'visual)   'doom-modeline-evil-visual-alpha-state)
                      ((eq evil-state 'replace)  'doom-modeline-evil-replace-alpha-state)
                      ((eq evil-state 'motion)   'doom-modeline-evil-motion-alpha-state)
                      (t                         'doom-modeline-evil-normal-alpha-state))
                   'doom-modeline-evil-normal-alpha-state)
                 'doom-modeline-buffer-file-alpha)))

  (doom-modeline-def-segment powerline-filename-right-1
    "Insert a Powerline separator into the Doom Modeline."
    (propertize " " 'display
                (powerline-arrow-left
                 'doom-modeline-mode-line-alpha
                 'doom-modeline-buffer-file-alpha)))

  (doom-modeline-def-segment powerline-filename-right-2
    "Insert a Powerline separator into the Doom Modeline."
    (propertize " " 'display
                (powerline-arrow-left
                 'doom-modeline-buffer-file-alpha
                 'doom-modeline-mode-line-alpha)))

  (doom-modeline-def-segment powerline-separator-right-vert
    "Insert a Powerline separator into the Doom Modeline."
    (propertize " " 'display
                (powerline-arrow-right
                 'doom-modeline-evil-normal-alpha-state
                 'doom-modeline-mode-line-alpha)))

  (doom-modeline-def-segment powerline-separator-left
    "Insert a Powerline separator into the Doom Modeline."
    (propertize " " 'display
        (powerline-arrow-right
                'doom-modeline-mode-line-alpha
                'doom-modeline-major-mode-alpha)))

  (doom-modeline-def-segment powerline-separator-left-vcs
    "Insert a Powerline separator into the Doom Modeline."
    (propertize " " 'display
        (powerline-arrow-right
                'doom-modeline-mode-line-alpha
                'doom-modeline-evil-normal-alpha-state)))

  (doom-modeline-def-segment powerline-separator-left-time
    "Insert a Powerline separator into the Doom Modeline."
    (propertize " " 'display
        (powerline-arrow-right
                'doom-modeline-mode-line-alpha
                'doom-modeline-time-alpha)))

  (doom-modeline-def-segment powerline-separator-left-time-db
    "Insert a Powerline separator into the Doom Modeline."
    (propertize " " 'display
        (powerline-arrow-right
                'doom-modeline-evil-normal-alpha-state
                'doom-modeline-mode-line-alpha)))

  (doom-modeline-def-segment powerline-separator-left-git-empty
    "Insert a Powerline separator into the Doom Modeline."
    (propertize " " 'display
        (powerline-arrow-right
                'doom-modeline-major-mode-alpha
                'doom-modeline-mode-line-alpha)))

  ;; 右侧：major-mode(Org) -> git 分支(master)，直接过渡。
  ;; 原来的 `powerline-separator-left-git-empty' + `powerline-separator-left-vcs'
  ;; 会在两个色块之间露出 mode-line 底色（左侧那个箭头空白问题的镜像）。
  ;; 这里合成一个箭头；没有 git 分支时本段为空，交给下面的 mt 段处理过渡。
  (doom-modeline-def-segment powerline-separator-left-om
    "Direct Powerline separator from major-mode straight into the git branch."
    (when (my-git-branch-with-dirty)
      (propertize " " 'display
        (powerline-arrow-right
                'doom-modeline-major-mode-alpha
                'doom-modeline-git-alpha))))

  ;; 右侧：git 分支(master) -> 时间，直接过渡。
  ;; 若当前不在 git 仓库，则退化为 major-mode(Org) -> 时间。
  (doom-modeline-def-segment powerline-separator-left-mt
    "Direct Powerline separator from the git branch straight into the time segment."
    (propertize " " 'display
        (powerline-arrow-right
                (if (my-git-branch-with-dirty)
                    'doom-modeline-git-alpha
                  'doom-modeline-major-mode-alpha)
                'doom-modeline-time-alpha)))


  (doom-modeline-def-segment my-major-mode
    "The major mode, including environment and text-scale info."
    (propertize
     (replace-regexp-in-string
      "/+\\(l\\|d\\)"
      ""
      (concat
       (doom-modeline-spc)
       (propertize (format-mode-line
                    (or (and (boundp 'delighted-modes)
                             (cadr (assq major-mode delighted-modes)))
                        mode-name))
                   'help-echo "Major mode\n\
                   mouse-1: Display major mode menu\n\
                   mouse-2: Show help for major mode\n\
                   mouse-3: Toggle minor modes"
                   'mouse-face 'doom-modeline-highlight
                   'local-map mode-line-major-mode-keymap)
       (when (and doom-modeline-env-version doom-modeline-env--version)
         (format "%s%s" (doom-modeline-vspc) doom-modeline-env--version))
       (and (boundp 'text-scale-mode-amount)
            (/= text-scale-mode-amount 0)
            (format
             (if (> text-scale-mode-amount 0)
                 " (%+d)"
               " (%-d)")
             text-scale-mode-amount))
       (doom-modeline-spc)))
     'face 'doom-modeline-major-mode-state))

  (doom-modeline-def-segment my-custom-segment
    (my-add-x-to-segment 'doom-modeline--major-mode-segment))
  (doom-modeline-def-segment wechat-msg-count
    "A custom segment that reads content from a local file."
    (propertize (concat "" (get-message-count)) 'face 'doom-modeline-evil-emacs-state))
  (doom-modeline-def-segment eyeMonitor-count
    "A custom segment that reads content from a local file."
    (let ((count (get-eyeMonitor-count)))  ; 定义局部变量 count
      (cond
       ((<= count 20) (propertize (concat "󰫃" "") 'face 'org-level-6) )
       ((<= count 40) (propertize (concat "󰫄" "") 'face 'org-level-4) )
       ((<= count 60) (propertize (concat "󰫅" "") 'face 'org-level-1) )
       ((<= count 80) (propertize (concat "󰫆" "") 'face 'org-level-5) )
       ((<= count 99) (propertize (concat "󰫇" "") 'face 'nerd-icons-lred) )
       ((= count 100) (propertize (concat "󰫈" "") 'face 'error) )
       (t (propertize (concat "󰫃" "") 'face 'diary)))))

  (doom-modeline-def-segment my-time
    "Display the current time in HH:mm:ss format."
    (propertize (format-time-string " %H:%M ")
                'face 'doom-modeline-time-state))
(defun my-buffer-file-name ()
  "Return a short file name for current buffer.
If another buffer has the same file name, include one parent directory
to disambiguate."
  (let ((filename (buffer-file-name)))
    (cond
     ;; 情况1：没有关联文件 → 返回缓冲区名
     ((not filename)
      (buffer-name))

     ;; 情况2：有文件名
     (t
      (let* ((basename (file-name-nondirectory filename))
             (dir (file-name-directory filename))
             (parent-dir (when dir
                           (file-name-nondirectory
                            (directory-file-name dir)))))
        ;; 检查是否有重复的文件名
        (if (and dir
                 (seq-some (lambda (buf)
                             (let ((other-file (buffer-file-name buf)))
                               (and other-file
                                    (not (eq buf (current-buffer)))
                                    (string= basename (file-name-nondirectory other-file)))))
                           (buffer-list)))
            ;; 有重复 → 显示 父目录/文件名
            (concat parent-dir "/" basename)
          ;; 无重复 → 只显示文件名
          basename))))))

  (doom-modeline-def-segment my-filename
    "Show buffer filename with disambiguation if needed."
    (concat
     ;; 文件类型图标：字形保留 nerd-icons 的颜色，但背景必须对齐文件名色块。
     ;; 不能用 `doom-modeline--buffer-mode-icon'：它会把图标和后面的半角空格
     ;; 都 inherit 到 `doom-modeline'（modeline 底色），于是色块里露出空隙。
     (when (doom-modeline-icon-displayable-p)
       (let ((icon (doom-modeline-icon-for-buffer)))
         (when (and (stringp icon) (not (string-empty-p icon)))
           (let ((face (get-text-property 0 'face icon)))
             (concat
              ;; 图标左侧留一个空格，让图标不贴着箭头、视觉上更居中。
              ;; 空格用文件名色块 face，背景与图标一致，不会露出底色。
              (propertize " " 'face 'doom-modeline-buffer-file)
              (propertize icon 'face
                          (append (if (listp face) face (list :inherit face))
                                  (list :foreground "black"
                                        :background (my/modeline-role-color 'filename)))))))))
     (propertize
      (concat " " (my-buffer-file-name) (if (buffer-modified-p) "꙳" "") " ")
      'face (if (buffer-modified-p)
                'doom-modeline-buffer-modified
              'doom-modeline-buffer-file))))
  (defun my-git-branch-with-dirty ()
    "Return git branch name, with * if buffer or repo is modified."
    (if-let* ((file (buffer-file-name))
                (backend (vc-backend file))
                ((eq backend 'Git))
                (branch (vc-git--symbolic-ref file)))
      (let ((state (vc-state file)))
        (concat " " branch (if (eq state 'up-to-date) "" "꙳") " "))
      " nil "))
  (doom-modeline-def-segment my-git-branch
    "Show git branch, with * if modified."
    (when-let ((branch (my-git-branch-with-dirty)))
      (concat
       ;; 分支图标：nerd 字形，黑色前景 + git 色块背景（与文件名段风格一致）。
       (when (doom-modeline-icon-displayable-p)
         (let ((icon (nerd-icons-devicon "nf-dev-git_branch")))
           (when (and (stringp icon) (not (string-empty-p icon)))
             (let ((face (get-text-property 0 'face icon)))
               (concat
                ;; 图标左侧留一个空格，避免贴着前面的箭头
                (propertize " " 'face 'doom-modeline-git-state)
                (propertize icon 'face
                            (append (if (listp face) face (list :inherit face))
                                    (list :foreground "black"
                                          :background (my/modeline-role-color 'git)))))))))
       (propertize branch 'face 'doom-modeline-git-state))))

  (doom-modeline-def-segment empty-segment
    (propertize (concat " " "") 'face 'doom-modeline-evil-emacs-state))
  ;; (display-battery-mode 1)
  (display-time-mode 1)
  (doom-modeline-def-modeline 'main
    '(my-segment powerline-evil-filename-right my-filename powerline-filename-right-2 wechat-msg-count matches parrot selection-info)
    '(misc-info minor-modes input-method buffer-encoding powerline-separator-left my-major-mode
      powerline-separator-left-om my-git-branch
        powerline-separator-left-mt my-time ))
  (doom-modeline-def-modeline 'vcs
    '(my-segment powerline-evil-right wechat-msg-count matches parrot selection-info)
    '(compilation misc-info  irc mu4e gnus github debug minor-modes buffer-encoding process empty-segment powerline-separator-left my-major-mode
      powerline-separator-left-git-empty powerline-separator-left-time my-time ))
  (doom-modeline-def-modeline 'dashboard
    '(modals buffer-default-directory-simple remote-host)
    '(my-segment)))

(defun get-message-count ()
  "Read the content of a specific file and return it as a string."
  (let ((file-path "~/.message"))
    (if (file-exists-p file-path)
        (with-temp-buffer
          (insert-file-contents file-path)
          (let ((content (string-trim (buffer-string))))
            (cond
             ((string= content "")  "")
             ((string= content "0") "")
             ((string= content "1") " 󰆄")
             ((string= content "2") " 󰆄")
             ((string= content "3") " 󰆄")
             ((string= content "4") " 󰆄")
             ((string= content "5") " 󰆄")
             ((string= content "6") " 󰆄")
             ((string= content "7") " 󰆄")
             ((string= content "8") " 󰆄")
             ((string= content "9") " 󰆄")
             (t " 󰆄"))))
      "File not found")))

(defun get-eyeMonitor-count ()
  "Read the content of a specific file and return it as a number."
  (let ((file-path "~/.eyeMonitor"))
    (if (file-exists-p file-path)
        (with-temp-buffer
          (insert-file-contents file-path)  ; 读取文件内容到缓冲区
          (let ((content (string-trim (buffer-string))))  ; 去除两端空白
            (if (string-empty-p content)  ; 如果内容为空，返回 0
                0
              (string-to-number content))))  ; 转换为数字
      0)))  ; 如果文件不存在，返回 0

(defun run-applescript ()
  (interactive "fSelect AppleScript file: ")
  (let ((output-buffer "*AppleScript Output*"))
    (shell-command "osascript /Users/van/Desktop/获取微信消息数量.scpt" output-buffer)
    (display-buffer output-buffer)))

;; (defun my-powerline-segment ()
;;   "Insert a Powerline separator into the mode-line."
;;   (let* ((separator (powerline-current-separator))
;;          (separator-fn (intern (format "powerline-%s-%s" separator (car powerline-default-separator-dir)))))
;;     (propertize " " 'display (funcall separator-fn 'doom-modeline-bar 'mode-line))))
(use-package powerline
  ;; :ensure t
  :config
  (setq powerline-default-separator 'arrow) ;; 分隔符样式
  (setq powerline-default-separator-dir '(right . left)))


;  (set-face-attribute 'doom-modeline-buffer-file nil :fontset (my/create-modeline-fontset))
;  (set-face-attribute 'doom-modeline-buffer-modified nil :fontset (my/create-modeline-fontset))

(defun my-modeline-fonts-on-big-font-mode ()
  (if doom-big-font-mode
      (progn
        (custom-set-faces
         '(indent-bars-face                  ((t (:family "Kode Mono" :height 210))))
         '(mode-line ((t (:family "IBM Plex Mono" :box nil :height 175))))
         '(mode-line-inactive ((t (:family "IBM Plex Mono" :box nil :height 175)))))
        (set-face-attribute 'doom-modeline-buffer-file nil :fontset (my/create-modeline-big-fontset))
        (set-face-attribute 'doom-modeline-buffer-modified nil :fontset (my/create-modeline-big-fontset)))
    (progn
      (custom-set-faces
       '(indent-bars-face                  ((t (:family "Kode Mono" :height 170))))
       '(mode-line ((t (:family "IBM Plex Mono" :box nil :height 150))))
       '(mode-line-inactive ((t (:family "IBM Plex Mono" :box nil :height 150)))))
      (set-face-attribute 'doom-modeline-buffer-file nil :fontset (my/create-modeline-fontset))
      (set-face-attribute 'doom-modeline-buffer-modified nil :fontset (my/create-modeline-fontset)))
    (setq powerline-scale (if doom-big-font-mode 1.5 1))
    (powerline-reset)))
(defun my-update-powerline-scale ()
  "Adjust powerline scale based on doom-big-font-mode."
  (setq powerline-scale (if doom-big-font-mode 1.5 1))
  (powerline-reset))

(add-hook 'doom-big-font-mode-hook 'my-modeline-fonts-on-big-font-mode)
(add-hook 'doom-big-font-mode-hook 'my-update-powerline-scale)


;; (add-hook 'doom-big-font-mode-hook #'reset-to-default-font)

(add-hook 'doom-modeline-mode-hook
          (lambda ()
            (setq doom-modeline-battery nil)
            (setq doom-modeline-spc "")    ; 替换普通分隔符
            (setq doom-modeline-wspc ""))  ; 替换宽空格
            (custom-set-faces
            '(+workspace-tab-face ((t (:family "IBM Plex Mono" :box nil :weight bold))))
            '(+workspace-tab-selected-face ((t (:family "IBM Plex Mono" :box nil :foreground "black" :background "Pink" :weight bold))))
            '(mode-line ((t (:family "IBM Plex Mono" :box nil :height 150 :underline nil))))
            '(mode-line-inactive ((t (:family "IBM Plex Mono" :box nil :height 150 :underline nil))))))

(after! indent-bars
  (custom-set-faces '(indent-bars-face ((t (:family "JetBrains Mono"))) t))
  (setq indent-bars-highlight-current-depth '(:blend 0.7 :bold t)))

(run-with-timer 0 1 'force-mode-line-update)
(add-hook 'after-init-hook
          (lambda ()
            (setq-local line-spacing nil)))

(map! :ne "; ;" (lambda () (interactive) (setq-local mode-line-format nil)))
