// config/pi/agent/extensions/upstream-guard.ts の振る舞いを固定する。
//
// 判定そのものは scripts/upstream_guard.py（tests/upstream_guard_test.py が見る）に任せ、
// ここでは拡張との受け渡しだけを見る: 拒否（終了コード 2）で止まる、終了コード 0 の警告は
// 通して見せる、実行ファイルが無い・想定外の終了コードのときは通して 1 行だけ警告する。
//
// 本物の禁止の宛先へは、どんな形でも触らない。判定に渡すのは文字列だけ。
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import upstreamGuard, { enabled, judge } from "../config/pi/agent/extensions/upstream-guard.ts";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const guardScript = join(repoRoot, "scripts", "upstream_guard.py");
const python = process.env.PYTHON ?? "python3";

// 本物の判定を PATH から呼ぶ包み。拡張は upstream-guard を名前で spawn する。
const realGuard = `#!/bin/sh\nexec ${python} "${guardScript}" "$@"\n`;

function installGuard(bin, body) {
  const file = join(bin, "upstream-guard");
  writeFileSync(file, body);
  chmodSync(file, 0o755);
}

function sandbox(body = realGuard) {
  const root = mkdtempSync(join(tmpdir(), "pi-upstream-guard-"));
  const bin = join(root, "bin");
  const home = join(root, "home");
  const empty = join(root, "empty");
  for (const dir of [bin, home, empty]) mkdirSync(dir, { recursive: true });
  installGuard(bin, body);
  return { root, bin, home, empty };
}

// HOME を砂箱へ向けて、手元の ~/.gitconfig と ~/.config/upstream-guard を読ませない。
function environment(box, overrides = {}) {
  return {
    PATH: `${box.bin}${delimiter}/usr/bin:/bin`,
    HOME: box.home,
    ORCA_AGENT_SESSION_ID: "test-session",
    ...overrides,
  };
}

// takt の実物と同じ形の remote を持つ使い捨てのリポジトリ（origin は自分、upstream は上流で push は DISABLED）。
function taktLikeRepo(box) {
  const dir = join(box.root, "takt");
  mkdirSync(dir, { recursive: true });
  const git = (...args) =>
    execFileSync("git", ["-C", dir, ...args], {
      stdio: "ignore",
      env: { ...process.env, HOME: box.home },
    });
  git("init", "-q", "-b", "main");
  git("remote", "add", "origin", "https://github.com/j5ik2o/takt");
  git("remote", "add", "upstream", "https://github.com/nrslib/takt.git");
  git("remote", "set-url", "--push", "upstream", "DISABLED");
  git("config", "remote.pushDefault", "origin");
  return dir;
}

// 非同期の run を待ってから戻す。待たずに戻すと、最初の await で環境が元に戻り、
// 2 回目以降の呼び出しが砂箱の外（本物の PATH や環境変数）で走ってしまう。
async function withEnv(vars, run) {
  const saved = new Map();
  for (const [key, value] of Object.entries(vars)) {
    saved.set(key, process.env[key]);
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  try {
    return await run();
  } finally {
    for (const [key, value] of saved) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

function fakePi() {
  const handlers = new Map();
  return { handlers, on: (name, handler) => handlers.set(name, handler) };
}

test("拒否: 禁止の宛先へのマージは止まる", async () => {
  const box = sandbox();
  const verdict = await judge(
    "gh pr merge 2101 -R nrslib/takt --merge",
    box.root,
    environment(box),
  );
  assert.equal(verdict.block, true, "止める");
  assert.match(verdict.message, /upstream-guard/, "ガードの文面を渡す");
  assert.equal(verdict.warning, false);
});

test("拒否: takt の手元からの上流への push は止まる", async () => {
  const box = sandbox();
  const cwd = taktLikeRepo(box);
  const verdict = await judge("git push upstream main", cwd, environment(box));
  assert.equal(verdict.block, true, "止める");
  assert.match(verdict.message, /上流/, "理由を渡す");
});

test("許可: 自分宛てのマージ・push・読み取りは通る", async () => {
  const box = sandbox();
  const cwd = taktLikeRepo(box);
  const env = environment(box);
  for (const command of [
    "gh pr merge 2101 -R j5ik2o/takt --merge",
    "git push origin HEAD",
    "ls -la",
  ]) {
    const verdict = await judge(command, cwd, env);
    assert.equal(verdict.block, false, `${command} は通す`);
    assert.equal(verdict.warning, false, `${command} は警告を出さない`);
  }
});

// 宛先が変数で決まる push。git のリポジトリでない場所でも、判定できないことが確実に決まる。
const undecidable = "git push $R main";

test("許可＋警告: 宛先を決められない push は通して警告する", async () => {
  const box = sandbox();
  const verdict = await judge(undecidable, box.empty, environment(box));
  assert.equal(verdict.block, false, "止めない");
  assert.equal(verdict.warning, true, "警告を出す");
  assert.match(verdict.message, /upstream-guard/, "ガードの警告を渡す");
});

test("実行ファイルが PATH に無いときは通して 1 行だけ警告する", async () => {
  const box = sandbox();
  const env = environment(box, { PATH: box.empty });
  const verdict = await judge("gh pr merge 2101 -R nrslib/takt --merge", box.root, env);
  assert.equal(verdict.block, false, "止めない");
  assert.equal(verdict.warning, true, "警告を出す");
  assert.equal(verdict.message.split("\n").length, 1, "1 行");
});

test("想定外の終了コードは通して警告する", async () => {
  const box = sandbox("#!/bin/sh\nexit 3\n");
  const verdict = await judge("ls -la", box.root, environment(box));
  assert.equal(verdict.block, false, "止めない");
  assert.equal(verdict.warning, true, "警告を出す");
  assert.match(verdict.message, /終了コード 3/, "終了コードを伝える");
});

test("判定するのは Orca のセッションだけで、緊急時は環境変数で切れる", () => {
  assert.equal(enabled({}), false, "ORCA_AGENT_SESSION_ID が無ければ判定しない");
  assert.equal(enabled({ ORCA_AGENT_SESSION_ID: "s" }), true);
  assert.equal(
    enabled({ ORCA_AGENT_SESSION_ID: "s", PI_UPSTREAM_GUARD_DISABLED: "1" }),
    false,
    "PI_UPSTREAM_GUARD_DISABLED=1 で切れる",
  );
  assert.equal(
    enabled({ ORCA_AGENT_SESSION_ID: "s", PI_UPSTREAM_GUARD_DISABLED: "0" }),
    true,
    "0 は切らない",
  );
});

test("Pi の結線: 拒否は block を返し、警告は通して結果の本文へ足す", async () => {
  const box = sandbox();
  await withEnv(
    {
      PATH: environment(box).PATH,
      HOME: box.home,
      ORCA_AGENT_SESSION_ID: "test-session",
      PI_UPSTREAM_GUARD_DISABLED: undefined,
    },
    async () => {
      const pi = fakePi();
      upstreamGuard(pi);
      const notices = [];
      const ctx = { cwd: box.empty, ui: { notify: (text, level) => notices.push({ text, level }) } };
      const toolCall = pi.handlers.get("tool_call");

      const denied = await toolCall(
        {
          toolName: "bash",
          toolCallId: "call-1",
          input: { command: "gh pr merge 2101 -R nrslib/takt --merge" },
        },
        ctx,
      );
      assert.equal(denied.block, true, "拒否は block");
      assert.match(denied.reason, /upstream-guard/);

      const warned = await toolCall(
        { toolName: "bash", toolCallId: "call-2", input: { command: undecidable } },
        ctx,
      );
      assert.equal(warned, undefined, "警告では止めない");
      assert.equal(notices.length, 1, "TUI へ 1 件出す");
      assert.equal(notices[0].level, "warning");

      const patched = await pi.handlers.get("tool_result")({
        toolName: "bash",
        toolCallId: "call-2",
        input: { command: undecidable },
        content: [{ type: "text", text: "output" }],
        isError: false,
      });
      assert.equal(patched.content.length, 2, "警告を本文へ足す");
      assert.match(patched.content[1].text, /upstream-guard/);

      const other = await pi.handlers.get("tool_result")({
        toolName: "read",
        toolCallId: "call-3",
        input: { path: "README.md" },
        content: [],
        isError: false,
      });
      assert.equal(other, undefined, "警告の無い呼び出しには触らない");
    },
  );
});

test("Pi の結線: 拡張を切るときと bash 以外は判定しない", async () => {
  const box = sandbox();
  await withEnv(
    {
      PATH: environment(box).PATH,
      HOME: box.home,
      ORCA_AGENT_SESSION_ID: "test-session",
      PI_UPSTREAM_GUARD_DISABLED: "1",
    },
    async () => {
      const pi = fakePi();
      upstreamGuard(pi);
      const ctx = { cwd: box.empty, ui: { notify: () => {} } };
      const denied = await pi.handlers.get("tool_call")(
        {
          toolName: "bash",
          toolCallId: "call-1",
          input: { command: "gh pr merge 2101 -R nrslib/takt --merge" },
        },
        ctx,
      );
      assert.equal(denied, undefined, "PI_UPSTREAM_GUARD_DISABLED=1 では止めない");

      await withEnv({ PI_UPSTREAM_GUARD_DISABLED: "0" }, async () => {
        const ignored = await pi.handlers.get("tool_call")(
          { toolName: "read", toolCallId: "call-2", input: { path: "README.md" } },
          ctx,
        );
        assert.equal(ignored, undefined, "bash 以外は見ない");
      });
    },
  );
});
