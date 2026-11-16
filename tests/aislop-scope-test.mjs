import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  CONFIG_PATH,
  EXCLUDED_ROOTS,
  PIN_PATH,
  readAccepted,
  readPin,
} from "./aislop-fixture.mjs";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));

const readJson = (relativePath) => JSON.parse(readFileSync(join(repoRoot, relativePath), "utf8"));
const readText = (relativePath) => readFileSync(join(repoRoot, relativePath), "utf8");

// j5ik2o/ci aislop/bootstrap.mjs（aislop-check-v5）の SHA-256。AC1 の固定値。
const CANONICAL_BOOTSTRAP_SHA256 =
  "58a6946d3eb48733e8e2536ef0c5b9a91545c5fac5dd5a87114cc982b49c4ae5";

// j5ik2o/ci aislop/ の ref と2ファイルの SHA-256。AC2 の固定値。
const CANONICAL_REF = "aislop-check-v5";
const CANONICAL_FILES = {
  "check-aislop.mjs": "c53e1b91dd45ead4bfdfd3dc4bbec794e2fd81b96857a90f7c5aaea414f8e30c",
  "check-aislop.test.mjs": "95dda876c46cea1ca3be454d82be31080ecf9ff1f387d0a06ea014e5bc1c9130",
};

const forbidden = [
  "scripts/check-aislop.mjs",
  "scripts/aislop-check.mjs",
  "tests/check-aislop-test.sh",
  "tests/aislop-check-test.sh",
  ".aislop/ci-baseline.json",
  ".aislop/baseline.json",
];

test("検査本体をリポジトリに持たず、aislop の baseline も持たない", () => {
  for (const relativePath of forbidden) {
    assert.throws(
      () => readFileSync(join(repoRoot, relativePath)),
      undefined,
      `${relativePath} は存在しない`,
    );
  }
});

test("起動役の写しは j5ik2o/ci の bootstrap.mjs と無編集で一致する", () => {
  const buffer = readFileSync(join(repoRoot, "scripts/aislop-check-bootstrap.mjs"));
  const digest = createHash("sha256").update(buffer).digest("hex");
  assert.equal(digest, CANONICAL_BOOTSTRAP_SHA256, "脚本は正本とバイト一致する");
});

test("pin は ref と正本2ファイルのハッシュを固定する", () => {
  const pin = readPin(repoRoot);
  assert.equal(pin.ref, CANONICAL_REF);
  assert.equal(typeof pin.files, "object");
  assert.deepEqual(pin.files, CANONICAL_FILES);
});

test("pin は bootstrap が読む形（ref 文字列と files オブジェクト）を持つ", () => {
  const raw = readJson(PIN_PATH);
  assert.equal(typeof raw.ref, "string");
  assert.ok(raw.ref.length > 0);
  assert.equal(typeof raw.files, "object");
  assert.ok(raw.files !== null);
});

test("受け入れ一覧の engines は実測に現れるエンジンで、architecture を含まない", () => {
  const document = readAccepted(repoRoot);
  assert.ok(Array.isArray(document.engines) && document.engines.length > 0);
  for (const name of ["ai-slop", "code-quality"]) {
    assert.ok(document.engines.includes(name), `${name} を挙げている`);
  }
  assert.ok(!document.engines.includes("architecture"), "記録の無い architecture を挙げない");
});

test("missingToolsAllowed は ruff の未導入理由を持つ", () => {
  const document = readAccepted(repoRoot);
  assert.equal(typeof document.missingToolsAllowed, "object");
  assert.ok(document.missingToolsAllowed !== null);
  assert.ok("ruff" in document.missingToolsAllowed, "ruff の欠落理由がある");
  assert.match(document.missingToolsAllowed.ruff, /\S/);
});

test("除外は取り込み済みの 3 ディレクトリだけを .aislop/config.yml に書く", () => {
  const config = readText(CONFIG_PATH);
  const listed = [...config.matchAll(/^\s*-\s+(\S+)\s*$/gm)].map((match) => match[1]);
  assert.deepEqual(listed.sort(), [...EXCLUDED_ROOTS].sort());
});

test("除外範囲は lint/vendored-paths.txt の root: と一致する", () => {
  const manifest = readText("lint/vendored-paths.txt");
  const roots = manifest
    .split("\n")
    .filter((line) => line.startsWith("root: "))
    .map((line) => line.slice("root: ".length).trim());
  assert.deepEqual(roots.sort(), [...EXCLUDED_ROOTS].sort());
  assert.ok(!roots.includes("packages/"), "packages/ は一括除外しない");
});

test("package.json の devDependencies は aislop を固定版で宣言する", () => {
  const { devDependencies } = readJson("package.json");
  assert.equal(devDependencies.aislop, "0.20.1");
});

test("package.json の scripts は check:aislop と test:aislop を bootstrap 経由で定義する", () => {
  const { scripts } = readJson("package.json");
  assert.equal(
    scripts["check:aislop"],
    "nix develop --command node scripts/aislop-check-bootstrap.mjs check",
  );
  assert.equal(scripts["test:aislop"], "node scripts/aislop-check-bootstrap.mjs test");
});

test("package-lock.json は lockfileVersion 3 で aislop 0.20.1 を記録する", () => {
  const lock = readJson("package-lock.json");
  assert.equal(lock.lockfileVersion, 3);
  assert.equal(lock.packages[""].devDependencies.aislop, "0.20.1");
  assert.equal(lock.packages["node_modules/aislop"].version, "0.20.1");
  assert.equal(lock.packages["node_modules/aislop"].dev, true);
});

test("Makefile の done は aislop のターゲットを含む", () => {
  const makefile = readText("Makefile");
  assert.match(makefile, /^aislop-check:/m, "aislop-check ターゲットがある");
  const lines = makefile.split("\n");
  const doneIndex = lines.findIndex((line) => line.startsWith("done:"));
  assert.notEqual(doneIndex, -1, "done ターゲットがある");
  const block = [lines[doneIndex]];
  for (let i = doneIndex + 1; i < lines.length; i += 1) {
    if (!lines[i].startsWith("\t")) break;
    block.push(lines[i]);
  }
  assert.match(block.join("\n"), /aislop-check/, "done の系列に aislop-check がある");
});

test("CI のワークフローは node と npm ci を用意して aislop の step を実行する", () => {
  const workflow = readText(".github/workflows/nix-check.yml");
  assert.match(workflow, /aislop/i, "nix-check.yml は aislop を含む");
  assert.match(workflow, /npm ci/, "npm ci を用意する");
  assert.match(workflow, /check:aislop/, "check:aislop を実行する");
  const hasNode =
    /setup-node/.test(workflow) || /mise-action/.test(workflow) || /nodejs/.test(workflow);
  assert.ok(hasNode, "node を用意する step がある");
});

test("mise.toml 以外から版数を直書きしない", () => {
  const workflow = readText(".github/workflows/nix-check.yml");
  const withVersion = [...workflow.matchAll(/node-version:\s*["']?([^"'\n]+)/g)].map((m) => m[1]);
  for (const version of withVersion) {
    assert.match(version, /mise|file/i, `node の版は config/mise/mise.toml が正本: ${version}`);
  }
});

test("mise.toml は aislop を持たない", () => {
  const content = readText("config/mise/mise.toml");
  assert.ok(!/aislop/i.test(content));
});
