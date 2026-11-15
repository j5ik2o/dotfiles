import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";

import {
  FINDING_KEYS,
  acceptedFindings,
  compareCounts,
  finding,
  isExcluded,
  readAccepted,
} from "./aislop-fixture.mjs";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const accepted = () => readAccepted(repoRoot);

const expand = (findings, count) => Array.from({ length: count }, () => ({ ...findings }));

test("受け入れ一覧は scripts/aislop-accepted.json に存在し、accepted 配列を持つ", () => {
  const document = accepted();
  assert.ok(Array.isArray(document.accepted), "accepted 配列を持つ");
  assert.ok(document.accepted.length > 0, "accepted 配列は空でない");
});

test("受け入れ一覧の各群は reason と findings を持ち、件数は 19 群・30 件", () => {
  const document = accepted();
  assert.equal(document.accepted.length, 19, "19 エントリ");
  for (const group of document.accepted) {
    assert.equal(typeof group.reason, "string");
    assert.ok(group.reason.trim().length > 0, `${group.reason} の reason`);
    assert.ok(Array.isArray(group.findings) && group.findings.length > 0);
  }
  assert.equal(acceptedFindings(document).length, 30, "findings の合計は 30 件");
});

test("各 findings は engine/rule/file/message の4キーだけを持ち、空文字を含まない", () => {
  for (const item of acceptedFindings(accepted())) {
    assert.deepEqual(Object.keys(item).sort(), FINDING_KEYS.slice().sort());
    for (const key of FINDING_KEYS) {
      assert.equal(typeof item[key], "string");
      assert.ok(item[key].length > 0, `${key} は空でない`);
    }
  }
});

test("findings のエンジンは engines に挙げたものだけを使う", () => {
  const document = accepted();
  for (const item of acceptedFindings(document)) {
    assert.ok(document.engines.includes(item.engine), `${item.engine} は engines にある`);
  }
});

test("同じ4キーが複数出る指摘は findings をその数だけ並べ、重複キーをまとめない", () => {
  const document = accepted();
  const byKey = new Map();
  for (const item of acceptedFindings(document)) {
    const key = JSON.stringify([item.engine, item.rule, item.file, item.message]);
    byKey.set(key, (byKey.get(key) ?? 0) + 1);
  }
  const dupCounts = [...byKey.values()].filter((count) => count > 1);
  assert.ok(dupCounts.length > 0, "複数行の同一指摘がある");
});

test("受け入れ一覧は aislop の baseline も旧形式（count / filePath）も持たない", () => {
  const document = accepted();
  assert.ok(!("baseline" in document) && !("entries" in document));
  for (const group of document.accepted) {
    assert.ok(!("count" in group), "群に count を残さない");
    for (const item of group.findings) {
      assert.ok(!("filePath" in item), "filePath を残さず file を使う");
      assert.ok(!("line" in item), "line を持たない");
    }
  }
});

test("受け入れ一覧は連携先モジュールを設計理由つきで登録している", () => {
  const entries = acceptedFindings(accepted()).filter(
    (item) =>
      item.rule === "ai-slop/hallucinated-import" &&
      (item.file === "packages/dsh-tui-login.mjs" || item.file === "packages/dsh-tui-models.mjs"),
  );
  assert.ok(entries.length > 0);
  const reasons = accepted().accepted
    .filter((group) => group.findings.some((item) => entries.includes(item)))
    .map((group) => group.reason);
  for (const reason of reasons) {
    assert.match(reason, /dsh|pi/);
    assert.match(reason, /実行時/);
  }
});

test("一覧どおりの scan は一致し、件数が余らない", () => {
  const document = accepted();
  const scanned = acceptedFindings(document).map((item) => ({
    engine: item.engine,
    rule: item.rule,
    filePath: item.file,
    message: item.message,
    severity: "warning",
  }));
  const { unlisted, resolved } = compareCounts(document, scanned);
  assert.deepEqual(unlisted, []);
  assert.deepEqual(resolved, []);
});

test("行番号だけが違う指摘は同じ4キーとして受け入れる", () => {
  const seed = {
    engine: "ai-slop",
    rule: "ai-slop/hallucinated-import",
    file: "config/pi/agent/extensions/content-guard.ts",
    message: 'Imports "@earendil-works/pi-coding-agent" but it\'s not declared in package.json',
  };
  const document = {
    engines: ["ai-slop"],
    missingToolsAllowed: {},
    accepted: [{ reason: "設計上の理由", findings: [{ ...seed }, { ...seed }] }],
  };
  const scanned = [
    { ...seed, filePath: seed.file, severity: "error", line: 18 },
    { ...seed, filePath: seed.file, severity: "error", line: 19 },
  ];
  const { unlisted, resolved } = compareCounts(document, scanned);
  assert.equal(unlisted.length, 0);
  assert.equal(resolved.length, 0);
});

test("受け入れ一覧に無い指摘は unlisted として拒否する", () => {
  const document = accepted();
  const unexpected = {
    ...finding({ file: "packages/unexpected.mjs", rule: "ai-slop/hallucinated-import" }),
    filePath: "packages/unexpected.mjs",
    severity: "error",
  };
  const scanned = [...acceptedFindings(document).map((item) => ({ ...item, filePath: item.file, severity: "warning" })), unexpected];
  const { unlisted } = compareCounts(document, scanned);
  assert.equal(unlisted.length, 1);
  assert.match(unlisted[0].key, /packages\/unexpected\.mjs/);
});

test("一覧にあるのに出ない指摘は resolved として検出する", () => {
  const document = accepted();
  const all = acceptedFindings(document);
  const scanned = all
    .slice(1)
    .map((item) => ({ ...item, filePath: item.file, severity: "warning" }));
  const { resolved } = compareCounts(document, scanned);
  assert.equal(resolved.length, 1);
  assert.ok(resolved[0].key.includes(all[0].file), resolved[0].key);
});

test("一覧の件数より多く出たら、超えた分を unlisted として拒否する", () => {
  const document = {
    engines: ["ai-slop"],
    missingToolsAllowed: {},
    accepted: [
      {
        reason: "CLI の出力が仕様",
        findings: [{ ...finding(), file: "packages/x.mjs" }],
      },
    ],
  };
  const scanned = expand({ ...finding(), filePath: "packages/x.mjs", severity: "warning" }, 2);
  const { unlisted } = compareCounts(document, scanned);
  assert.equal(unlisted.length, 1);
});

test("info は合否判定の対象から外れる", () => {
  const document = {
    engines: ["code-quality"],
    missingToolsAllowed: {},
    accepted: [],
  };
  const scanned = [
    { ...finding({ engine: "code-quality", rule: "code-quality/knip/skipped" }), filePath: "package.json", severity: "info" },
  ];
  const { unlisted, resolved } = compareCounts(document, scanned);
  assert.deepEqual(unlisted, []);
  assert.deepEqual(resolved, []);
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
