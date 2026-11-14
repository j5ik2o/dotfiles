import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { isExcluded, judgedOnly, readAccepted, reconcile } from "./aislop-fixture.mjs";

const repoRoot = new URL("..", import.meta.url).pathname;
const aislopBin = join(repoRoot, "node_modules/.bin/aislop");

const runScan = (excludeArgs) => {
  const result = spawnSync(aislopBin, ["scan", "--json", ...excludeArgs], {
    cwd: repoRoot,
    encoding: "utf8",
    env: {
      ...process.env,
      AISLOP_NO_TELEMETRY: "1",
      AISLOP_NO_UPDATE_NOTIFIER: "1",
    },
    maxBuffer: 64 * 1024 * 1024,
  });
  assert.equal(result.error, undefined, "aislop を起動できる");
  const status = result.status ?? (result.signal ? 128 : 1);
  assert.ok(status === 0 || status === 1, `aislop の終了コードは 0 か 1: ${result.stderr.slice(0, 500)}`);
  return JSON.parse(result.stdout);
};

const excludedScan = () =>
  runScan(["--exclude", ".codex-corporate/", "--exclude", ".codex-personal/", "--exclude", "references/"]);

test("npm ci の依存で aislop 0.20.1 の scan が JSON を返す", () => {
  const output = excludedScan();
  const version = JSON.parse(readFileSync(join(repoRoot, "node_modules/aislop/package.json"), "utf8"));
  assert.equal(version.version, "0.20.1");
  assert.equal(output.cliVersion, "0.20.1");
  assert.ok(Array.isArray(output.diagnostics));
});

test("scan の error と warning は 4キーと件数で受け入れ一覧と一致する", () => {
  const output = excludedScan();
  const { missing, mismatched, extra } = reconcile(judgedOnly(output.diagnostics), readAccepted(repoRoot).accepted);
  assert.deepEqual(missing, []);
  assert.deepEqual(mismatched, []);
  assert.deepEqual(extra, []);
});

test("除外ありの scan 出力には取り込み済み 3 ディレクトリの指摘が出ない", () => {
  const output = excludedScan();
  const excluded = output.diagnostics.filter((item) => isExcluded(item.filePath));
  assert.deepEqual(excluded, [], "既定の除外で取り込み済みの指摘は出ない");
});

test("除外を外すと同じ filePath の取り込み済み指摘が scan 出力に現れる", () => {
  const output = runScan([]);
  const excluded = output.diagnostics.filter((item) => isExcluded(item.filePath));
  assert.ok(excluded.length > 0, "除外なしの scan には取り込み済みディレクトリの指摘が出る");
  for (const item of excluded) {
    assert.equal(isExcluded(item.filePath), true, item.filePath);
  }
});
