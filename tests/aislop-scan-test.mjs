import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import { compareCounts, isExcluded, readAccepted } from "./aislop-fixture.mjs";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const aislopCli = join(repoRoot, "node_modules/aislop/dist/cli.js");
const hasAislop = existsSync(aislopCli);

// 正本 check-aislop.mjs と同じく AISLOP_NO_TELEMETRY/AISLOP_NO_UPDATE_NOTIFIER を渡す。
const aislopEnv = {
  ...process.env,
  AISLOP_NO_TELEMETRY: "1",
  AISLOP_NO_UPDATE_NOTIFIER: "1",
};

// 検査は package.json の check:aislop と同じく devShell の中で走らせる。
// aislop の format/lint エンジンは呼び出し元 PATH の ruff の有無で結果を変えるため、
// scan と bootstrap の起動環境を devShell に固定し、テストの観測も採用環境へ揃える。
const runInDevShell = (args, options = {}) =>
  spawnSync("nix", ["develop", "--command", process.execPath, ...args], {
    cwd: repoRoot,
    encoding: "utf8",
    env: { ...aislopEnv },
    maxBuffer: 64 * 1024 * 1024,
    ...options,
  });

const runBareScan = () => {
  const result = runInDevShell([aislopCli, "scan", "--json"]);
  assert.equal(result.error, undefined, "aislop を起動できる");
  const status = result.status ?? (result.signal ? 128 : 1);
  assert.ok(status === 0 || status === 1, `aislop の終了コードは 0 か 1: ${result.stderr.slice(0, 500)}`);
  return JSON.parse(result.stdout);
};

const runBootstrap = (mode) =>
  runInDevShell([join(repoRoot, "scripts/aislop-check-bootstrap.mjs"), mode], {
    timeout: 120_000,
  });

test("除外は .aislop/config.yml から読み、scan に --exclude を付けない", { skip: !hasAislop }, () => {
  const output = runBareScan();
  assert.equal(output.cliVersion, "0.20.1");
  assert.ok(Array.isArray(output.diagnostics));
  const leaked = output.diagnostics.filter((item) => isExcluded(item.filePath));
  assert.deepEqual(leaked, [], "config.yml の除外で取り込み済みの指摘は出ない");
});

test("通常 scan は error と warning が受け入れ一覧と一致する", { skip: !hasAislop }, () => {
  const output = runBareScan();
  const { unlisted, resolved } = compareCounts(readAccepted(repoRoot), output.diagnostics);
  assert.deepEqual(unlisted, [], "一覧に無い warn 以上の指摘は無い");
  assert.deepEqual(resolved, [], "一覧にあるが出ない指摘は無い");
});

test("scan の対象ファイルは 1 件以上ある", { skip: !hasAislop }, () => {
  const output = runBareScan();
  const count =
    typeof output.coverage?.supportedFiles === "number"
      ? output.coverage.supportedFiles
      : output.summary?.files;
  assert.ok(Number.isInteger(count) && count > 0, `対象ファイル数は 1 以上: ${count}`);
});

test("bootstrap の check は受け入れ一覧と一致して終了コード 0 になる", { skip: !hasAislop }, () => {
  const result = runBootstrap("check");
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
  assert.match(result.stdout, /一致します/);
});

test("bootstrap の test は正本のテストを回して通る", { skip: !hasAislop }, () => {
  const result = runBootstrap("test");
  assert.equal(result.status, 0, `${result.stdout.slice(-2000)}\n${result.stderr.slice(-2000)}`);
});
