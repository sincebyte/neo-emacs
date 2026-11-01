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
;;   - 小概率停下来「思考」。
;;
;; 不模拟打错字：写进文件的内容必须一次就是对的。
;;
;; 所有参数都可以通过任务 options 覆盖，见 `typing-agent-humanizer-delay'。

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defgroup typing-agent-humanizer nil
  "Typing Agent 的打字节奏。"
  :group 'typing-agent
  :prefix "typing-agent-")

(defcustom typing-agent-typing-speed 21.0
  "基础打字速度，单位：字符/秒。
11.0 约合每分钟 660 个字符（约 132 WPM），接近人类打字的上限，
配合词内加速和 burst 会更快，看起来是「飞快但仍在人力范畴」。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-typing-speed-variation 0.35
  "每个字符速度的随机浮动比例，0.35 表示 ±35%。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-burst-probability 0.28
  "开始一段连续快速输入的概率（在每个普通字符前判定）。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-burst-speed 17.0
  "连续快速输入时的速度，单位：字符/秒。
17.0 约合每分钟 1020 个字符（约 204 WPM），超过人类打字世界纪录，
是刻意「夸张」的一段手速爆发，用来凸显行云流水的观感。"
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

(defcustom typing-agent-punctuation-pause '(0.03 . 0.12)
  "标点后的停顿范围，单位：秒。"
  :type '(cons number number)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-newline-pause '(0.06 . 0.18)
  "换行后的停顿范围，单位：秒。"
  :type '(cons number number)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-line-break-pause '(0.08 . 0.22)
  "行尾按 ESC 回 Normal 与按 o 开新行之间的停顿范围，单位：秒。
人写完一行会先看一眼再开下一行，按键之间留一点空隙。"
  :type '(cons number number)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-next-line-pause '(0.12 . 0.30)
  "新行打开后到开始输入这一行之间的停顿范围，单位：秒。
让换行后的停顿明显可感知，而不是一口气接着敲。"
  :type '(cons number number)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-thinking-probability 0.002
  "每个字符前停下来思考的概率。
0.002 大约每 500 个字符停一次。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-thinking-pause '(0.20 . 0.55)
  "思考停顿的时间范围，单位：秒。"
  :type '(cons number number)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-key-delay-jitter 0.012
  "每个字符额外加上的固定抖动上限，单位：秒。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-min-key-delay 0.001
  "相邻字符的最小间隔，防止定时器过密导致界面卡顿。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-word-cps-factor 1.9
  "单词内部输入时相对基础速度的倍率。
同一个标识符或单词里字符连贯地快打，贴近真人手速；离开单词后回落。"
  :type 'number
  :group 'typing-agent-humanizer)

(defcustom typing-agent-word-gap-pause '(0.03 . 0.10)
  "从一个单词切换到下一个单词时的停顿范围，单位：秒。"
  :type '(cons number number)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-space-pause '(0.01 . 0.05)
  "敲下空格后的额外停顿范围，单位：秒。"
  :type '(cons number number)
  :group 'typing-agent-humanizer)

(defcustom typing-agent-buffer-enter-pause '(0.35 . 0.70)
  "任务进入目标 buffer 后、开始输入前的停顿范围，单位：秒。
像人一样先看一眼文件再动手。"
  :type '(cons number number)
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

(defun typing-agent-humanizer-punctuation-p (char)
  "CHAR 是否是标点。"
  (and (characterp char)
       (string-match-p (regexp-quote (char-to-string char))
                       typing-agent-punctuation-chars)))

(defun typing-agent-humanizer-word-char-p (char)
  "CHAR 是否属于一个单词。
字母、数字、下划线、美元符号和连续中文都算单词内部，词内会连贯快打。"
  (and (characterp char)
       (or (and (>= char ?0) (<= char ?9))
           (and (>= char ?a) (<= char ?z))
           (and (>= char ?A) (<= char ?Z))
           (memq char '(?_ ?$))
           (and (>= char #x4e00) (<= char #x9fff)))))

(defun typing-agent-humanizer-delay (char &optional speed prev-char)
  "计算输入 CHAR 之前应该等待的时间（秒）。
SPEED 是整体速度倍率，1.0 为正常速度，2.0 表示快一倍。
PREV-CHAR 是同一行刚输入的字符，用于判断单词边界：
同一个单词内部加速连贯输入，跨单词时停顿。返回的延迟已经包含
标点、换行、空格、思考与 burst。"
  (let* ((multiplier (or speed typing-agent-humanizer--speed-multiplier))
         (multiplier (if (and (numberp multiplier) (> multiplier 0))
                         multiplier
                       1.0))
         (word (typing-agent-humanizer-word-char-p char))
         (prev-word (typing-agent-humanizer-word-char-p prev-char))
         (word-body (and word prev-word))
         (base-cps (* typing-agent-typing-speed multiplier))
         (burst (and (> typing-agent-humanizer--burst-left 0)
                     (cl-decf typing-agent-humanizer--burst-left)
                     t))
         (cps (if burst
                  (* typing-agent-burst-speed multiplier)
                ;; 普通字符：词内整体加速，再叠加逐字符随机快慢。
                (* base-cps
                   (if word-body typing-agent-word-cps-factor 1.0)
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
    ;; 从非单词字符进入单词：两个词之间停一下，像人换词时的手部间隙。
    (when (and word (not prev-word) prev-char)
      (setq delay (+ delay
                     (typing-agent-humanizer--random-range
                      typing-agent-word-gap-pause))))
    ;; 空格之后补一个短停顿，让词与词之间自然断开。
    (when (eq char ?\s)
      (setq delay (+ delay
                     (typing-agent-humanizer--random-range
                      typing-agent-space-pause))))
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
