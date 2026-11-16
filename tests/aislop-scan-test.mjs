import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  RUN_TIMEOUT_MS,
  TREE_KILL_GRACE_MS,
  childTimeoutMs,
} from "../scripts/aislop-check-bootstrap.mjs";
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
// 期限は nix develop の起動と、外側の期限で起動役を終了させた後の後始末にも及ぶ。
const runInDevShell = (args, options = {}) =>
  spawnSync("nix", ["develop", "--command", process.execPath, ...args], {
    cwd: repoRoot,
    encoding: "utf8",
    env: { ...aislopEnv },
    maxBuffer: 64 * 1024 * 1024,
    ...options,
  });

// 起動役の全体予算（RUN_TIMEOUT_MS）と猶予の後に外側の期限を切るための余裕。
// 起動役は予算を超えるとプロセスツリーを猶予の間だけ待ってから終了し、その後に
// nix develop を経た終了が spawnSync へ返るので、外側の期限が予算 + 猶予より後でないと、
// 正本の取得と scan が重なったときに外側が先に切れて成功アサーションが失敗する。
// 期限は、正本の scan 600 秒 < 起動役の全体予算（RUN_TIMEOUT_MS、既定 660 秒）<
// 予算 + 猶予 < 外部の期限、の順に読める。
const BOOTSTRAP_DEADLINE_SLACK_MS = 30_000;

const bootstrapDeadlineMs = (env) =>
  childTimeoutMs(env) + TREE_KILL_GRACE_MS + BOOTSTRAP_DEADLINE_SLACK_MS;

// 期限切れは spawnSync が error に残し、status を 1 にするため、status の確認だけでは
// bootstrap 自身の失敗と区別できない。外側の期限が原因の失敗（ETIMEDOUT）だけを、
// 起動役の終了コードの代わりの status 1 と取り違えないよう、理由付きで落とす。
// 起動役自身が制限時間で終了した場合は通常の終了として status を検証する。
const failOnDeadlineExpiry = (result) => {
  if (result.error?.code === "ETIMEDOUT") {
    assert.fail(`起動役の期限を超えて終了しました: ${JSON.stringify(result.error.message)}`);
  }
  return result;
};

const runBareScan = () => {
  const result = runInDevShell([aislopCli, "scan", "--json"]);
  assert.equal(result.error, undefined, "aislop を起動できる");
  const status = result.status ?? (result.signal ? 128 : 1);
  assert.ok(status === 0 || status === 1, `aislop の終了コードは 0 か 1: ${result.stderr.slice(0, 500)}`);
  return JSON.parse(result.stdout);
};

const runBootstrap = (mode, { env } = {}) => {
  const childEnv = { ...aislopEnv, ...env };
  return runInDevShell([join(repoRoot, "scripts/aislop-check-bootstrap.mjs"), mode], {
    env: childEnv,
    timeout: bootstrapDeadlineMs(childEnv),
  });
};

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
  const result = failOnDeadlineExpiry(runBootstrap("check"));
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
  assert.match(result.stdout, /一致します/);
});

test("bootstrap の test は正本のテストを回して通る", { skip: !hasAislop }, () => {
  const result = failOnDeadlineExpiry(runBootstrap("test"));
  assert.equal(result.status, 0, `${result.stdout.slice(-2000)}\n${result.stderr.slice(-2000)}`);
});

test("外側の期限が切れた実行は ETIMEDOUT として失敗させる", () => {
  const expired = {
    error: { code: "ETIMEDOUT", message: "spawnSync nix ETIMEDOUT" },
    status: 1,
    stdout: "",
    stderr: "",
  };
  assert.throws(() => failOnDeadlineExpiry(expired), /起動役の期限を超えて終了しました/);
});

test("期限切れ以外の異常終了は従来どおり status で扱う", () => {
  const result = { error: undefined, status: 1, stdout: "", stderr: "失敗" };
  assert.equal(failOnDeadlineExpiry(result), result);
});

// 期限の期待値は、親プロセスの AISLOP_CHECK_RUN_TIMEOUT_MS に依存させない。
// 親の環境で予算が変わっていると、既定値を確かめるテストが誤って落ちるため、
// 既定値は空の環境の入力で計算し、予算を変えた場合も差だけを比べる。
const defaultDeadlineMs = () => bootstrapDeadlineMs({});

test("bootstrap の外側の期限は起動役の全体予算と猶予より後になる", () => {
  const deadline = defaultDeadlineMs();
  assert.ok(
    deadline > RUN_TIMEOUT_MS + TREE_KILL_GRACE_MS,
    `${deadline} は ${RUN_TIMEOUT_MS} + ${TREE_KILL_GRACE_MS} より後`,
  );
});

test("AISLOP_CHECK_RUN_TIMEOUT_MS で予算を変えると外側の期限も追随する", () => {
  const budget = RUN_TIMEOUT_MS / 2;
  const deadline = bootstrapDeadlineMs({ AISLOP_CHECK_RUN_TIMEOUT_MS: String(budget) });
  assert.equal(deadline, defaultDeadlineMs() - (RUN_TIMEOUT_MS - budget));
  assert.ok(
    deadline > budget + TREE_KILL_GRACE_MS,
    `${deadline} は ${budget} + ${TREE_KILL_GRACE_MS} より後`,
  );
});
