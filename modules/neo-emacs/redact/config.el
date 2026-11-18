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
(require 'json)

;; `redact--fontify-window' 在 `define-minor-mode' 之前定义，先声明变量，
;; 避免字节编译时把它当成自由变量。
(defvar redact-mode)

(defgroup redact nil
  "在屏幕上遮挡敏感信息。"
  :group 'editing
  :prefix "redact-")

(defcustom redact-mask "******"
  "遮挡用的替换字符串。
固定长度，避免从星号个数反推原文长度。
例外：Org 表格行内的遮挡都按原文的显示宽度生成等宽星号，保持竖线对齐，
见 `redact--mask-string'。"
  :type 'string
  :group 'redact
  :set (lambda (sym val)
         (set-default sym val)
         (dolist (buf (buffer-list))
           (with-current-buffer buf
             (when (bound-and-true-p redact-mode)
               (font-lock-flush)
               ;; overlay 里存的是旧的遮挡串，得重建。
               (when (fboundp 'redact--gitleaks-start)
                 (redact--gitleaks-start 'force))
               (when (fboundp 'redact--table-refresh)
                 (redact--table-refresh)))))))

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

(defun redact--refresh-buffers ()
  "对已启用遮挡的 buffer 立即清掉旧遮挡并重绘。
`setopt' 改变遮挡范围后调用，避免旧属性留在屏幕上。"
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (bound-and-true-p redact-mode)
        (when (fboundp 'redact--strip-masks)
          (redact--strip-masks (point-min) (point-max)))
        (font-lock-flush)))))

(defcustom redact-mask-ip-addresses t
  "是否遮挡 IPv4 地址。
四段点分数字都会按 IP 处理，包括 `1.2.3.4' 这种版本号写法；
每段必须在 0-255 之间，且前后不能紧邻字母、数字、点或横线。
IPv6 不在处理范围内。"
  :type 'boolean
  :group 'redact
  :set (lambda (sym val)
         (set-default sym val)
         (redact--refresh-buffers)))

(defcustom redact-mask-snowflake-ids t
  "是否遮挡雪花算法 ID（18-19 位连续十进制数字）。
位数范围写死；19 位的银联卡号也会被遮，需要区分时把本项设为 nil。
前后紧邻字母、数字、下划线或点时跳过。"
  :type 'boolean
  :group 'redact
  :set (lambda (sym val)
         (set-default sym val)
         (redact--refresh-buffers)))

(defcustom redact-mask-uuids t
  "是否遮挡标准 UUID（8-4-4-4-12 十六进制）。
`urn:uuid:' 前缀、花括号和引号保留，只遮 UUID 本体。
无破折号的 32 位十六进制串（MD5）不算，避免误伤哈希值。"
  :type 'boolean
  :group 'redact
  :set (lambda (sym val)
         (set-default sym val)
         (redact--refresh-buffers)))

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
   ;; 但单独的 key 太短，必须加词边界，否则 monkey = ... 也会命中。
   "\\(?:password\\|passwd\\|pwd\\|passphrase"
   "\\|client[_-]?secret\\|secret[_-]?key\\|app[_-]?secret"
   "\\|api[_-]?key\\|apikey"
   "\\|\\<key\\>"
   "\\|access[_-]?key\\(?:[_-]?id\\)?"
   "\\|private[_-]?key"
   "\\|secret"
   "\\|jwt"
   "\\|auth[_-]?token\\|access[_-]?token\\|refresh[_-]?token"
   "\\|token"
   ;; 中文键名：密码、口令、密钥/秘钥、私钥、令牌、凭证/凭据、账密
   "\\|密码\\|口令\\|密钥\\|秘钥\\|私钥\\|令牌\\|凭证\\|凭据\\|账密\\)"
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

(defconst redact--ipv4-regexp
  "\\(?:[0-9]\\{1,3\\}\\.\\)\\{3\\}[0-9]\\{1,3\\}"
  "IPv4 地址的粗匹配；每段范围在 `redact--valid-ipv4-p' 里校验。")

(defconst redact--uuid-regexp
  (concat "\\(?:[0-9A-Fa-f]\\{8\\}-[0-9A-Fa-f]\\{4\\}-"
          "[0-9A-Fa-f]\\{4\\}-[0-9A-Fa-f]\\{4\\}-"
          "[0-9A-Fa-f]\\{12\\}\\)")
  "标准 UUID 的 8-4-4-4-12 形式；前后边界在 `redact--match-uuid' 里检查。")

(defconst redact--snowflake-regexp
  "[0-9]\\{18,19\\}"
  "雪花算法 ID 的粗匹配（18-19 位十进制）；前后边界在 `redact--match-snowflake' 里检查。")

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

(defun redact--valid-ipv4-p (text)
  "TEXT 是否每段都在 0-255 之间。
`split-string' 和 `string-match-p' 都会动 match data，必须包起来。"
  (save-match-data
    (seq-every-p (lambda (part)
                   (and (string-match-p "\\`[0-9]+\\'" part)
                        (<= (string-to-number part) 255)))
                 (split-string text "\\."))))

(defun redact--match-ip (limit)
  "匹配 IPv4 地址。
前后紧邻字母、数字、点和横线时跳过：`1.2.3.4.5' 是更长的点分串，
`v1.2.3.4' 是版本号，都不当 IP 遮。"
  (when redact-mask-ip-addresses
    (catch 'found
      (while (redact--search redact--ipv4-regexp limit)
        (let ((beg (match-beginning 0))
              (end (match-end 0))
              (text (match-string-no-properties 0)))
          (unless (or (redact--hostname-char-p (char-before beg))
                      (redact--hostname-char-p (char-after end))
                      (not (redact--valid-ipv4-p text)))
            (throw 'found t))))
      nil)))

(defun redact--hex-char-p (c)
  "C 是否是十六进制数字字符。"
  (and c
       (or (and (>= c ?0) (<= c ?9))
           (and (>= c ?a) (<= c ?f))
           (and (>= c ?A) (<= c ?F)))))

(defun redact--match-uuid (limit)
  "匹配标准 UUID。
前后紧邻十六进制字符时跳过：那样是更长的哈希字符串，
单独遮一段并不能把它遮干净。`urn:uuid:' 、花括号、引号和横线
都不算边界字符，所以 UUID 本体照样遮挡。"
  (when redact-mask-uuids
    (catch 'found
      (while (redact--search redact--uuid-regexp limit)
        (let ((beg (match-beginning 0))
              (end (match-end 0)))
          (unless (or (redact--hex-char-p (char-before beg))
                      (redact--hex-char-p (char-after end)))
            (throw 'found t))))
      nil)))

(defun redact--snowflake-char-p (c)
  "C 是否可能属于更长的数字串或标识符。"
  (and c
       (or (and (>= c ?0) (<= c ?9))
           (and (>= c ?a) (<= c ?z))
           (and (>= c ?A) (<= c ?Z))
           (memq c '(?_ ?.)))))

(defun redact--match-snowflake (limit)
  "匹配雪花算法 ID（18-19 位连续十进制数字）。
前后紧邻字母、数字、下划线或点时跳过：`12345678901234567890' 是 20 位数，
`v123456789012345678' 是标识符，都不当雪花 ID 遮。"
  (when redact-mask-snowflake-ids
    (catch 'found
      (while (redact--search redact--snowflake-regexp limit)
        (let ((beg (match-beginning 0))
              (end (match-end 0)))
          (unless (or (redact--snowflake-char-p (char-before beg))
                      (redact--snowflake-char-p (char-after end)))
            (throw 'found t))))
      nil)))

(defun redact--match-word (limit)
  "匹配 `redact-words' 中配置的敏感词。"
  (when-let* ((regexp (redact--words-regexp)))
    (catch 'found
      (while (redact--search regexp limit)
        (throw 'found t))
      nil)))

;;; 打码

(defun redact--table-line-p (pos)
  "POS 所在行是否是 Org 表格行。"
  (and (derived-mode-p 'org-mode)
       (save-excursion
         (goto-char pos)
         (beginning-of-line)
         (looking-at-p "[ \t]*|"))))

(defun redact--mask-string (beg end)
  "返回 BEG..END 的遮挡串。
Org 表格行里按原文的显示宽度生成星号（中文算 2 列），否则用
`redact-mask'。表格行里的遮挡必须等宽，不然整张表的竖线会错位。"
  (if (redact--table-line-p beg)
      (make-string (max 1 (string-width
                           (buffer-substring-no-properties beg end)))
                   ?*)
    redact-mask))

(defun redact--overlay-mask-p (ov)
  "OV 是否属于本模块的遮挡 overlay。"
  (or (overlay-get ov 'redact-table)
      (overlay-get ov 'redact-pem)
      (overlay-get ov 'redact-gitleaks)))

(defun redact--masked-overlay (beg end)
  "返回完全覆盖 BEG..END 的遮挡 overlay，没有则返回 nil。
表格单元格、PEM 块和 gitleaks 都是 overlay，它们的 `display' 优先于
文本属性，整段只有一个值，所以里面再叠文本属性没有意义。"
  (seq-find (lambda (ov)
              (and (redact--overlay-mask-p ov)
                   (<= (overlay-start ov) beg)
                   (>= (overlay-end ov) end)))
            (overlays-in beg end)))

(defun redact--overlapping-mask-overlay (beg end)
  "返回与 BEG..END 有交集的遮挡 overlay，没有则返回 nil。
文本属性和 overlay 混用时，两段 `display' 只能相邻、不能相交：
相交时文本属性的这一段会被 overlay 边界劈成两块，每块都再渲染一次
整串星号，行宽就翻倍了。所以有交集时干脆不加文本属性。"
  (seq-find #'redact--overlay-mask-p
            (append (overlays-in (max (point-min) (1- beg))
                                 (min (point-max) (1+ end)))
                    (overlays-at beg))))

(defun redact--text-run-bounds (beg end)
  "把 BEG..END 扩大到与它相连、已带 `redact' 属性的连续区间。
返回 (BEG . END)。

这一步是必须的：`display' 属性按「值相同的连续区间」渲染，一段
遮挡如果被另一段宽度不同的遮挡截成几段，首尾两段会各自再渲染一遍
整串星号，行宽直接翻倍。典型例子是域名 `a.minexiot.com' 已经被
整段遮成 15 个星号，词表又单独遮了 `minexiot'，结果渲染成
15 + 8 + 15 个星号。这里改成先取并集、整段重算，保证一段遮挡
只有一个 `display' 值。"
  (let ((start beg)
        (stop end))
    (when (and (> start (point-min))
               (get-text-property (1- start) 'redact))
      (setq start (previous-single-property-change start 'redact nil (point-min))))
    (when (and (< stop (point-max))
               (get-text-property stop 'redact))
      (setq stop (next-single-property-change stop 'redact nil (point-max))))
    (cons start stop)))

(defun redact--union-bounds (beg end)
  "把 BEG..END 扩大到与它相连或重叠的所有已有遮挡，返回 (BEG . END)。
文本属性遮挡和遮挡 overlay 都算。用于 overlay 类遮挡（gitleaks）
避免把外层的整段遮挡切成几段。"
  (let* ((text (redact--text-run-bounds beg end))
         (start (car text))
         (stop (cdr text)))
    (dolist (ov (overlays-in (max (point-min) (1- start))
                             (min (point-max) (1+ stop))))
      (when (redact--overlay-mask-p ov)
        (setq start (min start (overlay-start ov)))
        (setq stop (max stop (overlay-end ov)))))
    (cons start stop)))

(defun redact--apply-mask (beg end)
  "把 BEG..END 遮挡起来，串长由 `redact--mask-string' 决定。
与已有文本属性遮挡重叠时先取并集再整段遮，避免 `display' 被截断后
重复渲染。文本属性变化也会把 buffer 标记为已修改，这里用
`with-silent-modifications' 保持原来的 modified 状态。"
  (unless (redact--overlapping-mask-overlay beg end)
    (with-silent-modifications
      (let* ((bounds (redact--text-run-bounds beg end))
             (start (car bounds))
             (stop (cdr bounds)))
        (add-text-properties
         start stop
         (list 'face 'redact-mask-face
               'display (redact--mask-string start stop)
               'help-echo "已遮挡"
               'redact t))))))

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
    (redact--match-ip
     (0 (progn (redact--apply-mask (match-beginning 0) (match-end 0)) nil)))
    (redact--match-snowflake
     (0 (progn (redact--apply-mask (match-beginning 0) (match-end 0)) nil)))
    (redact--match-uuid
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
  (setq redact--overlays nil)
  ;; `kill-all-local-variables'（切换主模式时会调用）会清空列表，
  ;; 但 overlay 仍留在 buffer 里，这里按属性扫一遍兜底。
  (remove-overlays (point-min) (point-max) 'redact-pem t))

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

;;; Org 表格列（表头驱动的遮挡）
;;
;; 笔记里常见的写法是
;;   | 系统 | 环境 | 地址 | 账密 | 备注 |
;; 密码直接躺在某一列里，前面没有 `password:' 这样的键名，
;; 内置正则和 gitleaks 都认不出来。这里按表头列名决定遮哪一列。

(defcustom redact-table-columns
  '("账密" "账号密码" "用户名密码" "密码" "口令" "密钥" "秘钥" "私钥"
    "凭据" "凭证"
    "password" "passwd" "pwd" "passphrase" "secret" "token" "key")
  "Org 表格里需要遮挡的列名。
表头单元格命中其中任一项时，整列数据行逐格遮挡；表头本身不遮。
比较时忽略大小写、空白和 Org 强调标记，并去掉括号里的补充说明。
英文列名按全等比较，中文列名按子串比较（`密码' 命中 `登录密码'）。"
  :type '(repeat string)
  :group 'redact)

(defcustom redact-table-idle-delay 0.3
  "编辑后多久重新扫描 Org 表格（秒）。
nil 表示只在打开 buffer 时扫一次。"
  :type '(choice (const :tag "不重新扫描" nil) number)
  :group 'redact)

(defvar-local redact--table-overlays nil
  "本 buffer 里由表格列规则创建的 overlay。")

(defvar-local redact--table-timer nil
  "表格重扫的 idle timer。")

(defun redact--table-cells (line-start)
  "返回 LINE-START 开头那行的单元格边界列表，顺序与列一致。
每个元素是 (BEG . END)，可能包含两侧空格，由调用方决定是否 trim。"
  (save-excursion
    (goto-char line-start)
    (skip-chars-forward " \t")
    (when (eq (char-after) ?|)
      (let ((limit (line-end-position)) cells)
        (forward-char 1)
        (while (< (point) limit)
          (let ((beg (point)))
            (if (search-forward "|" limit t)
                (push (cons beg (1- (point))) cells)
              (push (cons beg limit) cells)
              (goto-char limit))))
        (nreverse cells)))))

(defun redact--table-cell-name (cell)
  "把 CELL 的内容变成可比较的列名。
去掉 Org 强调标记、空白，以及括号里的补充说明，
比如 `账密（账号/密码）' 变成 `账密'。"
  (let ((text (buffer-substring-no-properties (car cell) (cdr cell))))
    (replace-regexp-in-string
     "[[:space:]]+" ""
     (replace-regexp-in-string
      "[*_=/~]" ""
      (replace-regexp-in-string "[（(][^）)]*[）)]" "" text)))))

(defun redact--table-target-p (name)
  "列名 NAME 是否在 `redact-table-columns' 里。
中文列名按子串比较，这样 `登录密码' 也能被 `密码' 命中；
英文列名按全等比较，避免 `key' 误伤 `keyword' 这种列。"
  (let ((n (downcase name)))
    (seq-some (lambda (col)
                (let ((c (downcase
                          (replace-regexp-in-string
                           "[[:space:]]+" "" (string-trim col)))))
                  (or (string= n c)
                      (and (string-match-p "[^[:ascii:]]" c)
                           (string-match-p (regexp-quote c) n)))))
              redact-table-columns)))

(defun redact--table-target-columns (header-start)
  "返回表头行 HEADER-START 里命中 `redact-table-columns' 的列下标。"
  (let ((index 0) cols)
    (dolist (cell (redact--table-cells header-start))
      (when (redact--table-target-p (redact--table-cell-name cell))
        (push index cols))
      (setq index (1+ index)))
    (nreverse cols)))

(defun redact--table-separator-p (cells)
  "CELLS 是否属于 `|---+---|' 这样的分隔行。"
  (and cells
       (seq-every-p
        (lambda (cell)
          (let ((text (string-trim
                       (buffer-substring-no-properties (car cell) (cdr cell)))))
            (or (string-empty-p text)
                (string-match-p "\\`[-+:]+\\'" text))))
        cells)))

(defconst redact--table-secret-cell-regexp
  "\\`\\([[:alpha:]][[:alnum:]._-]*\\)/\\([[:alnum:]!@#$%^&*?=_+.-]\\{8,\\}\\)\\'"
  "表格单元格里 `用户名/密码' 形态的粗匹配，group 2 是密码。")

(defun redact--table-secret-cell-p (text)
  "TEXT 是否像 `用户名/密码'。
密码要求至少 8 位，并且同时含字母和数字，或含明显的特殊符号。
这样 `docs/getting-started'、`nginx/1.25.3'、`application/json'
这类路径和版本号不会被当成账密。"
  (save-match-data
    (when (string-match redact--table-secret-cell-regexp text)
      (let ((pwd (match-string 2 text)))
        (or (and (string-match-p "[[:alpha:]]" pwd)
                 (string-match-p "[0-9]" pwd))
            (string-match-p "[!@#$%^&*?]" pwd))))))

(defun redact--table-infer-columns (start)
  "扫描 START 开始的表格，返回内容像账密的列下标。
只用于没有表头的表格：一列至少两个非空单元格，且全部符合
`用户名/密码' 形态才认，避免把地址、路径列误判成密码列。"
  (save-excursion
    (goto-char start)
    (let (rows)
      (while (looking-at-p "^[ \t]*|")
        (let ((cells (redact--table-cells (line-beginning-position))))
          (unless (redact--table-separator-p cells)
            (push cells rows)))
        (forward-line 1))
      (let ((rows (nreverse rows)))
        (when (>= (length rows) 2)
          (let* ((ncols (apply #'max (mapcar #'length rows)))
                 cols)
            (dotimes (i ncols)
              (let ((vals (delq nil
                                (mapcar (lambda (cells)
                                          (when-let* ((cell (nth i cells)))
                                            (let ((text (string-trim
                                                         (buffer-substring-no-properties
                                                          (car cell) (cdr cell)))))
                                              (unless (string-empty-p text) text))))
                                        rows))))
                (when (and (>= (length vals) 2)
                           (seq-every-p #'redact--table-secret-cell-p vals))
                  (push i cols))))
            (nreverse cols)))))))

(defun redact--table-add-overlay (beg end)
  "把表格单元格 BEG..END 遮起来。
遮挡串按单元格的显示宽度生成（中文算 2 列），保证 Org 表格的竖线仍然对齐。"
  (let ((ov (make-overlay beg end)))
    (overlay-put ov 'redact-table t)
    (overlay-put ov 'display (redact--mask-string beg end))
    (overlay-put ov 'face 'redact-mask-face)
    (overlay-put ov 'help-echo "已遮挡（表格列）")
    (overlay-put ov 'evaporate t)
    (push ov redact--table-overlays)))

(defun redact--table-mask-cell (cell &optional predicate)
  "遮挡 CELL 的内容，保留两侧用来对齐的空格。
空单元格和分隔标记跳过，避免把表格结构遮掉。
PREDICATE 非 nil 时只遮内容满足它的单元格。"
  (let ((beg (car cell))
        (end (cdr cell)))
    (save-excursion
      (goto-char beg)
      (skip-chars-forward " \t" end)
      (let ((start (point)))
        (goto-char end)
        (skip-chars-backward " \t" start)
        (when (< start (point))
          (let ((text (buffer-substring-no-properties start (point))))
            (unless (or (string-match-p "\\`[-+:]+\\'" text)
                        (and predicate (not (funcall predicate text))))
              (redact--table-add-overlay start (point)))))))))

(defun redact--table-mask-rows (start cols header-p)
  "从 START 开始逐行遮 COLS 列。
HEADER-P 为 t 时跳过第一行（表头），整列遮；否则第一行也是数据，
只遮内容符合 `用户名/密码' 形态的单元格。"
  (save-excursion
    (goto-char start)
    (when header-p
      (forward-line 1))
    (while (looking-at-p "^[ \t]*|")
      (let ((cells (redact--table-cells (line-beginning-position))))
        (unless (redact--table-separator-p cells)
          (dolist (col cols)
            (when-let* ((cell (nth col cells)))
              (redact--table-mask-cell
               cell (unless header-p #'redact--table-secret-cell-p))))))
      (forward-line 1))))

(defun redact--table-mask-block (header-start)
  "处理 HEADER-START 开始的整张表。
表头命中 `redact-table-columns' 时遮对应列（跳过表头）；
表头不命中时按列内容形态推断账密列，逐格只遮像 `用户名/密码' 的单元格。"
  (let ((cols (redact--table-target-columns header-start)))
    (if cols
        (redact--table-mask-rows header-start cols t)
      (when-let* ((inferred (redact--table-infer-columns header-start)))
        (redact--table-mask-rows header-start inferred nil)))))

(defun redact--table-clear ()
  "清掉本 buffer 的表格 overlay。"
  (mapc #'delete-overlay redact--table-overlays)
  (setq redact--table-overlays nil)
  ;; 主模式重载后列表会被清空，这里按属性兜底，避免 overlay 越积越多。
  (remove-overlays (point-min) (point-max) 'redact-table t))

(defun redact--table-refresh ()
  "重新扫描整个 buffer 的 Org 表格。
只处理每张表的第一行，避免同一张表被重复扫描。"
  (redact--table-clear)
  (when (eq major-mode 'org-mode)
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (while (re-search-forward "^[ \t]*|" nil t)
          (let ((line-start (line-beginning-position)))
            (unless (save-excursion
                      (and (= 0 (forward-line -1))
                           (looking-at-p "^[ \t]*|")))
              (redact--table-mask-block line-start))))))))

(defun redact--table-idle-scan (buffer)
  "编辑停下后重扫 BUFFER 的表格。"
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq redact--table-timer nil)
      (when (and redact-mode (eq major-mode 'org-mode))
        (redact--table-refresh)))))

(defun redact--table-schedule ()
  "把表格重扫推迟到输入停下之后。"
  (when (and redact-table-idle-delay (eq major-mode 'org-mode))
    (when (timerp redact--table-timer)
      (cancel-timer redact--table-timer))
    (setq redact--table-timer
          (run-with-idle-timer redact-table-idle-delay nil
                               #'redact--table-idle-scan
                               (current-buffer)))))

(defun redact--table-after-change (beg &rest _)
  "改动落到表格行上时，安排一次表格重扫。
BEG 是改动起点；不在表格行上的编辑（写正文）不必整份重扫。"
  (when (and redact-mode (eq major-mode 'org-mode))
    (when (save-excursion
            (goto-char (max (point-min) (min beg (point-max))))
            (let ((end (line-end-position)))
              (beginning-of-line)
              (re-search-forward "|" end t)))
      (redact--table-schedule))))

(defun redact--table-stop ()
  "停掉表格重扫并清除遮挡。"
  (when (timerp redact--table-timer)
    (cancel-timer redact--table-timer)
    (setq redact--table-timer nil))
  (redact--table-clear))

;;; Gitleaks（第二道规则：按规则库 + 熵识别密钥）
;;
;; 与内置正则互补：
;; - gitleaks 认不出 `db.password = "S3cr3tP@ssw0rd!xyz"'（值里带 @!），
;;   内置 `redact--credential-regexp' 认得出；
;; - 内置正则只认识列出来的几种密钥前缀，其他厂商的 token 靠 gitleaks。
;;
;; gitleaks 是外部进程，只在 buffer 首次启用和编辑停下后异步跑，
;; 不阻塞 UI。结果用 overlay 遮挡，和 font-lock 的文本属性互不干扰。

(defcustom redact-gitleaks-enabled t
  "是否用 gitleaks 识别密钥。
关闭后只用内置正则和 `redact-words'。"
  :type 'boolean
  :group 'redact)

(defcustom redact-gitleaks-executable "gitleaks"
  "gitleaks 可执行文件，命令名或绝对路径。"
  :type 'string
  :group 'redact)

(defcustom redact-gitleaks-config nil
  "自定义 gitleaks 配置（.toml）路径。
nil 表示用 gitleaks 自带规则；想加自己的规则时指向一个 toml 文件。"
  :type '(choice (const :tag "gitleaks 默认规则" nil) file)
  :group 'redact)

(defcustom redact-gitleaks-max-size 2000000
  "超过该字符数的 buffer 不跑 gitleaks，避免大文件卡顿。"
  :type 'integer
  :group 'redact)

(defcustom redact-gitleaks-idle-delay 0.6
  "编辑停下多久后重新跑 gitleaks（秒）。
nil 表示只在打开 buffer 时扫一次，编辑后不再更新。"
  :type '(choice (const :tag "不重新扫描" nil) number)
  :group 'redact)

(defcustom redact-gitleaks-blocking-wait 0.2
  "打开 buffer 时最多同步等 gitleaks 多久（秒）。
gitleaks 是异步的，默认情况下结果回来前屏幕上会先露出它能识别的密钥。
设一个很短的上限，可以让首帧就已经遮好；超时就转后台继续。
nil 表示完全不等（打开速度最快）。"
  :type '(choice (const :tag "完全不等" nil) number)
  :group 'redact)

(defcustom redact-gitleaks-timeout 15
  "单次 gitleaks 进程的超时秒数，超时直接杀掉。"
  :type 'integer
  :group 'redact)

(defcustom redact-gitleaks-extra-args nil
  "追加给 gitleaks 的参数，例如 (\"--enable-rule\" \"generic-api-key\")。"
  :type '(repeat string)
  :group 'redact)

(defcustom redact-gitleaks-ignore-modes
  '(vterm-mode eshell-mode term-mode shell-mode)
  "这些 major mode 不跑 gitleaks。
终端类 buffer 自己维护渲染，且内容是命令输出，扫了也没有意义。"
  :type '(repeat symbol)
  :group 'redact)

(defcustom redact-gitleaks-scan-non-file-buffers nil
  "是否也扫描没有对应文件的 buffer（`*scratch*'、`*Messages*' 等）。
默认只扫文件 buffer：打开文件才是主要场景，内部 buffer 扫了只会拖慢启动。
需要在临时 buffer 里手动验证密钥时可以打开。"
  :type 'boolean
  :group 'redact)

(defvar redact--gitleaks-availability 'unknown
  "`unknown' / `yes' / `no'，缓存 `executable-find' 的结果。
避免每个 buffer 都去查一次 PATH。")

(defvar redact--gitleaks-cache (make-hash-table :test #'equal)
  "内容 MD5 -> 遮挡位置列表。
值形如 ((BEG END RULE) ...)；同一份文本反复打开时直接复用，
不再起进程，也不在内存里保留明文密钥。")

(defconst redact--gitleaks-cache-max 64
  "缓存条目上限，超过就整体清空。")

(defvar-local redact--gitleaks-overlays nil
  "本 buffer 里由 gitleaks 结果创建的 overlay。")

(defvar-local redact--gitleaks-process nil
  "本 buffer 正在运行的 gitleaks 进程。")

(defvar-local redact--gitleaks-timer nil
  "编辑后重扫的 idle timer。")

(defvar-local redact--gitleaks-kill-timer nil
  "进程超时的 kill timer。")

(defvar-local redact--gitleaks-applied-tick nil
  "结果应用时的 `buffer-chars-modified-tick'。
用来判断已有遮挡是否对应当前内容，避免重复扫描。")

(defvar-local redact--gitleaks-pending-tick nil
  "正在扫描的内容对应的修改计数。
窗口切换和 idle timer 可能同时请求扫描，用它避免重复起进程。")

(defvar-local redact--gitleaks-failed-tick nil
  "在这个修改计数上扫描失败过。
内容不变时不重复起进程，避免持续失败把每次切换 buffer 都拖慢。")

(defun redact--gitleaks-available-p ()
  "gitleaks 是否可用；结果缓存，只查一次 PATH。"
  (when redact-gitleaks-enabled
    (pcase redact--gitleaks-availability
      ('yes t)
      ('no nil)
      (_
       (if (executable-find redact-gitleaks-executable)
           (progn (setq redact--gitleaks-availability 'yes) t)
         (setq redact--gitleaks-availability 'no)
         (message "redact: 找不到 %s，只使用内置规则（brew install gitleaks）"
                  redact-gitleaks-executable)
         nil)))))

(defun redact--gitleaks-line-bounds (line)
  "返回第 LINE 行（从 1 开始）的 (BEG . END)；行号越界返回 nil。"
  (when (and (integerp line) (>= line 1))
    (save-excursion
      (goto-char (point-min))
      (when (= 0 (forward-line (1- line)))
        (cons (line-beginning-position) (line-end-position))))))

(defun redact--gitleaks-find-secret (beg end secret match)
  "在 BEG..END 内定位 SECRET，定位不到时退化到 MATCH。
返回 (BEG . END)，都找不到时返回 nil。
gitleaks 报的 StartColumn 不可靠（实测偏移），所以只按行号 + 文本定位。"
  (let ((case-fold-search nil))
    (save-excursion
      (goto-char beg)
      (cond
       ((and (stringp secret)
             (not (string-empty-p secret))
             (search-forward secret end t))
        (cons (match-beginning 0) (match-end 0)))
       ((and (stringp match)
             (not (string-empty-p match))
             (search-forward match end t))
        (cons (match-beginning 0) (match-end 0)))
       (t nil)))))

(defun redact--gitleaks-push-overlay (beg end rule)
  "把 BEG..END 遮起来，RULE 记到提示里，方便排查误报。
表格行里同样按原文宽度遮挡，避免破坏表格对齐。
已经被整段遮住的不再重复遮：内层 overlay 会把外层整段的 `display'
截成几段，每段都重渲染整串星号，行宽就会翻倍。"
  (unless (redact--masked-overlay beg end)
    (let* ((bounds (redact--union-bounds beg end))
           (start (car bounds))
           (stop (cdr bounds))
           (ov (make-overlay start stop)))
      (overlay-put ov 'redact-gitleaks t)
      (overlay-put ov 'display (redact--mask-string start stop))
      (overlay-put ov 'face 'redact-mask-face)
      (overlay-put ov 'help-echo (format "已遮挡（gitleaks: %s）" rule))
      (overlay-put ov 'evaporate t)
      (push ov redact--gitleaks-overlays))))

(defun redact--gitleaks-locate (findings)
  "把 gitleaks FINDINGS 换算成 buffer 内的遮挡位置，返回 ((BEG END RULE) ...)。
只返回位置，不创建 overlay，方便按内容缓存。"
  (let (entries)
    (dolist (finding findings)
      (let* ((rule (or (plist-get finding :RuleID) "gitleaks"))
             (start (plist-get finding :StartLine))
             (end (or (plist-get finding :EndLine) start))
             (secret (plist-get finding :Secret))
             (match (plist-get finding :Match)))
        (unless (and (stringp secret) (redact--value-ignored-p secret))
          (when (and (integerp start) (integerp end) (>= start 1) (>= end start))
            (if (= start end)
                (when-let* ((bounds (redact--gitleaks-line-bounds start)))
                  (let ((pos (redact--gitleaks-find-secret
                              (car bounds) (cdr bounds) secret match)))
                    (push (if pos
                              (list (car pos) (cdr pos) rule)
                            (list (car bounds) (cdr bounds) rule))
                          entries)))
              (let ((line start))
                (while (<= line end)
                  (when-let* ((bounds (redact--gitleaks-line-bounds line)))
                    (when (< (car bounds) (cdr bounds))
                      (push (list (car bounds) (cdr bounds) rule) entries)))
                  (setq line (1+ line)))))))))
    (nreverse entries)))

(defun redact--gitleaks-clear ()
  "清掉本 buffer 的 gitleaks overlay。"
  (mapc #'delete-overlay redact--gitleaks-overlays)
  (setq redact--gitleaks-overlays nil)
  ;; 主模式重载后列表会被清空，这里按属性兜底，避免 overlay 越积越多。
  (remove-overlays (point-min) (point-max) 'redact-gitleaks t))

(defun redact--gitleaks-render (entries)
  "按 ENTRIES 重建遮挡。整个过程不改变 buffer 的 modified 状态。
位置是相对整个 buffer 算的，所以先 `widen'。"
  (with-silent-modifications
    (save-restriction
      (widen)
      (redact--gitleaks-clear)
      (dolist (entry entries)
        (redact--gitleaks-push-overlay
         (nth 0 entry) (nth 1 entry) (nth 2 entry))))))

(defun redact--gitleaks-cancel ()
  "停掉正在跑的进程和定时器，但保留已有遮挡。"
  (when (process-live-p redact--gitleaks-process)
    (delete-process redact--gitleaks-process))
  (setq redact--gitleaks-process nil)
  (setq redact--gitleaks-pending-tick nil)
  (when (timerp redact--gitleaks-timer)
    (cancel-timer redact--gitleaks-timer)
    (setq redact--gitleaks-timer nil))
  (when (timerp redact--gitleaks-kill-timer)
    (cancel-timer redact--gitleaks-kill-timer)
    (setq redact--gitleaks-kill-timer nil)))

(defun redact--gitleaks-stop ()
  "彻底停止本 buffer 的 gitleaks 工作并清除遮挡。"
  (redact--gitleaks-cancel)
  (redact--gitleaks-clear)
  (setq redact--gitleaks-applied-tick nil)
  (setq redact--gitleaks-pending-tick nil)
  (setq redact--gitleaks-failed-tick nil))

(defun redact--gitleaks-eligible-p ()
  "当前 buffer 是否应该跑 gitleaks。"
  (and redact-gitleaks-enabled
       (redact--gitleaks-available-p)
       (not (minibufferp))
       ;; gitleaks 自己的输出 buffer 必须排除，否则会递归扫描。
       (not (string-prefix-p " *redact-gitleaks-" (buffer-name)))
       (not (member major-mode redact-gitleaks-ignore-modes))
       (or redact-gitleaks-scan-non-file-buffers
           buffer-file-name)
       (<= (buffer-size) redact-gitleaks-max-size)))

(defun redact--gitleaks-json-body (text)
  "从 gitleaks 的输出里截出 JSON 数组。
gitleaks 会把 `leaks found: N' 之类的日志（还带 ANSI 颜色）写到 stdout，
直接解析整段输出会失败，所以从第一个独占一行的 `[' 开始截取。"
  (when (stringp text)
    (let ((start (cond
                  ((string-match-p "\\`[ \t\r\n]*\\[" text) 0)
                  ((string-match "\n\\[" text) (1+ (match-beginning 0)))
                  (t nil))))
      (when start (substring text start)))))

(defun redact--gitleaks-parse (json)
  "把 gitleaks 的 JSON 输出解析成 finding 列表；解析失败返回 nil。
注意不能把 :number-type 设为 integer：Entropy 是浮点数，整份报告会解析失败。"
  (condition-case nil
      (when-let* ((body (redact--gitleaks-json-body json)))
        (json-parse-string body
                           :object-type 'plist
                           :array-type 'list
                           :null-object nil
                           :false-object nil))
    (error nil)))

(defun redact--gitleaks-cache-put (key entries)
  "写入缓存，条目过多时整体清空。"
  (when (> (hash-table-count redact--gitleaks-cache)
           redact--gitleaks-cache-max)
    (clrhash redact--gitleaks-cache))
  (puthash key entries redact--gitleaks-cache))

(defvar redact--gitleaks-tempfiles nil
  "尚未清理的临时文件；Emacs 异常退出时由 `kill-emacs-hook' 兜底删除。")

(defun redact--gitleaks-temp-file (text)
  "把 TEXT 写进一个临时文件并返回文件名。
保留 buffer 的扩展名，让 gitleaks 的路径规则（如 `.env'）生效。
gitleaks 的 `stdin' 模式在 Emacs 的异步管道下读不到 EOF、进程不会退出，
所以只能用 `dir' 模式扫描文件。"
  (let* ((ext (and buffer-file-name
                    (file-name-extension buffer-file-name)))
         (file (make-temp-file "redact-gitleaks-" nil
                               (if ext (concat "." ext) ".txt")))
         (coding-system-for-write 'utf-8-unix))
    (push file redact--gitleaks-tempfiles)
    (write-region text nil file nil 'silent)
    file))

(defun redact--gitleaks-cleanup-temp (file)
  "删除临时文件 FILE 并把它移出待清理列表。"
  (when (and (stringp file) (file-exists-p file))
    (ignore-errors (delete-file file)))
  (setq redact--gitleaks-tempfiles
        (delete file redact--gitleaks-tempfiles)))

(defun redact--gitleaks-cleanup-all-temp ()
  "Emacs 退出前删掉所有扫描用的临时文件。"
  (mapc #'redact--gitleaks-cleanup-temp redact--gitleaks-tempfiles))

(defun redact--gitleaks-sentinel (process buffer out-buf err-buf tick key temp)
  "gitleaks 进程结束时解析结果。
TICK 是启动时的修改计数；buffer 内容此时已经变了就丢弃结果，
等 idle timer 再扫一次，避免把旧位置遮到新内容上。"
  (unwind-protect
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          (when (eq process redact--gitleaks-process)
            (setq redact--gitleaks-process nil)
            (setq redact--gitleaks-pending-tick nil)
            (when (timerp redact--gitleaks-kill-timer)
              (cancel-timer redact--gitleaks-kill-timer)
              (setq redact--gitleaks-kill-timer nil))
            (cond
             ;; 内容已经变了：结果作废，等 idle timer 用新内容再扫。
             ((not (eq tick (buffer-chars-modified-tick))) nil)
             ((and (eq (process-status process) 'exit)
                   (= (process-exit-status process) 0))
              (let* ((json (with-current-buffer out-buf
                             (buffer-string)))
                     (entries (save-restriction
                                (widen)
                                (redact--gitleaks-locate
                                 (redact--gitleaks-parse json)))))
                (redact--gitleaks-cache-put key entries)
                (redact--gitleaks-render entries)
                (setq redact--gitleaks-applied-tick tick)))
             ;; 超时或 gitleaks 自身出错：记下来，同一内容不再重试。
             (t
              (setq redact--gitleaks-failed-tick tick))))))
    (when (buffer-live-p out-buf) (kill-buffer out-buf))
    (when (buffer-live-p err-buf) (kill-buffer err-buf))
    (redact--gitleaks-cleanup-temp temp)))

(defun redact--gitleaks-spawn (text tick key)
  "把 TEXT 写到临时文件后异步跑 `gitleaks dir'。"
  (let* ((buffer (current-buffer))
         (err-buf (generate-new-buffer " *redact-gitleaks-err*"))
         (temp (redact--gitleaks-temp-file text))
         (out-buf (generate-new-buffer " *redact-gitleaks-out*"))
         (config-args (when redact-gitleaks-config
                        (list "--config" (expand-file-name redact-gitleaks-config))))
         (args (append (list "dir" temp
                             "--no-banner"
                             "--no-color"
                             "--log-level" "error"
                             "--report-format" "json"
                             "--report-path" "-"
                             "--exit-code" "0")
                       config-args
                       redact-gitleaks-extra-args))
         process)
    (setq process
          (make-process
           :name "redact-gitleaks"
           :buffer out-buf
           :stderr err-buf
           :noquery t
           :coding 'utf-8-unix
           :command (cons redact-gitleaks-executable args)
           :sentinel (lambda (proc _event)
                       (redact--gitleaks-sentinel
                        proc buffer out-buf err-buf tick key temp))))
    (setq redact--gitleaks-process process)
    (setq redact--gitleaks-kill-timer
          (run-with-timer
           redact-gitleaks-timeout nil
           (lambda ()
             (when (process-live-p process)
               (delete-process process)))))))

(defun redact--gitleaks-start (&optional force)
  "对当前 buffer 异步跑一次 gitleaks。
FORCE 为非 nil 时忽略\"内容没变\"和\"正在扫描同一内容\"的判断。"
  (when (redact--gitleaks-eligible-p)
    (let ((tick (buffer-chars-modified-tick)))
      (unless (and (not force)
                   (or (eq tick redact--gitleaks-applied-tick)
                       (eq tick redact--gitleaks-failed-tick)
                       (and (eq tick redact--gitleaks-pending-tick)
                            (process-live-p redact--gitleaks-process))))
        (redact--gitleaks-cancel)
        (setq redact--gitleaks-failed-tick nil)
        (let* ((text (save-restriction
                       (widen)
                       (buffer-substring-no-properties (point-min) (point-max))))
               (key (md5 text))
               (cached (gethash key redact--gitleaks-cache 'miss)))
          (if (eq cached 'miss)
              (progn
                (setq redact--gitleaks-pending-tick tick)
                (redact--gitleaks-spawn text tick key))
            (redact--gitleaks-cancel)
            (redact--gitleaks-render cached)
            (setq redact--gitleaks-applied-tick tick)))))))

(defun redact--gitleaks-wait ()
  "最多同步等 `redact-gitleaks-blocking-wait' 秒，让首帧就已经遮好。
超时后进程继续在后台跑，结果回来时再补 overlay。
除了等进程退出，还要等 sentinel 真正把结果应用上：
`process-live-p' 变 nil 和 sentinel 执行之间还有一小段空档。"
  (when (and redact-gitleaks-blocking-wait
             (or (process-live-p redact--gitleaks-process)
                 (and (null redact--gitleaks-applied-tick)
                      (null redact--gitleaks-failed-tick))))
    (let ((deadline (+ (float-time) redact-gitleaks-blocking-wait)))
      (while (and (< (float-time) deadline)
                  (or (process-live-p redact--gitleaks-process)
                      (and (null redact--gitleaks-applied-tick)
                           (null redact--gitleaks-failed-tick))))
        (accept-process-output redact--gitleaks-process 0.02)))))

(defun redact--gitleaks-idle-scan (buffer)
  "编辑停下后重扫 BUFFER；buffer 已不可见就不扫，省一次进程。"
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq redact--gitleaks-timer nil)
      (when (and redact-mode
                 (get-buffer-window buffer t))
        (redact--gitleaks-start)))))

(defun redact--gitleaks-schedule ()
  "把重扫推迟到输入停下之后，避免每个字符都起一次进程。"
  (when redact-gitleaks-idle-delay
    ;; 只重置定时器，不动正在跑的进程：它的结果会因为 tick 不符被丢弃，
    ;; 杀了重启反而让连续输入时永远扫不完。
    (when (timerp redact--gitleaks-timer)
      (cancel-timer redact--gitleaks-timer))
    (setq redact--gitleaks-timer
          (run-with-idle-timer redact-gitleaks-idle-delay nil
                               #'redact--gitleaks-idle-scan
                               (current-buffer)))))

(defun redact--gitleaks-after-change (&rest _)
  "buffer 内容变化后安排一次重扫。"
  (when (and redact-gitleaks-enabled
             redact-mode
             (redact--gitleaks-available-p))
    (redact--gitleaks-schedule)))

;;; 前置过滤（超大文件 / 二进制文件直接跳过）
;;
;; 录屏针对的是配置、代码、日志这类文本小文件。几十 MB 的文件和图片、
;; 压缩包、可执行文件不需要遮挡：一是没有可读的密钥，二是扫起来只会拖慢
;; Emacs。这一层在启用前判断，命中就不开启 `redact-mode'。

(defcustom redact-max-buffer-size (* 30 1024 1024)
  "buffer 超过该体积（字节）时完全不启用遮挡。
未修改的 buffer 用文件在磁盘上的字节数；已修改的 buffer 内容可能比
磁盘大，退化成用字符数估算。"
  :type 'integer
  :group 'redact)

(defcustom redact-skip-binary-buffers t
  "二进制文件（图片、压缩包、可执行文件等）不启用遮挡。
Emacs 对含 NUL 字节的文件会把 `buffer-file-coding-system' 设成
`no-conversion'，这里按编码和 major mode 判断。"
  :type 'boolean
  :group 'redact)

(defconst redact--binary-modes
  '(hexl-mode archive-mode tar-mode doc-view-mode image-mode
    pdf-view-mode pdf-info-mode nov-mode)
  "内容不是纯文本的 major mode。")

(defconst redact--binary-sniff-length 4096
  "判断二进制时最多检查 buffer 开头多少个字符。")

(defun redact--buffer-bytes ()
  "估算当前 buffer 的字节数。
未修改时用文件的磁盘大小，比 `buffer-size' 的字符数更接近“文件体积”。"
  (if (and buffer-file-name (not (buffer-modified-p)))
      (let ((attrs (ignore-errors (file-attributes buffer-file-name))))
        (or (and attrs (file-attribute-size attrs))
            (buffer-size)))
    (buffer-size)))

(defun redact--binary-buffer-p ()
  "当前 buffer 是二进制内容时返回 t。
`no-conversion' / `binary' 编码是 Emacs 对二进制文件的判定结果；
渲染类 mode 直接按 major mode 排除；最后再用开头是否出现 NUL 兜底。"
  (or (memq buffer-file-coding-system '(no-conversion binary))
      (apply #'derived-mode-p redact--binary-modes)
      (save-excursion
        (goto-char (point-min))
        (search-forward "\0"
                        (min (point-max)
                             (+ (point-min) redact--binary-sniff-length))
                        t))))

(defun redact--skip-buffer-p ()
  "当前 buffer 是否整体跳过遮挡（太大或不是文本）。"
  (or (> (redact--buffer-bytes) redact-max-buffer-size)
      (and redact-skip-binary-buffers
           (redact--binary-buffer-p))))

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

(defun redact--purge-keywords ()
  "移除 `font-lock-keywords' 里所有由本模块添加的规则。
按 matcher 符号名匹配，不依赖 `redact--font-lock-keywords' 的当前内容：
`doom/reload' 之后旧版规则对象和新的不 `equal'，只删新的会漏掉旧的。"
  (setq font-lock-keywords
        (seq-remove (lambda (kw)
                      (let ((matcher (car-safe kw)))
                        (and (symbolp matcher)
                             (string-prefix-p "redact--" (symbol-name matcher)))))
                    font-lock-keywords)))

(defun redact--install-keywords ()
  "清掉旧规则后重新安装当前 `redact--font-lock-keywords'。"
  (redact--purge-keywords)
  (font-lock-add-keywords nil redact--font-lock-keywords 'append))

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
      (redact--install-keywords)
      (unless font-lock-mode
        (font-lock-mode 1))
      (font-lock-flush)
      (add-hook 'after-change-functions #'redact--pem-after-change nil t)
      (redact--refresh-pem)
      (add-hook 'after-change-functions #'redact--gitleaks-after-change nil t)
      (add-hook 'kill-buffer-hook #'redact--gitleaks-stop nil t)
      (add-hook 'after-change-functions #'redact--table-after-change nil t)
      (add-hook 'kill-buffer-hook #'redact--table-stop nil t)
      (redact--table-refresh)
      ;; 关键：不等 redisplay 的 jit-lock，启用时同步 fontify。
      ;; 否则 buffer 第一次显示时可能先画出明文，下一帧才变成星号。
      (redact--ensure-fontified)
      ;; gitleaks 是异步的，这里只发起扫描，不阻塞打开文件：
      ;; session 恢复时一次打开几十个 buffer，逐个等待会把启动拖慢几十秒。
      ;; 真正显示到窗口时由 `redact--window-buffer-changed' 短暂等一下。
      (redact--gitleaks-start))))

(defun redact--disable ()
  (when redact--enabled
    (with-silent-modifications
      (setq redact--enabled nil)
      (redact--purge-keywords)
      (setq-local font-lock-extra-managed-props redact--saved-managed-props)
      (remove-hook 'after-change-functions #'redact--pem-after-change t)
      (remove-hook 'after-change-functions #'redact--gitleaks-after-change t)
      (remove-hook 'kill-buffer-hook #'redact--gitleaks-stop t)
      (remove-hook 'after-change-functions #'redact--table-after-change t)
      (remove-hook 'kill-buffer-hook #'redact--table-stop t)
      (redact--table-stop)
      (redact--clear-overlays)
      (redact--gitleaks-stop)
      (redact--strip-masks (point-min) (point-max))
      (when font-lock-mode
        (font-lock-flush)))))

(defface redact-modeline-face
  ;; TokyoNight green：锁图标用绿色表示"敏感内容已被安全遮挡"。
  '((t :family "Symbols Nerd Font Mono" :height 1.0 :foreground "#9ece6a"))
  "模型栏锁图标字形（Nerd Font，非 emoji）。
绿色前景代表遮挡已生效、内容处于安全状态。"
  :group 'redact)

;; `defface' 只在 face 第一次定义时写入属性，重载模块不会更新已有 face，
;; 所以配置热加载后颜色会停在上一次的值；这里再设一遍，保证刷新即生效。
(set-face-attribute 'redact-modeline-face nil
                    :family "Symbols Nerd Font Mono"
                    :height 1.0
                    :foreground "#9ece6a")

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
              (eq major-mode 'vterm-mode)
              ;; 超大文件、二进制文件整体跳过
              (redact--skip-buffer-p))
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
             (not (eq major-mode 'vterm-mode))
             (not (redact--skip-buffer-p)))
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
          (redact--fontify-window window)
          ;; 内容换过（改了文件、切了 buffer）就补一次扫描；
          ;; 内容没变时 `redact--gitleaks-start' 立刻返回。
          (when redact-gitleaks-enabled
            (redact--gitleaks-start)
            ;; 第一次显示这个 buffer 时短暂等结果，避免第一帧露出明文。
            ;; 已经扫过的不等，切换 buffer 不受影响。
            (when (null redact--gitleaks-applied-tick)
              (redact--gitleaks-wait))))))))

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

(defun redact--rebuild-buffers ()
  "按当前规则重建所有已启用 `redact-mode' buffer 的遮挡。
先清掉按旧规则留下的文本属性和 overlay，再重新扫描表格和 PEM 块。
`doom/reload' 不会重跑 `redact--enable'，遮挡宽度规则变过以后，
不清掉旧的画法表格看起来就还是错位的。
`buffer-list' 里可能混着已 kill 的 buffer（`doom/reload' 时很常见），
碰到要跳过，否则中途报错后面的 buffer 全都不会被重建。"
  (dolist (buf (buffer-list))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (when (bound-and-true-p redact-mode)
          ;; 规则本身也可能变了（新增/删除 matcher），重新装一遍。
          (when redact--enabled
            (setq-local font-lock-extra-managed-props
                        (delete-dups
                         (append '(display help-echo redact)
                                 (ensure-list font-lock-extra-managed-props))))
            (redact--install-keywords))
          (with-silent-modifications
            (redact--strip-masks (point-min) (point-max))
            (redact--table-refresh)
            (redact--refresh-pem))
          (font-lock-flush)
          (redact--gitleaks-start 'force))))))

(defun redact-refresh ()
  "清掉词表缓存并刷新所有启用 `redact-mode' 的 buffer。
用 `setq' 改过 `redact-words'，或 `doom/reload' 换了遮挡规则后调用。"
  (interactive)
  (setq redact--words-cache nil)
  (clrhash redact--gitleaks-cache)
  (redact--rebuild-buffers)
  (message "redact 规则已刷新"))

;; 启动时 buffer 里还没有 `redact-mode'，这里是空转；`doom/reload' 时
;; 才会真正清掉按旧规则画的属性和 overlay。
(redact--rebuild-buffers)

;;; 启动后初始化
;;
;; Doom 的 leader keymap 在 `doom-after-init-hook' 里的
;; `doom-init-leader-keys-h' 中重建；模块 config.el 加载时用 `map!'
;; 绑的键会被它覆盖。所以这里 append 到 hook 末尾，等它建完再绑。

(defvar redact--modeline-lock-cache nil
  "缓存模型栏锁图标，避免每次 redisplay 重新构造字符串。")

(defun redact--modeline-lock ()
  "模型栏锁图标：用 Symbols Nerd Font Mono 的字形，不用 emoji。
锁用绿色（`redact-modeline-face'），表示遮挡已生效。"
  (if (fboundp 'nerd-icons-faicon)
      (or redact--modeline-lock-cache
          (setq redact--modeline-lock-cache
                (nerd-icons-faicon "nf-fa-lock" :face 'redact-modeline-face)))
    ;; nerd-icons 还没加载时也有正确字形，只是不带颜色。
    (propertize "\uF023" 'face 'redact-modeline-face)))

(defun redact--late-init ()
  "在 Doom 完成 leader key 初始化后启用全局遮挡并绑定快捷键。"
  ;; 图标的 face 可能改过（比如换成绿色），丢掉上一次缓存的字符串，
  ;; 否则重载模块后 modeline 上还是旧颜色。
  (setq redact--modeline-lock-cache nil)
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
  ;; 进程被强杀时 sentinel 仍会清理；这里兜住 Emacs 直接退出的情况。
  (add-hook 'kill-emacs-hook #'redact--gitleaks-cleanup-all-temp)
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
  (when (get-buffer-window (current-buffer))
    (cond
     ;; 内容增长到超过上限（比如往 buffer 里灌了大段日志）时收手。
     ;; 这里用 `buffer-size' 的字符数，比查文件属性便宜，每帧都会跑。
     ((and redact-mode (> (buffer-size) redact-max-buffer-size))
      (redact-mode -1))
     ((not redact-mode)
      (redact--ensure-buffer-enabled)))))

(add-hook 'post-command-hook #'redact--ensure-current-buffer)

(provide 'neoemacs-redact)
;;; config.el ends here
