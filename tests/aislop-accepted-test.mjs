import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";

import {
  REQUIRED_KEYS,
  acceptedIndex,
  acceptedKeys,
  acceptanceOf,
  finding,
  groupFindings,
  isExcluded,
  judgedOnly,
  readAccepted,
  reconcile,
} from "./aislop-fixture.mjs";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const accepted = () => readAccepted(repoRoot).accepted;

const expand = (entries) =>
  entries.flatMap((entry) => Array.from({ length: entry.count }, () => ({ ...entry })));

test("受け入れ一覧は scripts/aislop-accepted.json に存在する", () => {
  const document = readAccepted(repoRoot);
  assert.ok(Array.isArray(document.accepted), "accepted 配列を持つ");
  assert.ok(document.accepted.length > 0, "accepted 配列は空でない");
});

test("受け入れ一覧の各エントリは engine/rule/filePath/message と件数と理由だけを持つ", () => {
  for (const entry of accepted()) {
    assert.deepEqual(Object.keys(entry).sort(), acceptedKeys.slice().sort());
  }
});

test("受け入れ一覧の各エントリは件数が正の整数で理由が空でない", () => {
  for (const entry of accepted()) {
    assert.ok(Number.isInteger(entry.count) && entry.count > 0, `${entry.filePath} の count`);
    assert.equal(typeof entry.reason, "string");
    assert.ok(entry.reason.trim().length > 0, `${entry.filePath} の reason`);
  }
});

test("受け入れ一覧の各エントリは 4キーの文字列を持ち、4キーが重複しない", () => {
  for (const entry of accepted()) {
    for (const key of REQUIRED_KEYS) {
      assert.equal(typeof entry[key], "string");
      assert.ok(entry[key].length > 0, `${entry.filePath} の ${key}`);
    }
  }
  const entries = accepted();
  assert.equal(acceptedIndex(entries).size, entries.length);
});

test("受け入れ一覧は aislop の baseline を持たない", () => {
  const document = readAccepted(repoRoot);
  assert.ok(!("baseline" in document) && !("version" in document) && !("entries" in document));
});

test("受け入れ一覧は連携先モジュールを設計理由つきで登録している", () => {
  const entries = accepted().filter(
    (entry) =>
      entry.rule === "ai-slop/hallucinated-import" &&
      (entry.filePath === "packages/dsh-tui-login.mjs" ||
        entry.filePath === "packages/dsh-tui-models.mjs"),
  );
  assert.ok(entries.length > 0);
  for (const entry of entries) {
    assert.match(entry.reason, /dsh|pi/);
    assert.match(entry.reason, /実行時/);
  }
});

test("受け入れ一覧の件数を足し合わせると既定の除外での error と warning の件数になる", () => {
  const total = accepted().reduce((sum, entry) => sum + entry.count, 0);
  assert.equal(total, 28);
});

test("受け入れ一覧が scan 出力をそのまま受理する", () => {
  const entries = accepted();
  const { missing, mismatched, extra } = reconcile(expand(entries), entries);
  assert.deepEqual(missing, []);
  assert.deepEqual(mismatched, []);
  assert.deepEqual(extra, []);
});

test("重複した 4キーは件数にまとめ、登録した件数と一致すれば受け入れになる", () => {
  const entries = [{ ...finding(), count: 10, reason: "CLI の出力が仕様" }];
  const findings = expand(entries);
  assert.equal(groupFindings(findings).length, 1);
  assert.equal(groupFindings(findings)[0].count, 10);
  const { missing, mismatched, extra } = reconcile(findings, entries);
  assert.deepEqual(missing, []);
  assert.deepEqual(mismatched, []);
  assert.deepEqual(extra, []);
});

test("登録件数が実際より多いエントリは不一致として拒否する", () => {
  const entries = [{ ...finding(), count: 10, reason: "CLI の出力が仕様" }];
  const findings = expand([{ ...entries[0], count: 9 }]);
  const { missing, mismatched } = reconcile(findings, entries);
  assert.deepEqual(missing, []);
  assert.equal(mismatched.length, 1);
  assert.equal(mismatched[0].entry.count, 10);
  assert.equal(mismatched[0].group.count, 9);
});

test("登録件数が実際より少ないエントリは不一致として拒否する", () => {
  const entries = [{ ...finding(), count: 10, reason: "CLI の出力が仕様" }];
  const findings = expand([{ ...entries[0], count: 11 }]);
  assert.equal(reconcile(findings, entries).mismatched.length, 1);
});

test("行番号だけが違う指摘は同じ 4キーとして受け入れる", () => {
  const seed = {
    engine: "ai-slop",
    rule: "ai-slop/hallucinated-import",
    filePath: "config/pi/agent/extensions/content-guard.ts",
    message: 'Imports "@earendil-works/pi-coding-agent" but it\'s not declared in package.json',
  };
  const entries = [{ ...seed, count: 2, reason: "設計上の理由" }];
  const findings = [
    { ...seed, line: 18 },
    { ...seed, line: 19 },
  ];
  const { missing, mismatched, extra } = reconcile(findings, entries);
  assert.deepEqual(missing, []);
  assert.deepEqual(mismatched, []);
  assert.deepEqual(extra, []);
});

test("受け入れ一覧に無い指摘は missing として拒否する", () => {
  const entries = accepted();
  const unexpected = finding({
    rule: "ai-slop/hallucinated-import",
    filePath: "packages/unexpected.mjs",
    message: 'Imports "left-pad" but it\'s not declared in package.json',
  });
  const { missing, extra } = reconcile([...expand(entries), unexpected], entries);
  assert.equal(missing.length, 1);
  assert.equal(missing[0].filePath, "packages/unexpected.mjs");
  assert.deepEqual(extra, []);
});

test("実際の scan に出ない登録は extra として検出する", () => {
  const entries = accepted();
  const { missing, extra } = reconcile(expand(entries.slice(1)), entries);
  assert.deepEqual(missing, []);
  assert.equal(extra.length, 1);
  assert.equal(extra[0].filePath, entries[0].filePath);
});

test("除外は取り込み済みの 3 ディレクトリだけに一致する", () => {
  const excluded = [
    ".codex-corporate/agents/note.md",
    ".codex-personal/sessions/a.jsonl",
    "references/upstream/readme.md",
  ];
  const notExcluded = [
    "packages/dsh-tui-login.mjs",
    "config/spark/namespace_relay.py",
    "config/pi/agent/extensions/content-guard.ts",
    "references-notice/readme.md",
  ];
  for (const filePath of excluded) {
    assert.equal(isExcluded(filePath), true, filePath);
  }
  for (const filePath of notExcluded) {
    assert.equal(isExcluded(filePath), false, filePath);
  }
});

test("info の指摘は合否判定の対象から外れる", () => {
  const info = finding({ rule: "code-quality/knip/skipped", severity: "info" });
  const error = finding({ rule: "ai-slop/hallucinated-import", severity: "error" });
  const warning = finding({ severity: "warning" });
  const accepted = acceptanceOf([info, error, warning], []);
  assert.deepEqual(
    accepted.map((group) => group.rule).sort(),
    ["ai-slop/console-leftover", "ai-slop/hallucinated-import"],
  );
});

test("severity を持たない診断は合否対象に含めず、error と warning と同じ判定を共有する", () => {
  const withoutSeverity = finding({ rule: "ai-slop/console-leftover" });
  const error = finding({ rule: "ai-slop/hallucinated-import", severity: "error" });
  const info = finding({ rule: "code-quality/knip/skipped", severity: "info" });
  const diagnostics = [withoutSeverity, error, info];
  assert.deepEqual(
    judgedOnly(diagnostics).map((item) => item.rule),
    ["ai-slop/hallucinated-import"],
  );
  assert.deepEqual(
    acceptanceOf(diagnostics, []).map((group) => group.rule),
    ["ai-slop/hallucinated-import"],
  );
});

test("scan の指摘は 4キーと行番号を別々に持つ", () => {
  const item = finding({ line: 42 });
  for (const key of REQUIRED_KEYS) {
    assert.equal(typeof item[key], "string");
  }
  assert.equal(item.line, 42);
});
