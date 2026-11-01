#!/usr/bin/env bun
/**
 * Typing Agent 的 MCP stdio server（零依赖）。
 *
 * 它本身不碰 Emacs，只是把 Emacs Typing Agent 的 HTTP API 包装成 MCP 工具。
 * 适合给 OpenCode 以外的 MCP 客户端使用；OpenCode 里更推荐直接用
 * ~/.config/opencode/tools/typing-agent.ts 原生工具，不必走 MCP。
 *
 * 运行：bun mcp/typing-agent-mcp.ts
 *
 * 环境变量：
 *   TYPING_AGENT_URL         默认 http://127.0.0.1:8765
 *   TYPING_AGENT_TOKEN       直接给 token（优先）
 *   TYPING_AGENT_TOKEN_FILE  默认 ~/.local/state/typing-agent/token
 *   TYPING_AGENT_MCP_DEBUG   设为 1 时把日志写到 stderr
 */

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { createInterface } from "node:readline";

const PROTOCOL_VERSION = "2024-11-05";
const SERVER_NAME = "typing-agent";
const SERVER_VERSION = "0.1.0";
const DEFAULT_URL = "http://127.0.0.1:8765";

function debug(message: string): void {
  if (process.env.TYPING_AGENT_MCP_DEBUG === "1") {
    process.stderr.write(`[typing-agent-mcp] ${message}\n`);
  }
}

function tokenFilePath(): string {
  const custom = process.env.TYPING_AGENT_TOKEN_FILE;
  if (custom && custom.trim() !== "") return custom;
  return path.join(os.homedir(), ".local", "state", "typing-agent", "token");
}

function serverUrl(): string {
  return (process.env.TYPING_AGENT_URL ?? DEFAULT_URL).replace(/\/+$/, "");
}

function readToken(): string {
  const fromEnv = process.env.TYPING_AGENT_TOKEN;
  if (fromEnv && fromEnv.trim() !== "") return fromEnv.trim();
  try {
    return fs.readFileSync(tokenFilePath(), "utf8").trim();
  } catch {
    throw new Error(
      `找不到 Typing Agent token：${tokenFilePath()}。请先在 Emacs 里执行 M-x typing-agent-server-start。`,
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
        `连不上 ${serverUrl()}：${error.message}。确认 Emacs 的 Typing Agent 服务已启动。`,
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

async function waitForTask(id: string, timeoutSeconds: number): Promise<any> {
  const deadline = Date.now() + timeoutSeconds * 1000;
  let task: any = null;
  while (Date.now() < deadline) {
    task = await request("GET", `/task/${encodeURIComponent(id)}`);
    if (TERMINAL_STATUSES.has(task.status)) return task;
    await sleep(250);
  }
  return { ...(task ?? { id }), timed_out: true };
}

function formatTask(task: any): any {
  const logs: string[] = Array.isArray(task?.log)
    ? task.log
        .slice(0, 8)
        .reverse()
        .map((entry: any) => `[${entry.level}] ${entry.message}`)
    : [];
  return {
    ok:
      !task?.error &&
      task?.status !== "failed" &&
      task?.status !== "cancelled",
    id: task?.id ?? null,
    status: task?.status ?? null,
    index: task?.index ?? null,
    total: task?.total ?? null,
    error: task?.error ?? null,
    result: task?.result ?? null,
    timed_out: task?.timed_out ?? false,
    recent_log: logs,
  };
}

const OPERATION_HELP = `operations 是操作数组，每项必须带 type：
open_file {path}、goto_line {line}、search_text {text, occurrence?, unique?}、
move_cursor {position, count?}（line_start|line_end|next_line|prev_line|buffer_start|buffer_end|word_forward|word_backward|char_forward|char_backward）、
enter_insert {command?}、type_text {text}、backspace {count?}、
delete_text {text?|lines?|count?}、delete_lines {count?}、insert_newline {count?}、
indent {lines?}、exit_insert {}、replace_region {search, replace, occurrence?, unique?}、
save_buffer {}、undo {count?}、pause/wait {ms?}。
type_text/backspace/insert_newline 要求 Insert；其余编辑操作要求 Normal（replace_region 自动进出 Insert）。`;

const TOOLS = [
  {
    name: "status",
    description:
      "查看 Emacs Typing Agent 服务状态：版本、服务、当前 buffer、活动任务。调用任何其他工具前先确认服务可达。",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
  },
  {
    name: "task",
    description: `提交一个编辑任务，由 Emacs + Evil 用可见按键逐字符修改代码。OpenCode 不直接写文件。
任务开始时 Emacs 会自动找到目标文件并让它独占当前 frame（单窗口），结束默认保持单窗口。
${OPERATION_HELP}`,
    inputSchema: {
      type: "object",
      properties: {
        file: { type: "string", description: "目标文件绝对路径" },
        operations: {
          type: "array",
          description: OPERATION_HELP,
          items: { type: "object" },
        },
        options: {
          type: "object",
          description:
            "speed（默认 1.0，约 11 字符/秒）、allow_dirty、save、recording、completion（Eglot 补全弹框，默认 true）、post_delay。任务运行期间输入被锁定（停止只能 control=stop）；任务结束不做恢复，停在最后编辑或查看的 buffer",
        },
        expected: {
          type: "object",
          description:
            "保存前校验：contains/not_contains（字符串数组）、regexp、content、sha256、line_count",
        },
        wait: {
          type: "boolean",
          description: "是否等待任务结束，默认 true；长任务建议 false 后轮询",
        },
        timeout_seconds: {
          type: "number",
          description: "等待任务的最长秒数，默认 300",
        },
      },
      required: ["file", "operations"],
      additionalProperties: false,
    },
  },
  {
    name: "task_status",
    description: "查询单个任务的状态、进度、错误与最近日志。",
    inputSchema: {
      type: "object",
      properties: { id: { type: "string", description: "任务 ID" } },
      required: ["id"],
      additionalProperties: false,
    },
  },
  {
    name: "control",
    description:
      "控制任务：pause 暂停、resume 继续、stop 取消、undo 撤销并把快照写回文件。不传 id 时作用于当前任务。",
    inputSchema: {
      type: "object",
      properties: {
        control: {
          type: "string",
          enum: ["pause", "resume", "stop", "undo"],
        },
        id: { type: "string", description: "任务 ID，可省略" },
      },
      required: ["control"],
      additionalProperties: false,
    },
  },
  {
    name: "save",
    description: "保存用户当前可见 buffer。",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
  },
  {
    name: "open",
    description: "打开文件并最大化窗口，可跳到指定行。",
    inputSchema: {
      type: "object",
      properties: {
        file: { type: "string" },
        line: { type: "number" },
      },
      required: ["file"],
      additionalProperties: false,
    },
  },
  {
    name: "goto",
    description:
      "在用户当前 buffer 中跳转：line 或 position（line_start|line_end|buffer_start|buffer_end|...），count 为重复次数。",
    inputSchema: {
      type: "object",
      properties: {
        line: { type: "number" },
        position: { type: "string" },
        count: { type: "number" },
      },
      additionalProperties: false,
    },
  },
  {
    name: "search",
    description: "在用户当前 buffer 中搜索文本并定位。",
    inputSchema: {
      type: "object",
      properties: {
        text: { type: "string" },
        occurrence: { type: "number" },
        unique: { type: "boolean" },
      },
      required: ["text"],
      additionalProperties: false,
    },
  },
  {
    name: "diff",
    description:
      "把 Unified Diff 转成任务 specs（file + operations），只转换不执行。确认后再用 task 提交。",
    inputSchema: {
      type: "object",
      properties: {
        diff: { type: "string", description: "Unified Diff 文本" },
        base_dir: { type: "string", description: "基准目录" },
      },
      required: ["diff"],
      additionalProperties: false,
    },
  },
  {
    name: "recording",
    description: "录制模式开关：start 整理窗口，stop 恢复布局。",
    inputSchema: {
      type: "object",
      properties: {
        action: { type: "string", enum: ["start", "stop"] },
        file: { type: "string" },
        line: { type: "number" },
        keep_window: { type: "boolean" },
      },
      required: ["action"],
      additionalProperties: false,
    },
  },
] as const;

async function callTool(name: string, args: any): Promise<any> {
  switch (name) {
    case "status":
      return request("GET", "/status");
    case "task": {
      if (!args?.file) throw new Error("task 需要 file");
      if (!Array.isArray(args?.operations) || args.operations.length === 0)
        throw new Error("task 需要非空 operations");
      const submitted = await request("POST", "/task", {
        file: args.file,
        operations: args.operations,
        options: args.options ?? {},
        expected: args.expected,
      });
      if (args.wait === false) return formatTask(submitted);
      return formatTask(
        await waitForTask(submitted.id, args.timeout_seconds ?? 300),
      );
    }
    case "task_status": {
      if (!args?.id) throw new Error("task_status 需要 id");
      return formatTask(
        await request("GET", `/task/${encodeURIComponent(args.id)}`),
      );
    }
    case "control": {
      if (!args?.control) throw new Error("control 需要 control 动作");
      const body: Record<string, unknown> = {};
      if (args.id) body.id = args.id;
      return formatTask(
        await request("POST", `/${args.control}`, body),
      );
    }
    case "save":
      return request("POST", "/save", {});
    case "open": {
      if (!args?.file) throw new Error("open 需要 file");
      return request("POST", "/open", {
        file: args.file,
        line: args.line,
      });
    }
    case "goto":
      return request("POST", "/goto", {
        line: args.line,
        position: args.position,
        count: args.count,
      });
    case "search": {
      if (!args?.text) throw new Error("search 需要 text");
      return request("POST", "/search", {
        text: args.text,
        occurrence: args.occurrence,
        unique: args.unique,
      });
    }
    case "diff": {
      if (!args?.diff) throw new Error("diff 需要 diff 文本");
      return request("POST", "/diff", {
        diff: args.diff,
        base_dir: args.base_dir ?? process.cwd(),
      });
    }
    case "recording": {
      if (!args?.action) throw new Error("recording 需要 action");
      return request("POST", "/recording", {
        action: args.action,
        file: args.file,
        line: args.line,
        keep_window: args.keep_window,
      });
    }
    default:
      throw new Error(`未知工具：${name}`);
  }
}

function reply(id: unknown, result: unknown): void {
  process.stdout.write(
    JSON.stringify({ jsonrpc: "2.0", id, result }) + "\n",
  );
}

function replyError(id: unknown, code: number, message: string): void {
  process.stdout.write(
    JSON.stringify({
      jsonrpc: "2.0",
      id,
      error: { code, message },
    }) + "\n",
  );
}

async function handle(message: any): Promise<void> {
  const { id, method, params } = message;
  const isNotification = id === undefined || id === null;

  try {
    switch (method) {
      case "initialize":
        reply(id, {
          protocolVersion: PROTOCOL_VERSION,
          capabilities: { tools: {} },
          serverInfo: { name: SERVER_NAME, version: SERVER_VERSION },
        });
        return;

      case "notifications/initialized":
      case "notifications/cancelled":
        return;

      case "ping":
        reply(id, {});
        return;

      case "tools/list":
        reply(id, { tools: TOOLS });
        return;

      case "tools/call": {
        const name = params?.name;
        const args = params?.arguments ?? {};
        if (typeof name !== "string") {
          replyError(id, -32602, "tools/call 缺少 name");
          return;
        }
        try {
          const result = await callTool(name, args);
          reply(id, {
            content: [
              { type: "text", text: JSON.stringify(result, null, 2) },
            ],
            isError: false,
          });
        } catch (error: any) {
          reply(id, {
            content: [
              {
                type: "text",
                text: error?.message ?? String(error),
              },
            ],
            isError: true,
          });
        }
        return;
      }

      default:
        if (!isNotification) {
          replyError(id, -32601, `不支持的方法：${method}`);
        }
    }
  } catch (error: any) {
    debug(`处理 ${method} 失败：${error?.message ?? error}`);
    if (!isNotification) {
      replyError(id, -32603, error?.message ?? String(error));
    }
  }
}

const rl = createInterface({ input: process.stdin, crlfDelay: Infinity });

rl.on("line", (line: string) => {
  const trimmed = line.trim();
  if (trimmed === "") return;
  let message: any;
  try {
    message = JSON.parse(trimmed);
  } catch (error: any) {
    debug(`无法解析 JSON：${error?.message ?? error}`);
    replyError(null, -32700, "JSON 解析失败");
    return;
  }
  debug(`收到 ${message.method ?? "响应"}`);
  void handle(message);
});

rl.on("close", () => {
  process.exit(0);
});
