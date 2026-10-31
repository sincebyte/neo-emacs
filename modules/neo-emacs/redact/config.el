;;; neoemacs/redact/config.el -*- lexical-binding: t; -*-
;;
;; 屏幕遮挡（redaction）
;;
;; 目的：录屏时不要把密码 / 密钥 / 手机号以明文留在画面上。
;; 只改“显示层”：buffer 内容、kill-ring、保存到磁盘的文件都不变。
;; 遮挡串固定 6 个星号，不按原文长度生成，避免泄露密码长度。
;;
;; 用法：
;;   SPC t k    全局开关（默认开启）
;;
;; 识别范围：
;;   1. 凭据赋值：password=... / api_key: ... / "client_secret": "..."
;;   2. 已知形态的密钥：OpenAI / AWS / GitHub / GitLab / Slack / Google /
;;      Stripe / 阿里云 / 腾讯云 / JWT / Bearer token / 连接串里的密码
;;   3. 域名、中国大陆手机号
;;   4. 敏感词表 `redact-words'：人名、公司名等无法用正则识别的词
;;
;; 不识别：邮箱、身份证、银行卡、IP 地址。需要时把词加进 `redact-words'。

;;; Code:

(require 'subr-x)
(require 'seq)

;; `redact--fontify-window' 在 `define-minor-mode' 之前定义，先声明变量，
;; 避免字节编译时把它当成自由变量。
(defvar redact-mode)

(defgroup redact nil
  "在屏幕上遮挡敏感信息。"
  :group 'editing
  :prefix "redact-")

(defcustom redact-mask "******"
  "遮挡用的替换字符串。
固定长度，避免从星号个数反推原文长度。"
  :type 'string
  :group 'redact
  :set (lambda (sym val)
         (set-default sym val)
         (dolist (buf (buffer-list))
           (with-current-buffer buf
             (when (bound-and-true-p redact-mode)
               (font-lock-flush))))))

(defcustom redact-min-length 6
  "键值对中，值短于该长度时不遮挡。
短值通常是占位符（如 xxx、todo、123），遮了反而干扰阅读。"
  :type 'integer
  :group 'redact)

(defcustom redact-eager-fontify-max-size 2000000
  "启用遮挡时同步 fontify 整个 buffer 的大小上限（字节）。

遮挡依赖 font-lock 的 `display' 属性，而 jit-lock 默认等到 redisplay
才 fontify，屏幕上会先露出明文。为此启用时直接同步 fontify 整个 buffer。
超过该上限的大文件只同步处理可见窗口，其余区域由 jit-lock 兜底，滚动时
仍可能短暂露出原文；需要绝对安全时把它调大。"
  :type 'integer
  :group 'redact)

(defcustom redact-ignored-values
  '("password" "passwd" "pwd" "secret" "token"
    "changeme" "change-me" "change_me"
    "your_password" "your-password" "your_password_here"
    "your_api_key" "your-api-key" "your_token" "your-token"
    "null" "nil" "none" "true" "false"
    "todo" "test" "example" "sample" "placeholder" "redacted")
  "值黑名单（小写比较），命中时不遮挡。"
  :type '(repeat string)
  :group 'redact)

(defvar redact--words-cache nil
  "`redact-words' 的正则缓存，形如 (WORDS . REGEXP)。")

(defcustom redact-words nil
  "始终遮挡的词表，可配置多个。
用于人名、公司名、项目名等没有固定格式、无法用正则识别的词。
英文按整词匹配（van 不会命中 vanish），中文按子串匹配。
例如：

  (setq redact-words (quote (\"张三\" \"李四\" \"van\")))

启动时用 `setq' 即可；运行中增删建议用 `redact-add-word' /
`redact-remove-word'，或改完调用 `redact-refresh' 刷新已 fontify 的区域。"
  :type '(repeat string)
  :group 'redact
  :set (lambda (sym val)
         (set-default sym val)
         (setq redact--words-cache nil)
         (dolist (buf (buffer-list))
           (with-current-buffer buf
             (when (bound-and-true-p redact-mode)
               (font-lock-flush))))))

(defface redact-mask-face
  '((t :inherit shadow))
  "遮挡文本的外观。"
  :group 'redact)

;;; 正则

(defconst redact--credential-regexp
  (concat
   ;; 键名允许作为更长标识符的一部分（db_password、aws_secret_access_key），
   ;; 所以不加前缀匹配；否则贪婪前缀会把键名本身吞掉。
   "\\(?:password\\|passwd\\|pwd\\|passphrase"
   "\\|client[_-]?secret\\|secret[_-]?key\\|app[_-]?secret"
   "\\|api[_-]?key\\|apikey"
   "\\|access[_-]?key\\(?:[_-]?id\\)?"
   "\\|private[_-]?key"
   "\\|secret"
   "\\|jwt"
   "\\|auth[_-]?token\\|access[_-]?token\\|refresh[_-]?token"
   "\\|token"
   ;; 中文键名：密码、口令、密钥/秘钥、私钥、令牌、凭证/凭据
   "\\|密码\\|口令\\|密钥\\|秘钥\\|私钥\\|令牌\\|凭证\\|凭据\\)"
   "[\"']?[ \t]*\\(?:[:=：＝|｜]\\|%3D\\)[ \t]*[\"']?"
   ;; group 1：值本身。不吞引号/逗号/括号/表格竖线/查询串分隔符，
   ;; 避免把语法符号或后面的参数一起遮掉。
   ;; `]' 必须放在 `[^' 之后作为字符类的第一个字符，Emacs 不支持 `\\]'。
   ;; 同时排除中文标点，否则 `password=abc12345，电话' 会把“，电话”一起吞掉。
   "\\([^]，。；：、！？（）【】《》「」『』\"' \t\r\n,;})|｜&]+\\)")
  "匹配 `key = value' 形式（含中文键名与表格竖线），group 1 是值。")

(defconst redact--connection-regexp
  ;; 密码里可能有没有转义的 @（ftp://user:pass@word@host），
  ;; 所以贪婪吃到最后一个 @，把整段口令都遮掉。
  "\\(?:[[:alpha:]][[:alnum:]+.-]*\\)://[^:/@ \t\r\n]*:\\([^/ \t\r\n]+\\)@"
  "匹配 scheme://user:password@host，group 1 是密码。")

(defconst redact--placeholder-key-regexp
  "\\(?:password\\|passwd\\|pwd\\|passphrase\\|secret\\|jwt\\|token\\|credential\\|key\\)"
  "占位符名字里可能表示凭据的词。")

(defconst redact--placeholder-regexp
  (concat "\\${\\([^}:{} \t\r\n]*"
          redact--placeholder-key-regexp
          "[^}:{} \t\r\n]*\\):"
          ;; group 2：默认值，止于右花括号。
          "\\([^} \t\r\n]+\\)}")
  "匹配 Spring 占位符 `${key:default}'，group 2 是默认值。
`@Value(\"${uap.global.jwt:...}\")' 这类写法里的默认值常常就是真密钥，
而键名 `jwt' 又不在普通键值规则里，所以单独处理。")

(defconst redact--bearer-regexp
  "\\(?:[Bb]earer\\)[ \t]+\\([[:alnum:]._~+/=-]\\{16,\\}\\)"
  "匹配 `Bearer <token>'，group 1 是 token。")

(defconst redact--token-regexp
  (concat
   "\\(?:"
   ;; OpenAI / Anthropic
   "sk-[[:alnum:]_-]\\{16,\\}"
   ;; AWS access key id
   "\\|AKIA[0-9A-Z]\\{16\\}"
   ;; GitHub
   "\\|gh[pousr]_[[:alnum:]]\\{30,\\}"
   ;; GitLab
   "\\|glpat-[[:alnum:]_-]\\{20,\\}"
   ;; Slack
   "\\|xox[baprs]-[[:alnum:]-]\\{10,\\}"
   ;; Google
   "\\|AIza[0-9A-Za-z_-]\\{35\\}"
   ;; Stripe
   "\\|sk_live_[[:alnum:]]\\{20,\\}"
   ;; 阿里云 AccessKey ID
   "\\|LTAI[0-9A-Za-z]\\{12,\\}"
   ;; 腾讯云 SecretId
   "\\|AKID[0-9A-Za-z]\\{32,\\}"
   ;; JWT
   "\\|eyJ[[:alnum:]_-]\\{8,\\}\\.[[:alnum:]_-]\\{8,\\}\\.[[:alnum:]_-]\\{8,\\}"
   "\\)")
  "匹配无需键名的、形态足够特异的密钥。")

(defconst redact--phone-regexp
  "\\(?:\\+?86[- \t]?\\)?1[3-9][0-9]\\{9\\}"
  "中国大陆手机号；前后边界在 `redact--match-phone' 里检查。")

(defconst redact--domain-regexp
  (concat "\\(?:[a-zA-Z0-9-]+\\.\\)+"
          ;; TLD 白名单。刻意不含 sh/pl/md/rs/so/in/zip/cc 这些同时是
          ;; 代码文件扩展名的后缀，否则 run.sh、foo.pl、README.md 都会被遮。
          "\\(?:com\\|cn\\|net\\|org\\|io\\|co\\|tv\\|xyz\\|top\\|info\\|biz"
          "\\|dev\\|app\\|cloud\\|site\\|online\\|tech\\|vip\\|ltd\\|group"
          "\\|work\\|live\\|link\\|ai\\|hk\\|tw\\|jp\\|uk\\|us\\|de\\|ru\\|fr\\|sg\\)")
  "域名；前后边界和反向域名（Java 包名）在 `redact--match-domain' 里排除。")

(defconst redact--domain-ignore-first-labels
  '("com" "org" "net" "edu" "gov" "mil" "int" "cn" "io")
  "Java 包名等反向域名的常见开头，不按域名遮挡。")

(defun redact--build-words-regexp (words)
  "把 WORDS 编译成一个匹配正则。
纯 ASCII 的词加整词边界，避免 van 命中 vanish；含中文的词按子串匹配。"
  (let (ascii other)
    (dolist (word words)
      (if (string-match-p "\\`[[:ascii:]]+\\'" word)
          (push word ascii)
        (push word other)))
    (let ((parts nil))
      (when ascii
        (push (concat "\\<" (regexp-opt ascii) "\\>") parts))
      (when other
        (push (regexp-opt other) parts))
      (when parts
        (mapconcat #'identity (nreverse parts) "\\|")))))

(defun redact--words-regexp ()
  "返回 `redact-words' 对应的正则；词表变化时重建缓存。"
  (let ((words (delq nil
                     (mapcar (lambda (word)
                               (when (stringp word)
                                 (let ((w (string-trim word)))
                                   (unless (string-empty-p w) w))))
                             redact-words))))
    (if (and redact--words-cache
             (equal (car redact--words-cache) words))
        (cdr redact--words-cache)
      (setq redact--words-cache
            (cons words (redact--build-words-regexp words)))
      (cdr redact--words-cache))))

(defconst redact--pem-begin-regexp
  "-----BEGIN \\(?:[A-Z0-9 ]+\\)PRIVATE KEY-----"
  "PEM 私钥块起始行。")

(defconst redact--pem-end-regexp
  "-----END \\(?:[A-Z0-9 ]+\\)PRIVATE KEY-----"
  "PEM 私钥块结束行。")

;;; 匹配器

(defun redact--search (regexp limit)
  "大小写不敏感地搜索 REGEXP，不越过 LIMIT。"
  (let ((case-fold-search t))
    (re-search-forward regexp limit t)))

(defun redact--value-ignored-p (value)
  "VALUE 是否应当跳过（太短、纯占位符、或命中黑名单）。
注意：内部会做正则匹配，必须 `save-match-data'，
否则会破坏 font-lock matcher 的匹配位置。"
  (save-match-data
    (let ((v (string-trim value)))
      (or (< (length v) redact-min-length)
          (string-match-p "\\`[xX*._-]+\\'" v)
          (member (downcase v) redact-ignored-values)))))

(defun redact--word-boundary-p (beg end)
  "BEG/END 两侧是否都不是单词字符。
用于避免把长数字串或长标识符的一部分当成手机号 / token。"
  (and (or (<= beg (point-min))
           (not (eq ?w (char-syntax (char-before beg)))))
       (or (>= end (point-max))
           (not (eq ?w (char-syntax (char-after end)))))))

(defun redact--value-call-p (group)
  "GROUP 匹配到的值像是函数调用时返回 t。
`jwt = request.getHeader(...)' 这类赋值右边是代码而不是字面密钥，不该遮。
带引号的值（`password = \"ab(cd\"'）不按调用处理。"
  (let ((beg (match-beginning group)))
    (and (not (memq (char-before beg) '(?\" ?')))
         (string-match-p "(" (match-string-no-properties group)))))

(defun redact--match-credential (limit)
  (catch 'found
    (while (redact--search redact--credential-regexp limit)
      (unless (or (redact--value-ignored-p (match-string-no-properties 1))
                  (redact--value-call-p 1))
        (throw 'found t)))
    nil))

(defun redact--match-connection (limit)
  (catch 'found
    (while (redact--search redact--connection-regexp limit)
      (unless (redact--value-ignored-p (match-string-no-properties 1))
        (throw 'found t)))
    nil))

(defun redact--match-placeholder (limit)
  (catch 'found
    (while (redact--search redact--placeholder-regexp limit)
      (unless (redact--value-ignored-p (match-string-no-properties 2))
        (throw 'found t)))
    nil))

(defun redact--match-bearer (limit)
  (catch 'found
    (while (redact--search redact--bearer-regexp limit)
      (unless (redact--value-ignored-p (match-string-no-properties 1))
        (throw 'found t)))
    nil))

(defun redact--match-token (limit)
  (catch 'found
    (while (redact--search redact--token-regexp limit)
      (unless (redact--value-ignored-p (match-string-no-properties 0))
        (when (redact--word-boundary-p (match-beginning 0) (match-end 0))
          (throw 'found t))))
    nil))

(defun redact--match-phone (limit)
  (catch 'found
    (while (redact--search redact--phone-regexp limit)
      (when (redact--word-boundary-p (match-beginning 0) (match-end 0))
        (throw 'found t)))
    nil))

(defun redact--hostname-char-p (c)
  "C 是否可能属于主机名/标识符（ASCII 字母、数字、点、横线、下划线）。"
  (and c
       (or (and (>= c ?0) (<= c ?9))
           (and (>= c ?a) (<= c ?z))
           (and (>= c ?A) (<= c ?Z))
           (memq c '(?. ?- ?_)))))

(defun redact--match-domain (limit)
  (catch 'found
    (while (redact--search redact--domain-regexp limit)
      (let* ((beg (match-beginning 0))
             (end (match-end 0))
             (text (match-string-no-properties 0))
             ;; `split-string' 内部会用 match data，必须包起来，
             ;; 否则 font-lock 拿到的匹配位置会被改掉。
             (first (downcase (save-match-data
                                (car (split-string text "\\."))))))
        (unless (or
                 ;; Java 包名等反向域名：com.genersoft.iot.vmp / io.quarkus.dev
                 (member first redact--domain-ignore-first-labels)
                 ;; 前面还连着标识符或另一段域名
                 (redact--hostname-char-p (char-before beg))
                 ;; 后面还连着标识符，或者是更长的点分串（file.live.flv）
                 (redact--hostname-char-p (char-after end))
                 (and (eq ?. (char-after end))
                      (redact--hostname-char-p (char-after (1+ end))))
                 ;; 方法调用：logger.info(...)、log.info(...)。
                 ;; `info' 同时也是 TLD，后面紧跟括号就按代码处理。
                 (eq ?\( (char-after end)))
          (throw 'found t))))
    nil))

(defun redact--match-word (limit)
  "匹配 `redact-words' 中配置的敏感词。"
  (when-let* ((regexp (redact--words-regexp)))
    (catch 'found
      (while (redact--search regexp limit)
        (throw 'found t))
      nil)))

;;; 打码

(defun redact--apply-mask (beg end)
  "把 BEG..END 显示为 `redact-mask'。
文本属性变化也会把 buffer 标记为已修改，这里用
`with-silent-modifications' 保持原来的 modified 状态。"
  (with-silent-modifications
    (add-text-properties
     beg end
     (list 'face 'redact-mask-face
           'display redact-mask
           'help-echo "已遮挡"
           'redact t))))

(defun redact--fontify-window (window)
  "同步 fontify WINDOW 中 buffer 的可见区域，立即完成遮挡。
`font-lock-ensure' 是同步的，不会像 jit-lock 那样留到下一次 redisplay。"
  (with-current-buffer (window-buffer window)
    (when (and font-lock-mode redact-mode)
      (let ((beg (window-start window))
            (end (window-end window t)))
        (when (and beg end (< beg end))
          (font-lock-ensure beg end))))))

(defun redact--ensure-fontified ()
  "同步 fontify 当前 buffer，避免进入 buffer 时先露出明文。
小 buffer 整块处理；超过 `redact-eager-fontify-max-size' 时只处理可见窗口。"
  (when font-lock-mode
    (if (<= (buffer-size) redact-eager-fontify-max-size)
        (font-lock-ensure (point-min) (point-max))
      (dolist (window (get-buffer-window-list (current-buffer) nil t))
        (redact--fontify-window window)))))

(defconst redact--font-lock-keywords
  `((redact--match-credential
     (1 (progn (redact--apply-mask (match-beginning 1) (match-end 1)) nil)))
    (redact--match-connection
     (1 (progn (redact--apply-mask (match-beginning 1) (match-end 1)) nil)))
    (redact--match-placeholder
     (2 (progn (redact--apply-mask (match-beginning 2) (match-end 2)) nil)))
    (redact--match-bearer
     (1 (progn (redact--apply-mask (match-beginning 1) (match-end 1)) nil)))
    (redact--match-token
     (0 (progn (redact--apply-mask (match-beginning 0) (match-end 0)) nil)))
    (redact--match-domain
     (0 (progn (redact--apply-mask (match-beginning 0) (match-end 0)) nil)))
    (redact--match-phone
     (0 (progn (redact--apply-mask (match-beginning 0) (match-end 0)) nil)))
    (redact--match-word
     (0 (progn (redact--apply-mask (match-beginning 0) (match-end 0)) nil))))
  "font-lock 规则。命中后加 `display' 属性，不依赖 face 关键字。")

;;; PEM 私钥块（跨行，font-lock 处理不了）

(defvar-local redact--overlays nil
  "本 buffer 里由 PEM 规则创建的 overlay。")

(defun redact--clear-overlays ()
  (mapc #'delete-overlay redact--overlays)
  (setq redact--overlays nil))

(defun redact--add-overlay (beg end)
  (let ((ov (make-overlay beg end)))
    (overlay-put ov 'redact-pem t)
    (overlay-put ov 'display redact-mask)
    (overlay-put ov 'face 'redact-mask-face)
    (overlay-put ov 'help-echo "已遮挡")
    (overlay-put ov 'evaporate t)
    (push ov redact--overlays)))

(defun redact--mask-pem-lines (beg end)
  "逐行遮挡 BEG..END，保留行数，避免整块塌陷。"
  (save-excursion
    (goto-char beg)
    (while (< (point) end)
      (let ((line-beg (line-beginning-position))
            (line-end (line-end-position)))
        (when (< line-beg line-end)
          (redact--add-overlay line-beg line-end)))
      (forward-line 1))))

(defun redact--refresh-pem ()
  "重扫整个 buffer 的 PEM 私钥块。"
  (save-excursion
    (save-restriction
      (widen)
      (dolist (ov redact--overlays)
        (when (overlay-get ov 'redact-pem)
          (delete-overlay ov)))
      (setq redact--overlays
            (seq-filter (lambda (ov) (not (overlay-get ov 'redact-pem)))
                        redact--overlays))
      (goto-char (point-min))
      (while (re-search-forward redact--pem-begin-regexp nil t)
        (let ((beg (match-beginning 0)))
          (when (re-search-forward redact--pem-end-regexp nil t)
            (redact--mask-pem-lines beg (match-end 0))))))))

(defun redact--pem-near-p (beg end)
  "BEG..END 是否与已有的 PEM overlay 相交。"
  (seq-some (lambda (ov)
              (let ((start (overlay-start ov)))
                (and (overlay-get ov 'redact-pem)
                     start
                     (<= start end)
                     (>= (overlay-end ov) beg))))
            redact--overlays))

(defun redact--pem-after-change (beg end _old-len)
  "只在可能涉及 PEM 时重扫，避免每次输入都遍历整个 buffer。"
  (when (or (redact--pem-near-p beg end)
            (save-excursion
              (goto-char (max (point-min) (- beg 12)))
              (search-forward "-----BEGIN" (min (point-max) (+ end 12)) t)))
    (redact--refresh-pem)))

;;; 清除

(defun redact--strip-masks (beg end)
  "移除 BEG..END 内由本模块添加的显示属性。
同样不能因此把 buffer 标记为已修改。"
  (with-silent-modifications
    (save-excursion
      (goto-char beg)
      (while (< (point) end)
        (let ((next (next-single-property-change (point) 'redact nil end)))
          (when (get-text-property (point) 'redact)
            (remove-text-properties
             (point) next
             '(display nil help-echo nil face nil redact nil)))
          (goto-char next))))))

;;; minor mode

(defvar-local redact--saved-managed-props nil
  "开启前 buffer 的 `font-lock-extra-managed-props'，关闭时恢复。")

(defvar-local redact--enabled nil
  "本 buffer 是否已经完成启用流程，避免重复添加 font-lock 规则。")

(defun redact--enable ()
  ;; 注意：`define-minor-mode' 会先设置 `redact-mode' 再执行 body，
  ;; 所以这里不能用 `(unless redact-mode ...)' 判断；用独立标志保证幂等。
  (unless redact--enabled
    ;; font-lock 自己会保护 modified 状态，但启动/重排是同步执行的，
    ;; 这里再包一层，确保任何路径都不会把 clean 的 buffer 变成 modified。
    (with-silent-modifications
      (setq redact--enabled t)
      (setq redact--saved-managed-props font-lock-extra-managed-props)
      (setq-local font-lock-extra-managed-props
                  (delete-dups
                   (append '(display help-echo redact)
                           (ensure-list font-lock-extra-managed-props))))
      ;; 先移除再添加，避免 major mode 切换后重复启用时累积同一批规则。
      (font-lock-remove-keywords nil redact--font-lock-keywords)
      (font-lock-add-keywords nil redact--font-lock-keywords 'append)
      (unless font-lock-mode
        (font-lock-mode 1))
      (font-lock-flush)
      (add-hook 'after-change-functions #'redact--pem-after-change nil t)
      (redact--refresh-pem)
      ;; 关键：不等 redisplay 的 jit-lock，启用时同步 fontify。
      ;; 否则 buffer 第一次显示时可能先画出明文，下一帧才变成星号。
      (redact--ensure-fontified))))

(defun redact--disable ()
  (when redact--enabled
    (with-silent-modifications
      (setq redact--enabled nil)
      (font-lock-remove-keywords nil redact--font-lock-keywords)
      (setq-local font-lock-extra-managed-props redact--saved-managed-props)
      (remove-hook 'after-change-functions #'redact--pem-after-change t)
      (redact--clear-overlays)
      (redact--strip-masks (point-min) (point-max))
      (when font-lock-mode
        (font-lock-flush)))))

(defface redact-modeline-face
  '((t :family "Symbols Nerd Font Mono" :height 1.0))
  "模型栏锁图标字形（Nerd Font，非 emoji）。"
  :group 'redact)

;;;###autoload
(define-minor-mode redact-mode
  "在当前 buffer 中遮挡密码、密钥和手机号。"
  :lighter (propertize " \uF023" 'face 'redact-modeline-face)
  :group 'redact
  (if redact-mode
      (redact--enable)
    (redact--disable)))

(defun redact--turn-on ()
  "全局模式的 per-buffer 启用函数。"
  (unless (or (minibufferp)
              ;; vterm 自己维护缓冲区渲染，暂不接入 font-lock
              (eq major-mode 'vterm-mode))
    (redact-mode 1)))

;;;###autoload
(define-globalized-minor-mode global-redact-mode
  redact-mode redact--turn-on
  :group 'redact)

(defun redact--ensure-buffer-enabled ()
  "全局模式开启而当前 buffer 漏了 `redact-mode' 时静默补上。
绑定 `redact-mode--suppress-set-explicitly'，免得把补启用当成用户显式开启，
导致重新打开全局模式后该 buffer 不再被自动启用。"
  (when (and global-redact-mode
             (not redact-mode)
             (not (minibufferp))
             (not (eq major-mode 'vterm-mode)))
    (let ((redact-mode--suppress-set-explicitly t))
      (redact-mode 1))))

(defun redact--window-buffer-changed (frame)
  "窗口切换 buffer 时，在画面绘制前完成遮挡。
这个钩子在 redisplay 中、窗口内容绘制前运行，所以这里同步 fontify
能避免第一帧露出明文；同时兜住被 major mode / 文件局部变量清掉的启用状态。"
  (when global-redact-mode
    (dolist (window (window-list frame 'no-minibuffer))
      (with-current-buffer (window-buffer window)
        (redact--ensure-buffer-enabled)
        (when redact-mode
          (redact--fontify-window window))))))

;;; 词表维护

(defun redact-add-word (word)
  "把 WORD 加入 `redact-words' 并立即刷新。
有 region 时用 region 内容，否则提示输入。"
  (interactive
   (list (string-trim
          (if (use-region-p)
              (buffer-substring-no-properties (region-beginning) (region-end))
            (read-string "要遮挡的词: ")))))
  (when (string-empty-p word)
    (user-error "词不能为空"))
  (if (member word redact-words)
      (message "已在词表中：%s" word)
    (customize-set-variable 'redact-words (cons word redact-words))
    (message "已加入词表：%s" word)))

(defun redact-remove-word (word)
  "从 `redact-words' 移除 WORD 并立即刷新。"
  (interactive
   (list (completing-read "移除词: " redact-words nil t)))
  (customize-set-variable 'redact-words (remove word redact-words))
  (message "已移除：%s" word))

(defun redact-refresh ()
  "清掉词表缓存并刷新所有启用 `redact-mode' 的 buffer。
用 `setq' 改过 `redact-words' 后调用。"
  (interactive)
  (setq redact--words-cache nil)
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (bound-and-true-p redact-mode)
        (font-lock-flush))))
  (message "redact 规则已刷新"))

;;; 启动后初始化
;;
;; Doom 的 leader keymap 在 `doom-after-init-hook' 里的
;; `doom-init-leader-keys-h' 中重建；模块 config.el 加载时用 `map!'
;; 绑的键会被它覆盖。所以这里 append 到 hook 末尾，等它建完再绑。

(defvar redact--modeline-lock-cache nil
  "缓存模型栏锁图标，避免每次 redisplay 重新构造字符串。")

(defun redact--modeline-lock ()
  "模型栏锁图标：用 Symbols Nerd Font Mono 的字形，不用 emoji。"
  (if (fboundp 'nerd-icons-faicon)
      (or redact--modeline-lock-cache
          (setq redact--modeline-lock-cache
                (nerd-icons-faicon "nf-fa-lock" :face 'nerd-icons-red)))
    ;; nerd-icons 还没加载时也有正确字形，只是不带颜色。
    (propertize "\uF023" 'face '(:family "Symbols Nerd Font Mono" :height 1.0))))

(defun redact--late-init ()
  "在 Doom 完成 leader key 初始化后启用全局遮挡并绑定快捷键。"
  (global-redact-mode 1)
  ;; Doom modeline 默认不显示 minor modes（`doom-modeline-minor-modes' 为 nil），
  ;; 所以 `redact-mode' 的 lighter 不会出现。改挂到 `misc-info' 段，
  ;; 只在当前 buffer 启用时显示锁图标（Nerd Font 字形，非 emoji）。
  (setq mode-line-misc-info
        (assq-delete-all 'redact-mode mode-line-misc-info))
  (add-to-list 'mode-line-misc-info
               '(redact-mode (" " (:eval (redact--modeline-lock)))))
  ;; 显示前的最后一道保险：窗口切换到新 buffer 时先同步 fontify。
  (add-hook 'window-buffer-change-functions #'redact--window-buffer-changed)
  (when (fboundp 'map!)
    (map! :leader :desc "Toggle secret masking" "t k" #'global-redact-mode)))

(if after-init-time
    (redact--late-init)
  (add-hook 'doom-after-init-hook #'redact--late-init t))

;; 兜底：部分 mode（org + org-modern-indent / org-appear 等）会在
;; `org-mode-hook' 里重置 buffer-local 变量，把已经启用的 `redact-mode'
;; 清掉，而 `after-change-major-mode-hook' 只会补一次。这里每次命令后
;; 检查当前可见 buffer，漏了就补上。
(defun redact--ensure-current-buffer ()
  (when (and (get-buffer-window (current-buffer))
             (not redact-mode))
    (redact--ensure-buffer-enabled)))

(add-hook 'post-command-hook #'redact--ensure-current-buffer)

(provide 'neoemacs-redact)
;;; config.el ends here
