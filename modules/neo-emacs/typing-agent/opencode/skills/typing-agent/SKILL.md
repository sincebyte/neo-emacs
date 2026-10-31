---
name: typing-agent
description: "Drive a running Emacs through a local HTTP API so that Evil types code character by character, visibly and human-like. Use when the user wants an AI coding recording/demo, wants edits performed through Emacs instead of direct file writes, asks to watch the agent type, or mentions Typing Agent / 真人编程 / 录制. Requires the typing-agent server in Emacs and the typing-agent OpenCode tool."
license: MIT
allowed-tools: typing-agent
---

# Emacs Typing Agent

## 这个技能做什么

把“改代码”这件事交给 Emacs 完成：OpenCode 只提交结构化任务，Emacs 用 Evil 的
Normal/Insert 状态、逐字符按键把修改真实地打出来，最后校验并保存。

适用于：

- 录制“AI 真人编程”演示视频；
- 需要在编辑器里留下可见按键过程；
- 用户明确要求由 Emacs 执行修改，而不是直接写文件。

不适用于：批量重构、多文件大改、需要精确控制每个按键细节的场景。

“只是查看文件”也算使用场景：查看前先让 Emacs 打开它（`open`），这样画面和
录制里能看到正在读的是哪个文件、哪一行。

## 使用前检查

1. Emacs 必须正在运行，且服务可用（默认 `http://127.0.0.1:8765`）。
2. 首个调用建议是 `action: "status"`。返回 `ok: true` 且 `server.running: true` 才继续。
3. 连不上时提示用户在 Emacs 里执行 `M-x typing-agent-server-start`（或
   `SPC t y s`）；token 在 `~/.local/state/typing-agent/token`。

## 核心流程

1. **读文件**：先用 `action: "open"` 传 `file` 在 Emacs 里打开；Emacs 会像人一样
   弹出 buffer/文件选择框，输入文件名后跳过去，再跳到 offset 行，并最大化窗口。
   再用常规读文件工具看清目标文件的真实内容（缩进、换行、结尾）。安装了
   `typing-agent-follow` 插件时 read 会自动触发这一步；没装时手动调用。
   文件还不存在时不要 `open`（会报错），直接进下一步提交任务，任务会先在 dired
   里把文件创建出来。
2. **设计操作**：优先用少量 `replace_region`，每个都带唯一、精确的 `search`。
3. **提交任务**：`action: "task"`，传 `file`、`operations`，`options.speed` 按录制需要
   （正常 1.0，慢速演示 0.6–0.8，快 2.0+）。默认会等待任务结束。
   任务开始时 Emacs 会让目标文件独占当前 frame（单窗口、光标居中），已经显示时
   不会再弹选择框。任务结束不做恢复：停在最后编辑或查看的 buffer，不切回原 buffer。
4. **看结果**：`ok: true` 且 `status: "completed"` 才算成功；`result.saved` 表示已写盘。
5. **失败处理**：
   - `409` + 有未保存修改 → 先 `action: "save"`，或确认后加 `options.allow_dirty: true`；
   - `422` 定位失败 → `search` 文本与文件实际内容不一致，重新读取文件后修正；
   - 需要回滚 → `action: "control"`，`control: "undo"`（会同时写回文件）。

## 操作类型速查

每条操作是一个对象，必须有 `type`。

| type | 字段 | 要求的状态 | 说明 |
| --- | --- | --- | --- |
| `open_file` | `path` | 任意 | 只允许打开任务顶层 `file` |
| `goto_line` | `line` | Normal | 跳到行首 |
| `search_text` | `text`, `occurrence?`, `unique?` | Normal | 定位文本，默认要求唯一 |
| `move_cursor` | `position`, `count?` | Normal | `line_start`/`line_end`/`next_line`/`prev_line`/`buffer_start`/`buffer_end`/`word_forward`/`word_backward`/`char_forward`/`char_backward` |
| `enter_insert` | `command?` | Normal | 默认 `i` |
| `type_text` | `text` | Insert | 逐字符输入，多行时按行切换 Insert/Normal |
| `backspace` | `count?` | Insert | 退格 |
| `delete_text` | `text?` / `lines?` / `count?` | Normal | 删除定位文本、整行或光标后字符 |
| `delete_lines` | `count?` | Normal | `dd` |
| `insert_newline` | `count?` | Insert | 换行，行尾用 `ESC` + `o` |
| `indent` | `lines?` | Normal | 缩进 |
| `exit_insert` | — | Insert | 回 Normal |
| `replace_region` | `search`, `replace`, `occurrence?`, `unique?` | Normal | 整行先 `dd` 再用 `O`/`o` 逐行写回，行内用 Visual 删除 + `i` |
| `save_buffer` | — | 任意 | 校验并写盘 |
| `undo` | `count?` | 任意 | 撤销 |
| `pause` / `wait` | `ms?` | 任意 | 任务内停顿，默认 800ms |

`replace_region` 是最常用也最稳的操作：一次只改一处，`search` 包含完整缩进和换行。
不要用它替换大段代码；内容越多，打字时间越长。

## 编辑行为

Emacs 里看到的是真人会做的动作，不是一次性灌入文本：

- 目标文件不存在时先走 dired：打开父目录、按「新建空文件」、输入文件名，停
  `typing-agent-confirm-pause`（默认 1 秒）再回车创建，再回车打开，然后才开始输入；
  每步之间还有 `typing-agent-create-pause` 的停顿。
- 多行文本每写完一行就 `ESC` 回 Normal，再用 `o` 开新行重新进 Insert；行与行之间
  有明显停顿（`ESC`→`o`、新行→开始输入各停一下，可用
  `typing-agent-line-break-pause`、`typing-agent-next-line-pause` 调整）。
  只有在行中换行（行内替换跨行）时才用 `RET`。
- 整行替换与 `delete_lines` 都用 `dd` 删行，再用 `O`/`o` 逐行写回；行内文本用
  Visual 删除 + `i`。
- 行首缩进交给 `TAB`（`indent-for-tab-command`），再用空格/退格校正到目标列；
  主模式的 tab/空格写法与预期不同时按预期字符改写，落盘内容逐字符一致。
- 每段输入结束都会校验实际内容，发现自动配对、自动缩进、snippet 展开等干扰立刻失败，
  不会带着错误内容保存。

## 代码补全弹框（Eglot + corfu）

目标 buffer 由 Eglot 管理时，任务会像人一样一边输入一边看补全弹框，默认开启
（`options.completion`，设 `false` 关闭）。

- **什么时候看**：输入 `.` 或标识符字符后；只有目标行后面还有标识符字符时才检查，
  单词已写完、行尾、标点直接跳过；字符串和注释里不触发。
- **候选多个**：继续逐字符输入让弹框自己筛，弹框留在屏幕上。
- **只剩一个**：候选必须带 Eglot 的 LSP item，且纯文本（`insertText`）正好是目标行
  从补全起点开始的前缀、比已输入部分更长，才选中；否则继续手动输入。
- **不重复输入**：选中后按实际写入的字符数推进字符索引，已经补全的字符不会再敲一遍。
- **不改写内容**：选中前清掉 LSP item 的 `textEdit`、`insertTextFormat`、
  `additionalTextEdits`、`command`、`data`，所以不会展开 snippet、不会自动 import、
  不会触发 resolve 改写；插入仍走 `corfu-insert`，undo 分组与用户按 `RET` 一致。
- **插入后校验**：buffer 里那段文本必须正好等于候选纯文本，否则恢复前缀并让任务失败。
- 退出 Insert 前先收起弹框，避免 `ESC` 被 corfu 按键映射吃掉。

含义是：写 Java 这类有 LSP 的代码时，可以照常写完整目标文本（比如
`System.out.println(...)`），任务会在 `System.out.` 后等弹框、在候选唯一时自动补完，
最终落盘内容仍与 `expected` 逐字符一致。没有 Eglot 的 buffer 行为不变。

## 任务示例

```json
{
  "action": "task",
  "file": "/Users/van/project/src/main/java/UserService.java",
  "options": { "speed": 1.0, "typo_probability": 0.01 },
  "operations": [
    { "type": "search_text", "text": "public User find(Long id) {" },
    { "type": "replace_region",
      "search": "        return repository.findById(id);\n",
      "replace": "        return repository.findById(id)\n                .orElseThrow(() -> new NotFoundException(id));\n" },
    { "type": "save_buffer" }
  ],
  "expected": { "contains": ["orElseThrow"], "not_contains": ["return repository.findById(id);"] }
}
```

`expected` 可选，在 `save_buffer` 前校验最终内容；失败则整个任务失败且不保存。
支持 `contains`、`not_contains`（字符串数组）、`regexp`、`content`、`sha256`、`line_count`。

## 任务选项

| 选项 | 默认 | 说明 |
| --- | --- | --- |
| `speed` | 1.0 | 打字速度倍率 |
| `typo_probability` | 0.015 | 模拟打错并自动改正的概率，0 关闭 |
| `allow_dirty` | false | 允许目标 buffer 有未保存修改 |
| `save` | false | 任务结束后自动保存 |
| `recording` | false | 进入录制模式（整理窗口） |
| `completion` | true | 在 Eglot 管理的 buffer 里接入补全弹框 |
| `post_delay` | 1.5 | 结束前停顿秒数 |

## 其他 action

- `status` / `buffer` / `tasks` / `task_status`：只读查询。
- `open` `{file, line?}`、`goto` `{line}`、`search` `{text}`：直接操作当前可见 buffer。
- `save`：保存当前可见 buffer。
- `control` `{control: "pause"|"resume"|"stop"|"undo", id?}`：控制任务；不传 `id` 用当前任务。
- `diff` `{diff, base_dir?}`：把 Unified Diff 转成 `specs`（每项含 `file` 与
  `operations`），**不执行**；确认后再作为 `task` 提交。
- `recording` `{recording_action: "start"|"stop", file?, line?, keep_window?}`：录制窗口开关。

## 限制

- 一次只能跑一个任务；已有任务运行时提交会返回 `409`。
- 第一版是单文件任务，`open_file` 不能切到别的文件。
- 目标文件不存在时，任务会先在 dired 里创建（打开父目录、新建空文件、输入文件名、
  回车），创建完才开始输入；buffer 不能只读，默认不能有未保存修改。
- 任务期间会临时关闭 electric-indent、自动配对、snippet 等干扰，结束后恢复；
  有补全任务时 `corfu-mode` 保持开启，只用 buffer 局部的 `corfu-auto: nil` 阻止
  自动弹框，由任务按需触发。
- 不要手动编辑正在执行任务的 buffer；也不要同时用其他工具改同一个文件。
