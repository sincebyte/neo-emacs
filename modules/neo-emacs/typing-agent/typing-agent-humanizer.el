;;; typing-agent-humanizer.el --- 真人打字节奏模拟 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 只负责「什么时候输入下一个字符」，不负责编辑本身。
;; 时间单位统一为秒，方便直接交给 `run-at-time'。
;;
;; 节奏模型：
;;   - 基础速度 + 每人不同的随机抖动；
;;   - 遇到标点、换行稍作停顿；
;;   - 小概率进入 burst（连续快速输入一段）；
;;   - 小概率停下来「思考」；
;;   - 小概率打错字符，停顿后删除并重新输入。
;;
;; 所有参数都可以通过任务 options 覆盖，见 `typing-agent-humanizer-delay'。

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defgroup typing-agent-humanizer nil
  "Typing Agent 的打字节奏。"
  :group 'typing-agent
  :prefix "typing-agent-")

(defcustom typing-agent-typing-speed 11.0
  "基础打字速度，单位：字符/秒。
11 大约相当于每分钟 130 个字符，录屏时不会太拖沓。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-typing-speed-variation 0.35
  "每个字符速度的随机浮动比例，0.35 表示 ±35%。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-burst-probability 0.16
  "开始一段连续快速输入的概率（在每个普通字符前判定）。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-burst-speed 22.0
  "连续快速输入时的速度，单位：字符/秒。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-burst-length '(4 . 12)
  "一段 burst 持续的字符数范围。"
  :type '(cons integer integer)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-punctuation-chars ".。,:：;；!！?？)】}"
  "输入这些字符之后会插入一个较短停顿。"
  :type 'string
  :group 'typing-agent-humanizer)

(defcustom typing-agent-punctuation-pause '(0.10 . 0.32)
  "标点后的停顿范围，单位：秒。"
  :type '(cons number number)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-newline-pause '(0.16 . 0.48)
  "换行后的停顿范围，单位：秒。"
  :type '(cons number number)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-line-break-pause '(0.22 . 0.50)
  "行尾按 ESC 回 Normal 与按 o 开新行之间的停顿范围，单位：秒。
人写完一行会先看一眼再开下一行，按键之间留一点空隙。"
  :type '(cons number number)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-next-line-pause '(0.40 . 0.95)
  "新行打开后到开始输入这一行之间的停顿范围，单位：秒。
让换行后的停顿明显可感知，而不是一口气接着敲。"
  :type '(cons number number)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-thinking-probability 0.006
  "每个字符前停下来思考的概率。
0.006 大约每 160 个字符停一次。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-thinking-pause '(0.40 . 1.30)
  "思考停顿的时间范围，单位：秒。"
  :type '(cons number number)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-typo-probability 0.015
  "打错字符的概率。
只对 ASCII 字母、数字和常见符号生效；中文不模拟错字。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-correction-delay '(0.18 . 0.42)
  "发现打错到按下退格之间的停顿范围，单位：秒。"
  :type '(cons number number)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-key-delay-jitter 0.012
  "每个字符额外加上的固定抖动上限，单位：秒。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-min-key-delay 0.006
  "相邻字符的最小间隔，防止定时器过密导致界面卡顿。"
  :type 'number
  :group 'typing-agent-humanizer)

(defvar typing-agent-humanizer--burst-left 0
  "当前 burst 还剩多少个字符。
由 Typing Engine 在任务开始时通过 `typing-agent-humanizer-reset' 清空。")

(defvar typing-agent-humanizer--speed-multiplier 1.0
  "本次任务的整体速度倍率。")

(defun typing-agent-humanizer-reset (&optional speed-multiplier)
  "重置节奏状态。SPEED-MULTIPLIER 为任务级速度倍率。"
  (setq typing-agent-humanizer--burst-left 0)
  (setq typing-agent-humanizer--speed-multiplier
        (if (and (numberp speed-multiplier) (> speed-multiplier 0))
            (float speed-multiplier)
          1.0)))

(defun typing-agent-humanizer--random-range (range)
  "从 (MIN . MAX) 中均匀取一个浮点数。"
  (let ((min (float (car range)))
        (max (float (cdr range))))
    (if (<= max min)
        min
      (+ min (* (- max min) (/ (float (random 10000)) 10000.0))))))

(defun typing-agent-humanizer--clamp (value min max)
  "把 VALUE 限制在 MIN..MAX。"
  (max min (min max value)))

(defun typing-agent-humanizer-punctuation-p (char)
  "CHAR 是否是标点。"
  (and (characterp char)
       (string-match-p (regexp-quote (char-to-string char))
                       typing-agent-punctuation-chars)))

(defun typing-agent-humanizer--ascii-code-char-p (char)
  "CHAR 是否是可以模拟打错的代码字符。"
  (and (characterp char)
       (< 31 char 127)
       (not (memq char '(?\n ?\r ?\t)))))

(defconst typing-agent-humanizer--typo-map
  '((?a . (?s ?q ?z))
    (?b . (?v ?n ?g))
    (?c . (?x ?v ?d))
    (?d . (?s ?f ?e))
    (?e . (?w ?r ?d))
    (?f . (?d ?g ?r))
    (?g . (?f ?h ?t))
    (?h . (?g ?j ?y))
    (?i . (?u ?o ?k))
    (?j . (?h ?k ?u))
    (?k . (?j ?l ?i))
    (?l . (?k ?\; ?o))
    (?m . (?n ?j ?k))
    (?n . (?b ?m ?h))
    (?o . (?i ?p ?l))
    (?p . (?o ?\[ ?l))
    (?q . (?w ?a ?1))
    (?r . (?e ?t ?f))
    (?s . (?a ?d ?w))
    (?t . (?r ?y ?g))
    (?u . (?y ?i ?j))
    (?v . (?c ?b ?f))
    (?w . (?q ?e ?s))
    (?x . (?z ?c ?s))
    (?y . (?t ?u ?h))
    (?z . (?x ?a ?s))
    (?0 . (?9 ?o ?p))
    (?1 . (?2 ?q ?`))
    (?2 . (?3 ?w ?1))
    (?3 . (?4 ?e ?2))
    (?4 . (?5 ?r ?3))
    (?5 . (?6 ?t ?4))
    (?6 . (?7 ?y ?5))
    (?7 . (?8 ?u ?6))
    (?8 . (?9 ?i ?7))
    (?9 . (?0 ?o ?8))
    (?\; . (?l ?' ?:))
    (?, . (?m ?. ?<))
    (?. . (?, ?/ ?>))
    (?- . (?= ?0 ?\[))
    (?= . (?- ?+ ?\])))
  "相邻键位映射，用来生成「像手滑按到旁边键」的错字。")

(defun typing-agent-humanizer-typo-char (char)
  "为 CHAR 生成一个相邻键位的错字；没有映射时返回 nil。"
  (let ((candidates (cdr (assq char typing-agent-humanizer--typo-map))))
    (and candidates
         (nth (random (length candidates)) candidates))))

(defun typing-agent-humanizer-should-typo-p (char &optional speed)
  "是否应该为 CHAR 模拟一次打错。
SPEED 是整体速度倍率；打字越快，错字概率越低。"
  (and (typing-agent-humanizer--ascii-code-char-p char)
       (typing-agent-humanizer-typo-char char)
       (> typing-agent-typo-probability 0)
       (< (random 10000)
          (round (* 10000
                    (typing-agent-humanizer--clamp
                     (* typing-agent-typo-probability
                        (or speed typing-agent-humanizer--speed-multiplier))
                     0.0 1.0))))))

(defun typing-agent-humanizer-correction-delay ()
  "按下退格前的停顿。"
  (typing-agent-humanizer--random-range typing-agent-correction-delay))

(defun typing-agent-humanizer-delay (char &optional speed)
  "计算输入 CHAR 之前应该等待的时间（秒）。
SPEED 是整体速度倍率，1.0 为正常速度，2.0 表示快一倍。
返回的延迟已经包含标点、换行、思考与 burst。"
  (let* ((multiplier (or speed typing-agent-humanizer--speed-multiplier))
         (multiplier (if (and (numberp multiplier) (> multiplier 0))
                         multiplier
                       1.0))
         (base-cps (* typing-agent-typing-speed multiplier))
         (burst (and (> typing-agent-humanizer--burst-left 0)
                     (cl-decf typing-agent-humanizer--burst-left)
                     t))
         (cps (if burst
                  (* typing-agent-burst-speed multiplier)
                ;; 普通字符：在基础速度上下浮动
                (* base-cps
                   (+ 1.0
                      (* typing-agent-typing-speed-variation
                         (- (* 2.0 (/ (float (random 10000)) 10000.0)) 1.0))))))
         (delay (/ 1.0 (max 0.5 cps)))
         (delay (+ delay
                   (* typing-agent-key-delay-jitter
                      (/ (float (random 10000)) 10000.0)))))
    ;; 新的一段 burst：普通字符前按概率触发
    (when (and (not burst)
               (> typing-agent-burst-probability 0)
               (< (random 10000)
                  (round (* 10000 typing-agent-burst-probability))))
      (let ((lo (car typing-agent-burst-length))
            (hi (cdr typing-agent-burst-length)))
        (setq typing-agent-humanizer--burst-left
              (+ lo (random (1+ (max 0 (- hi lo))))))))
    ;; 标点后停顿
    (when (typing-agent-humanizer-punctuation-p char)
      (setq delay (+ delay
                     (typing-agent-humanizer--random-range
                      typing-agent-punctuation-pause))))
    ;; 换行后的停顿
    (when (memq char '(?\n ?\r))
      (setq delay (+ delay
                     (typing-agent-humanizer--random-range
                      typing-agent-newline-pause))))
    ;; 思考停顿
    (when (and (> typing-agent-thinking-probability 0)
               (< (random 10000)
                  (round (* 10000 typing-agent-thinking-probability))))
      (setq delay (+ delay
                     (typing-agent-humanizer--random-range
                      typing-agent-thinking-pause))))
    (max typing-agent-min-key-delay delay)))

(provide 'typing-agent-humanizer)
;;; typing-agent-humanizer.el ends here
