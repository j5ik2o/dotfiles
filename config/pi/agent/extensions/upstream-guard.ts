/**
 * upstream-guard: 禁止の宛先（既定は nrslib）への push とマージを、Pi の bash 実行前に止める。
 *
 * 判定は既存の実行ファイル（`~/.local/bin/upstream-guard`、中身は
 * `scripts/upstream_guard.py`）に任せる。ここでは判定を書かない。Claude Code と Codex の
 * PreToolUse フックが呼ぶのと同じ `upstream-guard check --cwd <dir> -- '<command>'` を spawn する。
 *
 * 対象にするのは、Orca が起動したセッション（環境変数 ORCA_AGENT_SESSION_ID がある）だけ。
 * オーナーの対話のセッションでは何もしない。フックと同じ線引きにしている。
 *
 * 止めるのは終了コード 2（拒否）のときだけ。拡張の側の失敗（実行ファイルが PATH に無い・
 * 時間切れ・想定外の終了コード）は、コマンドを通したうえで 1 行の警告を出す。ここで閉じると
 * 全ボットの bash が止まって作業が全停止するため。警告は TUI へ出し、そのツール結果の本文にも
 * 足してモデルへ渡す（副元帥へ知らせられるように）。
 *
 * 緊急時に拡張ごと止めるには `PI_UPSTREAM_GUARD_DISABLED=1` を渡す（`0` と `false` は止めない）。
 */
import { spawn } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const GUARD_BIN = "upstream-guard";
// upstream-guard check の内部（git の設定読みと判定）は数秒で終わる。待ち続けない。
const TIMEOUT_MS = 15_000;
// 警告をモデルへ渡すのは tool_result のとき。止められた呼び出しでは来ないので、上限を置く。
const MAX_PENDING_WARNINGS = 32;
const DISABLE_ENV = "PI_UPSTREAM_GUARD_DISABLED";
const SESSION_ENV = "ORCA_AGENT_SESSION_ID";
// upstream-guard check は 1 行目に判定の種類を出す（allow / warn / deny）。
const VERDICT_WORDS = new Set(["allow", "warn", "deny"]);

interface GuardOutput {
  code: number | null;
  stdout: string;
  stderr: string;
  /** 起動できなかったとき（PATH に無い、時間切れ、など）の理由。 */
  failedToStart?: string;
}

/** 拡張としての判定。block のときだけ bash を止める。 */
export interface Verdict {
  block: boolean;
  /** block なら拒否の理由、warning なら通したうえで見せる警告。 */
  message: string;
  warning: boolean;
}

function runGuard(command: string, cwd: string, environ: NodeJS.ProcessEnv): Promise<GuardOutput> {
  return new Promise((resolve) => {
    const child = spawn(GUARD_BIN, ["check", "--cwd", cwd, "--", command], {
      cwd,
      env: environ,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    let settled = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const finish = (output: GuardOutput) => {
      if (settled) return;
      settled = true;
      if (timer !== undefined) clearTimeout(timer);
      resolve(output);
    };
    timer = setTimeout(() => {
      child.kill("SIGKILL");
      finish({ code: null, stdout, stderr, failedToStart: `${TIMEOUT_MS}ms 以内に終わらない` });
    }, TIMEOUT_MS);
    child.stdout.on("data", (chunk: Buffer) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk: Buffer) => {
      stderr += chunk.toString();
    });
    child.on("error", (error: Error) => {
      finish({ code: null, stdout, stderr, failedToStart: error.message });
    });
    child.on("close", (code) => {
      finish({ code, stdout, stderr });
    });
  });
}

// 判定の種類の行を落として、理由の本文だけにする。
function verdictBody(text: string): string {
  const lines = text.trim().split("\n");
  const first = (lines[0] ?? "").trim();
  return (VERDICT_WORDS.has(first) ? lines.slice(1) : lines).join("\n").trim();
}

function oneLine(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

function warn(message: string): Verdict {
  const text = oneLine(message);
  const prefixed = text.startsWith("upstream-guard") ? text : `upstream-guard（警告）: ${text}`;
  return { block: false, warning: true, message: prefixed };
}

/** このセッションで判定するか。オーナーの対話と、緊急時の停止を除く。 */
export function enabled(environ: NodeJS.ProcessEnv): boolean {
  if (!environ[SESSION_ENV]) return false;
  const flag = (environ[DISABLE_ENV] ?? "").trim().toLowerCase();
  return flag === "" || flag === "0" || flag === "false";
}

/** コマンドを判定する。拡張の内部エラーで止めないため、例外は投げない。 */
export async function judge(
  command: string,
  cwd: string,
  environ: NodeJS.ProcessEnv,
): Promise<Verdict> {
  const output = await runGuard(command, cwd, environ);
  if (output.failedToStart !== undefined) {
    return warn(
      "upstream-guard（警告）: 実行ファイルを起動できないため、このコマンドのマージと push の判定をしていません。コマンドは止めていません。副元帥へ知らせてください。",
    );
  }
  const detail = verdictBody(output.stdout) || output.stderr.trim();
  if (output.code === 2) {
    return {
      block: true,
      warning: false,
      message: detail || "upstream-guard: 禁止の宛先へのマージか push を止めました。",
    };
  }
  if (output.code !== 0) {
    return warn(
      `upstream-guard（警告）: 判定が終了コード ${output.code ?? "不明"} で失敗したため、このコマンドのマージと push の判定をしていません。コマンドは止めていません。副元帥へ知らせてください。`,
    );
  }
  // 終了コード 0 でも、宛先を決められなかったときは警告（warn）が返る。通すが文面は見せる。
  return detail ? warn(detail) : { block: false, warning: false, message: "" };
}

function shellCommand(event: { toolName: string; input?: unknown }): string | null {
  if (event.toolName !== "bash" && event.toolName !== "powershell") return null;
  const input = event.input as { command?: unknown } | undefined;
  return typeof input?.command === "string" ? input.command : null;
}

export default function upstreamGuard(pi: ExtensionAPI): void {
  const pendingWarnings = new Map<string, string>();

  const remember = (toolCallId: string, message: string) => {
    if (pendingWarnings.size >= MAX_PENDING_WARNINGS) {
      const oldest = pendingWarnings.keys().next();
      if (!oldest.done) pendingWarnings.delete(oldest.value);
    }
    pendingWarnings.set(toolCallId, message);
  };

  pi.on("session_start", async (_event, ctx) => {
    if (!enabled(process.env)) return;
    try {
      ctx.ui.notify(
        "upstream-guard: 禁止の宛先（nrslib など）へのマージと push を実行前に止めます",
        "info",
      );
    } catch {
      // 表示の失敗でセッションを止めない
    }
  });

  pi.on("tool_call", async (event, ctx) => {
    const command = shellCommand(event);
    if (command === null || !enabled(process.env)) return undefined;
    try {
      const verdict = await judge(command, ctx.cwd, process.env);
      if (verdict.block) return { block: true, reason: verdict.message };
      if (verdict.warning) {
        remember(event.toolCallId, verdict.message);
        try {
          ctx.ui.notify(verdict.message, "warning");
        } catch {
          // 表示の失敗でコマンドを止めない
        }
      }
    } catch {
      // 拡張の内部エラーで全ボットの bash を止めない
      return undefined;
    }
    return undefined;
  });

  // 通したコマンドの警告を、そのツール結果の本文にも足してモデルへ渡す。
  pi.on("tool_result", async (event) => {
    const message = pendingWarnings.get(event.toolCallId);
    if (message === undefined) return undefined;
    pendingWarnings.delete(event.toolCallId);
    return { content: [...event.content, { type: "text" as const, text: message }] };
  });
}
