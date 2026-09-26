;;; lr-macos-glass.el --- Ghostty-like macOS glass frame -*- lexical-binding: t; -*-

(when (eq system-type 'darwin)
  ;; 标题栏是否透明：t=透明（露出玻璃材质），nil=不透明
  (defvar salih/ns-transparent-titlebar t
    "Non-nil makes the macOS titlebar transparent.")
  ;; 当前使用的玻璃预设名：macos-glass-regular / macos-glass-clear
  (defvar salih/glass-style 'macos-glass-regular
    "Current macOS glass preset.")
  ;; 帧背景 alpha：0.0=全透明，1.0=不透明（越大越"实"）。
  ;; 用原生玻璃时通常给个很小的值(≈0.01)让玻璃透出来；想更实就调大(0.3~0.7)
  (defvar salih/alpha-background 0.01
    "Frame background alpha used with native glass.")
  ;; CGS 背景模糊半径(整数)：0=不模糊。有原生材质时用不到；
  ;; 仅在"降级模式"(Emacs 没有原生玻璃支持)下才会生效
  (defvar salih/ns-background-blur 0
    "CGS background blur radius used with native glass.")
  ;; 哪些绘制元素参与 alpha-background 透明：ns-alpha-all=全部。
  ;; 也可按需单选（可组合）：
  ;;   ns-alpha-default  默认 face / 背景
  ;;   ns-alpha-fringe   边缘(fringe)与内边框清除区域
  ;;   ns-alpha-box      带 box 的 face 边框
  ;;   ns-alpha-stipple  stipple 遮罩背景
  ;;   ns-alpha-relief   3D relief/阴影线
  ;;   ns-alpha-glyphs   hl-line/选区 等"字形背景"填充
  ;; 全部启用（含 ns-alpha-glyphs）：hl-line、选区、org 代码块、补全弹框 都半透明，
  ;; 和帧背景(默认 face) 一致的玻璃感。
  ;; mode line 例外：由 ns-glass-effect.patch 按 glyph row 的 `mode_line_p' 判断，
  ;; 单独保持不透明——Powerline 分隔符是不透明图片，这样 segment 与箭头零色差，
  ;; 而其它"字形背景"照常透明。
  (defvar salih/ns-alpha-elements
    '(ns-alpha-default ns-alpha-fringe ns-alpha-box ns-alpha-stipple ns-alpha-relief
      ns-alpha-glyphs)
    "Frame elements that receive `alpha-background' (all, including glyphs).")
  ;; 非默认字形背景(hl-line/选区/补全高亮等)的最小 alpha。
  ;; 防止 alpha-background 很小时这些高亮彻底看不见（会自动取 max(alpha, 此值)）
  (defvar salih/ns-alpha-glyphs-min-alpha 0.24
    "Minimum alpha for non-default glyph backgrounds on native glass builds.")
  ;; 原生玻璃材质：regular(常规,毛玻璃感) / clear(更清透) / nil(关闭原生玻璃)
  (defvar salih/ns-glass-material 'regular
    "Native glass material: `regular', `clear', or nil.")
  ;; 玻璃上叠加"主题背景色"的不透明度：越大越偏主题色、越暗/越实
  (defvar salih/ns-glass-tint-opacity 0.05
    "Native glass tint opacity.")
  ;; 窗口失焦时叠加层的饱和度倍数：>1 更鲜艳
  (defvar salih/ns-glass-saturation 1.9
    "Native glass inactive overlay saturation multiplier.")
  ;; 窗口失焦时叠加层的不透明度：越大越遮挡/越暗；nil=不叠加
  (defvar salih/ns-glass-inactive-opacity 0.05
    "Native glass inactive overlay opacity.")
  ;; 玻璃视图的圆角半径（点）
  (defvar salih/ns-glass-corner-radius 2
    "Native glass corner radius.")
  ;; 【降级模式】Emacs 无原生玻璃支持时使用的 alpha-background
  (defvar salih/glass-fallback-alpha-background 0.70
    "Fallback alpha for Emacs builds without native glass material support.")
  ;; 【降级模式】Emacs 无原生玻璃支持时使用的 CGS 模糊半径
  (defvar salih/glass-fallback-background-blur 30
    "Fallback CGS blur for Emacs builds without native glass material support.")

  (defconst salih/glass-presets
    '((macos-glass-regular        ; 预设A：默认毛玻璃（salih/glass-style 的默认值；材质见下）
       :material  regular           ; 玻璃材质：clear=更清透/模糊更轻；regular=毛玻璃感更重
       :alpha 0.80                ; 帧背景 alpha：0=全透、1=不透明（越大越"实"）
       :glyphs-min-alpha 0.24     ; hl-line/选区等字形背景的最小 alpha
       :blur 0                    ; CGS 模糊半径（原生材质自带模糊，保持 0）
       :tint-opacity 0.35         ; 玻璃上叠主题色调的不透明度：越大越暗/越实
       :saturation 1.9            ; 窗口失焦时叠加层的饱和度倍数：>1 更鲜艳
       :inactive-opacity 0.05     ; 窗口失焦时叠加层不透明度：越大越暗；nil=不叠加
       :corner-radius 2           ; 玻璃区域圆角（点）
       :fallback-alpha 0.70       ; 【降级】无原生玻璃时的 alpha
       :fallback-blur 30)         ; 【降级】无原生玻璃时的模糊半径
      (macos-glass-clear          ; 预设B：更清透的玻璃
       :material clear            ; 材质 clear=清透
       :alpha 0.01                ; 帧背景 alpha（很小=几乎全透）
       :glyphs-min-alpha 0.22     ; 字形背景最小 alpha
       :blur 0                    ; CGS 模糊半径
       :tint-opacity 0.01         ; 玻璃色调不透明度（几乎不加色）
       :saturation 1.2            ; 失焦叠加层饱和度
       :inactive-opacity nil      ; 失焦时不做叠加
       :corner-radius 0           ; 圆角为 0
       :fallback-alpha 0.78       ; 【降级】alpha
       :fallback-blur 40))        ; 【降级】模糊半径
    "Ghostty-named presets available to `salih/set-glass-style'.")

  (defvar salih/--glass-build-warning-shown nil
    "Non-nil once the missing patched Emacs build warning was shown.")
  (defvar salih/--native-glass-build-p-cache :unset
    "Cached result of checking whether this Emacs supports native glass.")

  (defun salih/--plist-get (plist prop)
    "Return PROP from PLIST."
    (cadr (memq prop plist)))

  (defun salih/--glass-preset (style)
    "Return the glass preset for STYLE."
    (or (alist-get style salih/glass-presets)
        (user-error "Unknown glass style: %s" style)))

  (defun salih/--apply-glass-style-values (style)
    "Load STYLE values into the active glass variables."
    (let ((preset (salih/--glass-preset style)))
      (setq salih/glass-style style
            salih/ns-glass-material (salih/--plist-get preset :material)
            salih/alpha-background (salih/--plist-get preset :alpha)
            salih/ns-alpha-glyphs-min-alpha
            (salih/--plist-get preset :glyphs-min-alpha)
            salih/ns-background-blur (salih/--plist-get preset :blur)
            salih/ns-alpha-elements
            '(ns-alpha-default ns-alpha-fringe ns-alpha-box ns-alpha-stipple ns-alpha-relief
              ns-alpha-glyphs)
            salih/ns-glass-tint-opacity (salih/--plist-get preset :tint-opacity)
            salih/ns-glass-saturation (salih/--plist-get preset :saturation)
            salih/ns-glass-inactive-opacity
            (salih/--plist-get preset :inactive-opacity)
            salih/ns-glass-corner-radius (salih/--plist-get preset :corner-radius)
            salih/glass-fallback-alpha-background
            (salih/--plist-get preset :fallback-alpha)
            salih/glass-fallback-background-blur
            (salih/--plist-get preset :fallback-blur))))

  (salih/--apply-glass-style-values salih/glass-style)

  (defun salih/--emacs-binary-has-string-p (needle)
    "Return non-nil if the current Emacs executable contains NEEDLE."
    (let ((binary (or (car command-line-args)
                      (expand-file-name invocation-name invocation-directory))))
      (and binary
           (file-executable-p binary)
           (executable-find "strings")
           (with-temp-buffer
             (and (zerop (call-process "strings" nil t nil binary))
                  (progn
                    (goto-char (point-min))
                    (search-forward needle nil t)))))))

  (defun salih/--native-glass-build-p ()
    "Return non-nil if this Emacs binary exposes native glass parameters."
    (if (eq salih/--native-glass-build-p-cache :unset)
        (setq salih/--native-glass-build-p-cache
              (and (salih/--emacs-binary-has-string-p "ns-glass-material")
                   (salih/--emacs-binary-has-string-p "ns-alpha-glyphs-alpha")))
      salih/--native-glass-build-p-cache))

  (defun salih/--warn-unless-glass-build ()
    "Warn if this Emacs binary is missing the patched glass support."
    (unless salih/--glass-build-warning-shown
      (setq salih/--glass-build-warning-shown t)
      (unless (and (salih/--emacs-binary-has-string-p "ns-background-blur")
                   (salih/--emacs-binary-has-string-p "ns-alpha-elements")
                   (salih/--native-glass-build-p))
        (display-warning
         'lr-macos-glass
         "Liquid glass needs emacs-plus@31 built with frame-transparency and ns-glass-effect. The emacs-plus-app cask ignores ~/.config/emacs-plus/build.yml."
         :warning))))

  (defun salih/--effective-alpha-background ()
    "Return the alpha value for this Emacs build."
    (if (salih/--native-glass-build-p)
        salih/alpha-background
      salih/glass-fallback-alpha-background))

  (defun salih/--effective-background-blur ()
    "Return the blur value for this Emacs build."
    (if (salih/--native-glass-build-p)
        salih/ns-background-blur
      salih/glass-fallback-background-blur))

  (defun salih/--effective-alpha-glyphs-alpha ()
    "Return the alpha for non-default glyph backgrounds."
    (max (salih/--effective-alpha-background)
         salih/ns-alpha-glyphs-min-alpha))

  (defun salih/--theme-background ()
    "Return the active theme's default background, if it defines one."
    (let ((background (face-background 'default nil t)))
      (unless (or (memq background '(nil unspecified))
                  (member background '("unspecified-bg" "unspecified-fg")))
        background)))

  (defun salih/--theme-background-frame-parameters ()
    "Return a frame background parameter derived from the active theme."
    (let ((background (salih/--theme-background)))
      (when background
        `((background-color . ,background)))))

  (defun salih/--native-glass-frame-parameters ()
    "Return native glass frame parameters, when this Emacs supports them."
    (when (salih/--native-glass-build-p)
      `((ns-alpha-glyphs-alpha . ,(salih/--effective-alpha-glyphs-alpha))
        (ns-glass-material . ,salih/ns-glass-material)
        (ns-glass-tint-opacity . ,salih/ns-glass-tint-opacity)
        (ns-glass-saturation . ,salih/ns-glass-saturation)
        (ns-glass-inactive-opacity . ,salih/ns-glass-inactive-opacity)
        (ns-glass-corner-radius . ,salih/ns-glass-corner-radius))))

  (defun salih/--glass-frame-parameters ()
    "Return frame parameters for the current glass preset."
    (append
     (salih/--theme-background-frame-parameters)
     `((ns-transparent-titlebar . ,salih/ns-transparent-titlebar)
       (alpha-background . ,(salih/--effective-alpha-background))
       (ns-background-blur . ,(salih/--effective-background-blur))
       (ns-alpha-elements . ,salih/ns-alpha-elements))
     (salih/--native-glass-frame-parameters)))

  (defun salih/--opaque-frame-parameters ()
    "Return frame parameters for a solid opaque frame."
    (append
     (salih/--theme-background-frame-parameters)
     `((ns-transparent-titlebar . ,salih/ns-transparent-titlebar)
       (alpha-background . 1.0)
       (ns-background-blur . 0)
       (ns-alpha-elements . ,salih/ns-alpha-elements))
     (when (salih/--native-glass-build-p)
       '((ns-alpha-glyphs-alpha . nil)
         (ns-glass-material . nil)))))

  (dolist (parameter (salih/--glass-frame-parameters))
    (unless (eq (car parameter) 'background-color)
      (add-to-list 'default-frame-alist parameter)))

  (defun salih/--apply-glass (&optional frame)
    "Re-apply transparency and blur to FRAME."
    (when (display-graphic-p)
      (salih/--warn-unless-glass-build))
    (with-selected-frame (or frame (selected-frame))
      (dolist (parameter (salih/--glass-frame-parameters))
        (set-frame-parameter nil (car parameter) (cdr parameter)))))

  (defun salih/--apply-glass-after-theme (&rest _)
    "Re-apply glass after a theme changes the default face."
    (when (display-graphic-p)
      (salih/--apply-glass)))

  (add-hook 'doom-load-theme-hook #'salih/--apply-glass-after-theme)
  (advice-add 'load-theme :after #'salih/--apply-glass-after-theme)
  (add-hook 'after-make-frame-functions #'salih/--apply-glass)
  (unless (daemonp)
    (add-hook 'window-setup-hook #'salih/--apply-glass))
  (when (display-graphic-p)
    (salih/--apply-glass))

  (defun salih/toggle-glass ()
    "Toggle the glass effect on/off."
    (interactive)
    (let* ((current (frame-parameter nil 'alpha-background))
           (off (or (null current) (= current 1.0))))
      (modify-all-frames-parameters
       (if off
           (salih/--glass-frame-parameters)
         (salih/--opaque-frame-parameters)))
      (message "glass: %s alpha=%s glyph-alpha=%s blur=%s"
               (if off salih/glass-style 'off)
               (if off (salih/--effective-alpha-background) 1.0)
               (if off (salih/--effective-alpha-glyphs-alpha) nil)
               (if off (salih/--effective-background-blur) 0))))

  (defun salih/set-glass (alpha blur)
    "Set ALPHA (0.0-1.0) and BLUR radius (0-50) on every frame."
    (interactive "nAlpha (0.0-1.0): \nnBlur (0-50): ")
    (setq salih/alpha-background alpha
          salih/ns-background-blur blur)
    (modify-all-frames-parameters (salih/--glass-frame-parameters))
    (message "glass: alpha=%s glyph-alpha=%s blur=%s material=%s"
             (salih/--effective-alpha-background)
             (salih/--effective-alpha-glyphs-alpha)
             (salih/--effective-background-blur)
             (if (salih/--native-glass-build-p) salih/ns-glass-material 'fallback)))

  (defun salih/set-glass-glyph-alpha (alpha)
    "Set the minimum alpha for non-default glyph backgrounds."
    (interactive "nGlyph background alpha (0.0-1.0): ")
    (setq salih/ns-alpha-glyphs-min-alpha alpha)
    (modify-all-frames-parameters (salih/--glass-frame-parameters))
    (message "glass: glyph-alpha=%s" (salih/--effective-alpha-glyphs-alpha)))

  (defun salih/set-glass-style (style)
    "Apply a glass STYLE preset to every frame."
    (interactive
     (list (intern
            (completing-read
             "Glass style: "
             (mapcar (lambda (preset) (symbol-name (car preset)))
                     salih/glass-presets)
             nil t nil nil (symbol-name salih/glass-style)))))
    (salih/--apply-glass-style-values style)
    (modify-all-frames-parameters (salih/--glass-frame-parameters))
    (message "glass: %s alpha=%s glyph-alpha=%s blur=%s material=%s"
             style
             (salih/--effective-alpha-background)
             (salih/--effective-alpha-glyphs-alpha)
             (salih/--effective-background-blur)
             (if (salih/--native-glass-build-p) salih/ns-glass-material 'fallback))))

(provide 'lr-macos-glass)
