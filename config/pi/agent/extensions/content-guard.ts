/**
 * content-guard: run the ddd-principles Claude hooks inside Pi.
 *
 * The repository keeps its checks in `scripts/content_guard.py` (textlint,
 * markdownlint, terminology, git baselines). This extension adapts Pi events to
 * the JSON contract that script expects, so the same checks run in Pi.
 *
 * Only repositories that contain `scripts/content_guard.py` and
 * `knowledge/index.md` are guarded; other projects are untouched.
 */
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type GuardMode = "check" | "prebash" | "postcheck" | "display" | "remind" | "stop";

interface GuardResult {
  code: number;
  stdout: string;
  stderr: string;
  failedToStart?: string;
}

const GUARD = path.join("scripts", "content_guard.py");
const TIMEOUT_MS: Record<GuardMode, number> = {
  check: 120_000,
  prebash: 60_000,
  postcheck: 120_000,
  display: 30_000,
  remind: 30_000,
  stop: 120_000,
};

function detectRepo(start: string | undefined): string | null {
  if (!start) return null;
  let dir = path.resolve(start);
  for (let depth = 0; depth < 12; depth += 1) {
    if (existsSync(path.join(dir, GUARD)) && existsSync(path.join(dir, "knowledge", "index.md"))) {
      return dir;
    }
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

function repoFor(ctx: ExtensionContext, target?: string): string | null {
  if (target) {
    const fromTarget = detectRepo(path.dirname(path.resolve(target)));
    if (fromTarget) return fromTarget;
  }
  return detectRepo(ctx.cwd);
}

function runGuard(root: string, mode: GuardMode, payload: Record<string, unknown>): Promise<GuardResult> {
  return new Promise((resolve) => {
    const child = spawn("python3", [path.join(root, GUARD), mode], {
      cwd: root,
      env: { ...process.env, CLAUDE_PROJECT_DIR: root },
      stdio: ["pipe", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    let settled = false;
    const finish = (result: GuardResult) => {
      if (settled) return;
      settled = true;
      resolve(result);
    };
    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      finish({ code: 2, stdout, stderr: `${stderr}\ncontent_guard.py ${mode} timed out`.trim() });
    }, TIMEOUT_MS[mode]);
    child.stdout.on("data", (chunk) => { stdout += chunk.toString(); });
    child.stderr.on("data", (chunk) => { stderr += chunk.toString(); });
    child.on("error", (error) => {
      clearTimeout(timer);
      finish({ code: 2, stdout, stderr, failedToStart: error.message });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      finish({ code: code ?? 2, stdout, stderr });
    });
    child.stdin.on("error", () => { /* the process may exit before reading stdin */ });
    child.stdin.end(JSON.stringify(payload));
  });
}

function sessionId(ctx: ExtensionContext): string {
  try {
    return ctx.sessionManager.getSessionId();
  } catch {
    return "pi";
  }
}

function textOf(message: unknown): string {
  if (!message || typeof message !== "object") return "";
  const content = (message as { content?: unknown }).content;
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .filter((part): part is { type: "text"; text: string } =>
        !!part && typeof part === "object" && (part as { type?: string }).type === "text")
      .map((part) => part.text ?? "")
      .join("\n");
  }
  return "";
}

function lastAssistantText(messages: unknown): string {
  if (!Array.isArray(messages)) return "";
  for (let i = messages.length - 1; i >= 0; i -= 1) {
    const message = messages[i] as { role?: string };
    if (message?.role === "assistant") return textOf(message);
  }
  return "";
}

function basePayload(ctx: ExtensionContext, root: string, turnId: number): Record<string, unknown> {
  return {
    cwd: root,
    session_id: sessionId(ctx),
    turn_id: String(turnId),
  };
}

function blocked(result: GuardResult, fallback: string): { block: true; reason: string } {
  const reason = [result.stderr, result.stdout, result.failedToStart, fallback]
    .filter((part) => part && String(part).trim())
    .join("\n")
    .trim();
  return { block: true, reason: reason || fallback };
}

export default function contentGuard(pi: ExtensionAPI): void {
  let turnId = 0;
  let settleAttempts = 0;

  pi.on("session_start", async (_event, ctx) => {
    if (repoFor(ctx)) {
      ctx.ui.notify("content-guard: ddd-principles の検査を有効にしました", "info");
    }
  });

  pi.on("input", async (event, ctx) => {
    const root = repoFor(ctx);
    if (!root) return undefined;
    // 終了時検査の再試行回数は新しいユーザー要求でだけ戻す。
    // turn_start は継続ターンでも発行されるため、そこで戻すと stop の
    // continue が続く限り 3 回制限が効かなくなる。
    settleAttempts = 0;
    const result = await runGuard(root, "remind", basePayload(ctx, root, turnId));
    if (result.code !== 0 || !result.stdout.trim()) return undefined;
    return { action: "transform", text: `${result.stdout.trim()}\n\n${event.text}` };
  });

  pi.on("turn_start", async (event) => {
    turnId = Math.max(turnId, event.turnIndex);
  });

  pi.on("tool_call", async (event, ctx) => {
    const input = (event.input ?? {}) as Record<string, unknown>;
    const target = typeof input.path === "string" ? input.path : undefined;
    const root = repoFor(ctx, target);
    if (!root) return undefined;

    const toolName = event.toolName;
    let mode: GuardMode;
    let mappedName: string;
    let mappedInput: Record<string, unknown>;

    if (toolName === "write" && typeof input.path === "string" && typeof input.content === "string") {
      mode = "check";
      mappedName = "Write";
      mappedInput = { file_path: input.path, content: input.content };
    } else if (toolName === "edit" && typeof input.path === "string" && Array.isArray(input.edits)) {
      mode = "check";
      mappedName = "MultiEdit";
      mappedInput = {
        file_path: input.path,
        edits: (input.edits as Array<{ oldText?: string; newText?: string }>).map((edit) => ({
          old_string: edit.oldText ?? "",
          new_string: edit.newText ?? "",
        })),
      };
    } else if ((toolName === "bash" || toolName === "powershell") && typeof input.command === "string") {
      mode = "prebash";
      mappedName = toolName === "bash" ? "Bash" : "PowerShell";
      mappedInput = { command: input.command };
    } else if (toolName.startsWith("mcp__")) {
      mode = "prebash";
      mappedName = toolName;
      mappedInput = input;
    } else {
      return undefined;
    }

    const result = await runGuard(root, mode, {
      ...basePayload(ctx, root, turnId),
      hook_event_name: mode === "check" ? "PreToolUse" : "PreToolUse",
      tool_name: mappedName,
      tool_input: mappedInput,
      tool_use_id: event.toolCallId,
    });
    if (result.code === 0) return undefined;
    return blocked(result, `${mappedName} の検査で止めました`);
  });

  pi.on("tool_result", async (event, ctx) => {
    const input = (event.input ?? {}) as Record<string, unknown>;
    const target = typeof input.path === "string" ? input.path : undefined;
    const root = repoFor(ctx, target);
    if (!root) return undefined;

    const toolName = event.toolName;
    const isBash = toolName === "bash" || toolName === "powershell";
    const isMcp = toolName.startsWith("mcp__");
    if (!isBash && !isMcp) return undefined;

    const result = await runGuard(root, "postcheck", {
      ...basePayload(ctx, root, turnId),
      hook_event_name: event.isError ? "PostToolUseFailure" : "PostToolUse",
      tool_name: isBash ? (toolName === "bash" ? "Bash" : "PowerShell") : toolName,
      tool_input: input,
      tool_use_id: event.toolCallId,
    });
    if (result.code === 0) return undefined;

    const reason = [result.stderr, result.stdout, result.failedToStart]
      .filter((part) => part && String(part).trim())
      .join("\n")
      .trim();
    return {
      isError: true,
      content: [{ type: "text" as const, text: reason || "書かれたファイルの検査で止めました" }],
    };
  });

  pi.on("message_end", async (event, ctx) => {
    const message = event.message as { role?: string };
    if (message?.role !== "assistant") return undefined;
    const root = repoFor(ctx);
    if (!root) return undefined;
    await runGuard(root, "display", {
      ...basePayload(ctx, root, turnId),
      hook_event_name: "MessageDisplay",
      delta: textOf(message),
    });
    return undefined;
  });

  pi.on("agent_before_settle", async (event, ctx) => {
    const root = repoFor(ctx);
    if (!root) return undefined;
    if (settleAttempts >= 3) {
      ctx.ui.notify("content-guard: 修正の試行が3回に達したため、終了時の検査を保留しました", "warning");
      return undefined;
    }
    settleAttempts += 1;

    const result = await runGuard(root, "stop", {
      ...basePayload(ctx, root, turnId),
      hook_event_name: "Stop",
      last_assistant_message: lastAssistantText(event.context.contextMessages),
      background_tasks: [],
    });

    let decision: { decision?: string; reason?: string } | undefined;
    if (result.stdout.trim()) {
      try {
        decision = JSON.parse(result.stdout.trim());
      } catch {
        decision = undefined;
      }
    }
    const reason = decision?.reason
      ?? [result.stderr, result.failedToStart].filter(Boolean).join("\n").trim();
    if (result.code !== 0 || decision?.decision === "block" || reason) {
      const text = reason || "終了時の検査で止めました";
      return {
        continue: true,
        entries: [{
          type: "custom_message" as const,
          customType: "content-guard",
          content: `content-guard（終了時の検査）:\n${text}\n直してから、もう一度終えてください。`,
          display: true,
        }],
      };
    }
    return undefined;
  });
}
