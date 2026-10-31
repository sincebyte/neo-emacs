/**
 * Typing Agent Follow —— 让 Emacs 跟着 OpenCode 的“查看文件”动作。
 *
 * OpenCode 的 read 工具只是读磁盘，不会碰 Emacs。这个插件注册
 * `tool execute.before` hook，凡是 read 一个真实文件，就调用 Typing Agent 的
 * `POST /open`：Emacs 会找到该文件的窗口（没有就打开），让它独占当前 frame，
 * 光标居中。这样录制画面里始终能看到“正在看哪里”。
 *
 * 这是 OpenCode v2 插件：目录形式、默认导出 { id, setup }，在 setup 里注册 hook。
 *
 * 零依赖，只使用 node 内置模块。用 node:http 直连回环地址，不经过系统代理。
 * 失败一律静默：Emacs 没启动、服务没开、token 不存在，都不会影响读文件。
 *
 * 环境变量：
 *   TYPING_AGENT_FOLLOW=0        关闭跟随（默认开启）
 *   TYPING_AGENT_URL             默认 http://127.0.0.1:8765
 *   TYPING_AGENT_TOKEN           直接给 token（优先）
 *   TYPING_AGENT_TOKEN_FILE      默认 ~/.local/state/typing-agent/token
 *   TYPING_AGENT_FOLLOW_DEBUG=1  把跟随结果写到 stderr
 */

import * as fs from "node:fs";
import * as http from "node:http";
import * as os from "node:os";
import * as path from "node:path";

const DEFAULT_URL = "http://127.0.0.1:8765";
const OPEN_TIMEOUT_MS = 800;
const THROTTLE_MS = 1200;
const MAX_THROTTLE_ENTRIES = 500;

/** 每个文件上次打开的时间，避免连续 read 反复抢焦点。 */
const lastOpened = new Map();

function debug(message) {
  if ((process.env.TYPING_AGENT_FOLLOW_DEBUG ?? "") === "1") {
    process.stderr.write(`[typing-agent-follow] ${message}\n`);
  }
}

function followEnabled() {
  const value = (process.env.TYPING_AGENT_FOLLOW ?? "").trim().toLowerCase();
  return value !== "0" && value !== "false" && value !== "no";
}

function tokenFile() {
  const custom = (process.env.TYPING_AGENT_TOKEN_FILE ?? "").trim();
  if (custom !== "") return custom;
  return path.join(os.homedir(), ".local", "state", "typing-agent", "token");
}

function serverUrl() {
  return (process.env.TYPING_AGENT_URL ?? DEFAULT_URL).replace(/\/+$/, "");
}

function readToken() {
  const fromEnv = (process.env.TYPING_AGENT_TOKEN ?? "").trim();
  if (fromEnv !== "") return fromEnv;
  return fs.readFileSync(tokenFile(), "utf8").trim();
}

/**
 * read 的 filePath 可能是绝对路径，也可能是相对路径。
 * 相对路径依次按工作目录、项目根解析，取第一个真实存在的。
 */
function resolveFile(filePath, roots) {
  if (typeof filePath !== "string" || filePath === "") return null;
  const candidates = [];
  if (path.isAbsolute(filePath)) {
    candidates.push(filePath);
  } else {
    for (const root of roots) {
      if (typeof root === "string" && root !== "") {
        candidates.push(path.resolve(root, filePath));
      }
    }
  }
  for (const candidate of candidates) {
    try {
      if (fs.statSync(candidate).isFile()) return candidate;
    } catch {
      // 不存在就继续试下一个候选。
    }
  }
  return null;
}

function throttle(file) {
  const now = Date.now();
  const last = lastOpened.get(file) ?? 0;
  if (now - last < THROTTLE_MS) return false;
  lastOpened.set(file, now);
  if (lastOpened.size > MAX_THROTTLE_ENTRIES) {
    // Map 按插入顺序迭代，删掉最旧的一半就够。
    const drop = Math.floor(lastOpened.size / 2);
    let removed = 0;
    for (const key of lastOpened.keys()) {
      lastOpened.delete(key);
      if (++removed >= drop) break;
    }
  }
  return true;
}

function postOpen(file, line) {
  return new Promise((resolve) => {
    let token;
    try {
      token = readToken();
    } catch (error) {
      debug(`读取 token 失败：${error?.message ?? error}`);
      resolve(false);
      return;
    }

    const target = new URL(serverUrl());
    const payload = JSON.stringify(
      Number.isInteger(line) && line > 0 ? { file, line } : { file },
    );

    const request = http.request(
      {
        hostname: target.hostname,
        port: target.port || 80,
        path: "/open",
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(payload),
        },
      },
      (response) => {
        response.resume();
        response.on("end", () => {
          debug(`打开 ${file}（HTTP ${response.statusCode}）`);
          resolve(response.statusCode < 400);
        });
        response.on("error", () => resolve(false));
      },
    );

    request.on("error", (error) => {
      debug(`连接失败：${error?.message ?? error}`);
      resolve(false);
    });
    request.setTimeout(OPEN_TIMEOUT_MS, () => {
      request.destroy();
      resolve(false);
    });
    request.end(payload);
  });
}

export default {
  id: "typing-agent-follow",

  async setup(ctx) {
    const roots = [
      ctx?.location?.directory,
      ctx?.location?.project?.canonical,
    ];
    debug(
      `插件已加载，跟随 ${followEnabled() ? "开启" : "关闭"}，服务 ${serverUrl()}`,
    );

    // 同步 hook：先发起打开请求，不阻塞 read 本身。
    await ctx.tool.hook("execute.before", (event) => {
      try {
        if (!followEnabled()) return;
        if (event?.tool !== "read") return;

        const input = event.input ?? {};
        const file = resolveFile(input.filePath ?? input.path, roots);
        if (!file) return;
        if (!throttle(file)) return;

        const line = Number.isInteger(input.offset) ? input.offset : undefined;
        void postOpen(file, line);
      } catch (error) {
        debug(`hook 失败：${error?.message ?? error}`);
      }
    });
  },
};
