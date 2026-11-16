import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  assertCacheDirOutsideRoot,
  cacheRootDir,
} from "../scripts/aislop-check-bootstrap.mjs";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));

const withTempDir = (run) => {
  const dir = mkdtempSync(join(tmpdir(), "aislop-cache-test-"));
  try {
    return run(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
};

test("AISLOP_CHECK_CACHE_DIR を指定すると、その配下の aislop-check ではなく指定先をそのまま返す", () => {
  withTempDir((dir) => {
    const cacheDir = join(dir, "custom");
    const root = cacheRootDir({ AISLOP_CHECK_CACHE_DIR: cacheDir });
    assert.equal(root, resolve(cacheDir));
  });
});

test("AISLOP_CHECK_CACHE_DIR に相対パスを渡すと、作業ディレクトリ基準の絶対パスへ解決する", () => {
  const relative = "relative/cache-dir";
  const root = cacheRootDir({ AISLOP_CHECK_CACHE_DIR: relative });
  assert.equal(root, resolve(relative));
  assert.ok(root.startsWith("/") || /^[A-Za-z]:[\\/]/.test(root), `${root} は絶対パス`);
});

test("AISLOP_CHECK_CACHE_DIR が無ければ XDG_CACHE_HOME 配下の aislop-check を使う", () => {
  withTempDir((dir) => {
    const root = cacheRootDir({ XDG_CACHE_HOME: dir });
    assert.equal(root, resolve(dir, "aislop-check"));
  });
});

test("リポジトリ内を指すキャッシュの置き場所は書き込みの前に理由付きで拒否する", () => {
  const inside = join(repoRoot, "node_modules", ".aislop-check", "aislop-check-v5");
  assert.throws(
    () => assertCacheDirOutsideRoot(inside, repoRoot),
    /リポジトリの中になっています/,
    "リポジトリ内の置き場所は拒否する",
  );
});

test("リポジトリ直下そのものを指す置き場所も拒否する", () => {
  assert.throws(
    () => assertCacheDirOutsideRoot(repoRoot, repoRoot),
    /リポジトリの中になっています/,
  );
});

test("リポジトリの外を指す置き場所は受け入れる", () => {
  withTempDir((dir) => {
    assert.doesNotThrow(() => assertCacheDirOutsideRoot(join(dir, "aislop-check-v5"), repoRoot));
  });
});
