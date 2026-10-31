import { tool } from "@opencode-ai/plugin";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

/**
 * OpenCode 侧客户端：通过本地 HTTP API 驱动 Emacs Typing Agent。
 *
 * Emacs 是唯一真正改文件的一方；本工具只提交结构化任务并轮询状态。
 * 服务地址默认 http://127.0.0.1:8765，token 默认读
 * ~/.local/state/typing-agent/token。
 */

const DEFAULT_URL = "http://127.0.0.1:8765";

function tokenFilePath(): string {
  const custom = process.env.TYPING_AGENT_TOKEN_FILE;
  if (custom && custom.trim() !== "") return custom;
  return path.join(os.homedir(), ".local", "state", "typing-agent", "token");
}

function serverUrl(): string {
  const url = process.env.TYPING_AGENT_URL ?? DEFAULT_URL;
  return url.replace(/\/+$/, "");
}

function readToken(): string {
  const fromEnv = process.env.TYPING_AGENT_TOKEN;
  if (fromEnv && fromEnv.trim() !== "") return fromEnv.trim();
  const file = tokenFilePath();
  try {
    return fs.readFileSync(file, "utf8").trim();
  } catch {
    throw new Error(
      `找不到 Typing Agent token：${file}。先在 Emacs 里执行 M-x typing-agent-server-start。`,
    );
  }
}

async function request(
  method: "GET" | "POST",
  apiPath: string,
  body?: unknown,
  timeoutMs = 60000,
): Promise<any> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(`${serverUrl()}${apiPath}`, {
      method,
      headers: {
        Authorization: `Bearer ${readToken()}`,
        "Content-Type": "application/json",
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: controller.signal,
    });
    const text = await response.text();
    let json: any;
    try {
      json = JSON.parse(text);
    } catch {
      json = { raw: text };
    }
    if (!response.ok) {
      const message =
        typeof json?.error === "string" ? json.error : text.slice(0, 400);
      throw new Error(`HTTP ${response.status}: ${message}`);
    }
    return json;
  } catch (error: any) {
    if (error?.name === "AbortError") {
      throw new Error(`请求超时（${timeoutMs} ms）：${method} ${apiPath}`);
    }
    if (error instanceof TypeError) {
      throw new Error(
        `连不上 ${serverUrl()}：${error.message}。确认 Emacs 里 HTTP 服务已启动。`,
      );
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

const TERMINAL_STATUSES = new Set(["completed", "failed", "cancelled"]);

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForTask(
  id: string,
  timeoutSeconds: number,
  context: any,
): Promise<any> {
  const deadline = Date.now() + timeoutSeconds * 1000;
  let task: any = null;
  while (Date.now() < deadline) {
    task = await request("GET", `/task/${encodeURIComponent(id)}`);
    context?.metadata?.({
      title: `Typing Agent ${id}`,
      metadata: {
        status: task.status,
        index: task.index,
        total: task.total,
      },
    });
    if (TERMINAL_STATUSES.has(task.status)) return task;
    await sleep(250);
  }
  return { ...(task ?? { id }), timed_out: true };
}

function formatTask(task: any): string {
  const logs: string[] = Array.isArray(task?.log)
    ? task.log
        .slice(0, 8)
        .reverse()
        .map((entry: any) => `[${entry.level}] ${entry.message}`)
    : [];
  const ok = !task?.error && task?.status !== "failed" && task?.status !== "cancelled";
  return JSON.stringify(
    {
      ok,
      id: task?.id ?? null,
      status: task?.status ?? null,
      index: task?.index ?? null,
      total: task?.total ?? null,
      error: task?.error ?? null,
      result: task?.result ?? null,
      timed_out: task?.timed_out ?? false,
      recent_log: logs,
    },
    null,
    2,
  );
}

const OPERATION_HELP = `operations 是操作数组，每项必须带 type：
- open_file        {path}                       打开任务目标文件（只允许任务顶层 file）
- goto_line        {line}                       Normal 状态跳到行
- search_text      {text, occurrence?, unique?} Normal 状态唯一定位文本
- move_cursor      {position, count?}           position: line_start|line_end|next_line|prev_line|buffer_start|buffer_end|word_forward|word_backward|char_forward|char_backward
- enter_insert     {command?}                   command 默认 "i"
- type_text        {text}                       Insert 状态逐字符输入
- backspace        {count?}                     Insert 状态退格
- delete_text      {text?|lines?|count?}        Normal 状态删除
- delete_lines     {count?}                     dd
- insert_newline   {count?}                     Insert 状态换行
- indent           {lines?}                     Normal 状态缩进
- exit_insert      {}                           回到 Normal
- replace_region   {search, replace, occurrence?, unique?} 定位并整体替换，内部逐字符重打
- save_buffer      {}                           校验并写盘
- undo             {count?}                     撤销
- pause / wait     {ms?}                        任务内停顿
状态规则：type_text/backspace/insert_newline 要求 Insert；replace_region/goto_line/search_text/move_cursor/delete_text/delete_lines/indent 要求 Normal（replace_region 会自动进出 Insert）。`;

export default tool({
  description: `通过本地 HTTP API 驱动 Emacs Typing Agent：由 Emacs + Evil 用可见按键逐字符修改代码，OpenCode 不直接写目标文件。
操作类型见 action 参数说明。典型流程：action="task" 提交 file + operations 并等待完成，再检查返回的 status/result；失败时用 action="task_status" 看日志，或用 action="control" control="undo" 回滚。
${OPERATION_HELP}`,
  args: {
    action: tool.schema
      .enum([
        "status",
        "buffer",
        "tasks",
        "task",
        "task_status",
        "control",
        "save",
        "open",
        "goto",
        "search",
        "diff",
        "recording",
      ])
      .describe(
        "status=服务与当前 buffer 状态；buffer=当前 buffer；tasks=最近任务列表；task=提交编辑任务；task_status=查询任务；control=暂停/继续/停止/撤销；save=保存当前 buffer；open=打开文件；goto=跳行；search=搜索；diff=Unified Diff 转任务 spec（不执行）；recording=录制模式开关",
      ),
    file: tool.schema
      .string()
      .optional()
      .describe("目标文件绝对路径；task/open/recording 使用"),
    line: tool.schema
      .number()
      .int()
      .optional()
      .describe("行号（goto/open/recording 使用）"),
    text: tool.schema
      .string()
      .optional()
      .describe("search 接口要搜索的文本"),
    position: tool.schema.string().optional().describe("goto 接口的光标位置"),
    count: tool.schema.number().int().optional().describe("goto 的重复次数"),
    operations: tool.schema
      .array(tool.schema.record(tool.schema.string(), tool.schema.unknown()))
      .optional()
      .describe(`task 的操作数组。${OPERATION_HELP}`),
    options: tool.schema
      .record(tool.schema.string(), tool.schema.unknown())
      .optional()
      .describe(
        "任务选项：speed（速度倍率，默认 1.0）、typo_probability（默认 0.015）、allow_dirty（默认 false）、save（任务结束自动保存）、recording（录制模式）、post_delay（结束停顿秒数）。任务结束不做恢复，停在最后编辑或查看的 buffer。",
      ),
    expected: tool.schema
      .record(tool.schema.string(), tool.schema.unknown())
      .optional()
      .describe(
        "保存前的最终校验：contains/not_contains（字符串数组）、regexp、content（完整内容）、sha256、line_count",
      ),
    id: tool.schema.string().optional().describe("任务 ID（task_status/control 使用）"),
    control: tool.schema
      .enum(["pause", "resume", "stop", "undo"])
      .optional()
      .describe("control 动作"),
    diff: tool.schema.string().optional().describe("Unified Diff 文本（diff 接口）"),
    base_dir: tool.schema
      .string()
      .optional()
      .describe("diff 的基准目录，默认取 OpenCode 当前目录"),
    recording_action: tool.schema
      .enum(["start", "stop"])
      .optional()
      .describe("recording 接口的动作"),
    keep_window: tool.schema
      .boolean()
      .optional()
      .describe("recording stop 时是否保留录制窗口"),
    wait: tool.schema
      .boolean()
      .optional()
      .describe("task 提交后是否等待任务结束，默认 true"),
    timeout_seconds: tool.schema
      .number()
      .optional()
      .describe("等待任务的最长秒数，默认 300"),
  },
  async execute(args, context) {
    try {
      switch (args.action) {
        case "status": {
          const status = await request("GET", "/status");
          return JSON.stringify(status, null, 2);
        }
        case "buffer": {
          const info = await request("GET", "/buffer");
          return JSON.stringify(info, null, 2);
        }
        case "tasks": {
          const list = await request("GET", "/tasks");
          const tasks = Array.isArray(list?.tasks)
            ? list.tasks.map((task: any) => ({
                id: task.id,
                status: task.status,
                file: task.file,
                index: task.index,
                total: task.total,
                created_at: task.created_at,
                error: task.error ?? null,
              }))
            : [];
          return JSON.stringify({ ok: list?.ok !== false, tasks }, null, 2);
        }
        case "task": {
          if (!args.file) throw new Error("task 需要 file");
          if (!args.operations || args.operations.length === 0)
            throw new Error("task 需要非空 operations");
          const submitted = await request("POST", "/task", {
            file: args.file,
            operations: args.operations,
            options: args.options ?? {},
            expected: args.expected,
          });
          const id: string = submitted.id;
          context?.metadata?.({
            title: `Typing Agent ${id}`,
            metadata: { status: submitted.status, total: submitted.total },
          });
          const shouldWait = args.wait !== false;
          if (!shouldWait) return formatTask(submitted);
          const finished = await waitForTask(
            id,
            args.timeout_seconds ?? 300,
            context,
          );
          return formatTask(finished);
        }
        case "task_status": {
          if (!args.id) throw new Error("task_status 需要 id");
          const task = await request(
            "GET",
            `/task/${encodeURIComponent(args.id)}`,
          );
          return formatTask(task);
        }
        case "control": {
          if (!args.control) throw new Error("control 需要 control 动作");
          const body: Record<string, unknown> = {};
          if (args.id) body.id = args.id;
          const result = await request("POST", `/${args.control}`, body);
          return formatTask(result);
        }
        case "save": {
          const saved = await request("POST", "/save", {});
          return JSON.stringify(saved, null, 2);
        }
        case "open": {
          if (!args.file) throw new Error("open 需要 file");
          const opened = await request("POST", "/open", {
            file: args.file,
            line: args.line,
          });
          return JSON.stringify(opened, null, 2);
        }
        case "goto": {
          const moved = await request("POST", "/goto", {
            line: args.line,
            position: args.position,
            count: args.count,
          });
          return JSON.stringify(moved, null, 2);
        }
        case "search": {
          if (!args.text) throw new Error("search 需要 text");
          const found = await request("POST", "/search", { text: args.text });
          return JSON.stringify(found, null, 2);
        }
        case "diff": {
          if (!args.diff) throw new Error("diff 需要 diff 文本");
          const specs = await request("POST", "/diff", {
            diff: args.diff,
            base_dir: args.base_dir ?? context?.directory,
          });
          return JSON.stringify(specs, null, 2);
        }
        case "recording": {
          if (!args.recording_action)
            throw new Error("recording 需要 recording_action（start/stop）");
          const body: Record<string, unknown> = {
            action: args.recording_action,
          };
          if (args.file) body.file = args.file;
          if (args.line) body.line = args.line;
          if (args.keep_window !== undefined) body.keep_window = args.keep_window;
          const result = await request("POST", "/recording", body);
          return JSON.stringify(result, null, 2);
        }
        default:
          throw new Error(`未知 action: ${args.action}`);
      }
    } catch (error: any) {
      return `Typing Agent 调用失败：${error?.message ?? String(error)}`;
    }
  },
});
