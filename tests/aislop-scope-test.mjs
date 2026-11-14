import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { basename, extname, join } from "node:path";

const repoRoot = new URL("..", import.meta.url).pathname;

const readJson = (relativePath) => JSON.parse(readFileSync(join(repoRoot, relativePath), "utf8"));

const listFiles = (relativeDir) =>
  readdirSync(join(repoRoot, relativeDir), { withFileTypes: true, recursive: true })
    .filter((entry) => entry.isFile())
    .map((entry) => join(entry.parentPath, entry.name));

const forbidden = [
  "scripts/check-aislop.mjs",
  "tests/check-aislop-test.sh",
  "tests/aislop-check-test.sh",
  ".aislop/ci-baseline.json",
  ".aislop/baseline.json",
];

test("ゲート用のチェックスクリプトと aislop の baseline を持たない", () => {
  for (const relativePath of forbidden) {
    assert.throws(
      () => readFileSync(join(repoRoot, relativePath)),
      undefined,
      `${relativePath} は存在しない`,
    );
  }
});

test("package.json の devDependencies は aislop を固定版で宣言する", () => {
  const { devDependencies } = readJson("package.json");
  assert.equal(devDependencies.aislop, "0.20.1");
});

test("package.json の scripts に check:aislop を足していない", () => {
  const { scripts } = readJson("package.json");
  assert.ok(!("check:aislop" in scripts));
});

test("package-lock.json は lockfileVersion 3 で aislop 0.20.1 を記録する", () => {
  const lock = readJson("package-lock.json");
  assert.equal(lock.lockfileVersion, 3);
  assert.equal(lock.packages[""].devDependencies.aislop, "0.20.1");
  assert.equal(lock.packages["node_modules/aislop"].version, "0.20.1");
  assert.equal(lock.packages["node_modules/aislop"].dev, true);
});

test("Makefile の done は aislop のターゲットを含まない", () => {
  const makefile = readFileSync(join(repoRoot, "Makefile"), "utf8");
  assert.ok(!/^aislop-check:/m.test(makefile));
  assert.ok(!/aislop/i.test(makefile));
});

test("CI のワークフローは aislop の step を含まない", () => {
  for (const filePath of listFiles(".github/workflows")) {
    if (extname(filePath) !== ".yml" && extname(filePath) !== ".yaml") continue;
    const content = readFileSync(filePath, "utf8");
    assert.ok(!/aislop/i.test(content), `${basename(filePath)} は aislop を含まない`);
  }
});

test("mise.toml は aislop を持たない", () => {
  const content = readFileSync(join(repoRoot, "config/mise/mise.toml"), "utf8");
  assert.ok(!/aislop/i.test(content));
});
