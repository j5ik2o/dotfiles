import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));

const readDoc = () => {
  try {
    return readFileSync(join(repoRoot, "docs/aislop.md"), "utf8");
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
};

const readAcceptedTotal = () =>
  JSON.parse(readFileSync(join(repoRoot, "scripts/aislop-accepted.json"), "utf8"))
    .accepted.flatMap((group) => group.findings).length;

const lintGate = () => {
  const script = readFileSync(join(repoRoot, "scripts/lint.sh"), "utf8");
  const start = script.indexOf("gate=\"ruff\"");
  assert.notEqual(start, -1, "scripts/lint.sh に ruff ゲートがある");
  return script.slice(start);
};

const requireDoc = (doc) => {
  assert.notEqual(doc, null, "docs/aislop.md が存在する");
  return doc;
};

test("docs/aislop.md は先頭でこのゴールの範囲を明記する", () => {
  const doc = requireDoc(readDoc());
  assert.match(doc, /check-aislop\.mjs/);
  assert.match(doc, /make done/);
});

test("docs/aislop.md は除外の件数を対象ディレクトリと区分に結び付けて記録する", () => {
  const doc = requireDoc(readDoc());
  const rowFor = (label) => {
    const line = doc.split("\n").find((entry) => entry.startsWith(`| ${label}`));
    assert.ok(line, `${label} の行がある`);
    return line;
  };
  assert.match(rowFor("`.codex-corporate/` 配下の指摘"), /94（error 11・warning 81・info 2）/);
  assert.match(rowFor("`.codex-personal/` 配下の指摘"), /120（error 13・warning 105・info 2）/);
  assert.match(doc, /references\//);
});

test("docs/aislop.md の受け入れ行は規則ごとの件数と区分を持つ", () => {
  const doc = requireDoc(readDoc());
  const rowFor = (label) => {
    const line = doc.split("\n").find((entry) => entry.startsWith(`| ${label}`));
    assert.ok(line, `${label} の行がある`);
    return line;
  };
  assert.match(rowFor("`config/pi/agent/extensions/content-guard.ts` の hallucinated-import"), /2（error 2）/);
  assert.match(
    rowFor("`packages/dsh-tui-login.mjs` / `dsh-tui-models.mjs` の hallucinated-import"),
    /7（error 7）/,
  );
  assert.match(rowFor("`packages/dsh-tui-login.mjs` の console-leftover"), /10（warning 10）/);
  assert.match(rowFor("`packages/*-check.mjs` の console-leftover"), /4（warning 4）/);
  assert.match(rowFor("`packages/dsh-tui-models.mjs` の hardcoded-url"), /1（warning 1）/);
  assert.match(rowFor("`config/spark/namespace_relay.py` の complexity"), /3（warning 3）/);
  assert.match(rowFor("`packages/dsh-tui-models.mjs` の function-too-long"), /1（warning 1）/);
  assert.match(
    rowFor("`config/spark/namespace_relay.py` / `scripts/clean-commit-msg.py` の python-formatting"),
    /2（warning 2）/,
  );
});

test("docs/aislop.md は受け入れ一覧の件数の合計を記録する", () => {
  const doc = requireDoc(readDoc());
  assert.ok(doc.includes(String(readAcceptedTotal())), "受け入れ件数の合計");
});

test("docs/aislop.md は除外前後の error と warning の件数を区分つきで記録する", () => {
  const doc = requireDoc(readDoc());
  assert.match(doc, /error 9 件・warning 22 件/);
  assert.match(doc, /error 33 \/ warning 208/);
  assert.match(doc, /error 33 − 24 = 9/);
  assert.match(doc, /warning 208 − 186 = 22/);
});

test("docs/aislop.md は hallucinated-import の再 scan を根拠にした理由を記録する", () => {
  const doc = requireDoc(readDoc());
  assert.match(doc, /hallucinated-import/);
  assert.match(doc, /node_modules/);
  assert.match(doc, /packages\/dsh-tui-login\.mjs/);
  assert.match(doc, /packages\/dsh-tui-models\.mjs/);
});

test("docs/aislop.md は info の扱いを記録する", () => {
  const doc = requireDoc(readDoc());
  assert.match(doc, /info/);
  assert.match(doc, /knip/);
});

test("docs/aislop.md は info の件数を記録する", () => {
  const doc = requireDoc(readDoc());
  assert.match(doc, /info[^\n]*\b1\b|\b1\b[^\n]*info/);
});

test("docs/aislop.md は除外前後の件数の対応を記録する", () => {
  const doc = requireDoc(readDoc());
  for (const count of [33, 208, 9, 22]) {
    assert.ok(new RegExp(`\\b${count}\\b`).test(doc), `${count} が記録されている`);
  }
  assert.match(doc, /除外/);
});

test("docs/aislop.md は ruff の結論と根拠を記録する", () => {
  const doc = requireDoc(readDoc());
  const gate = lintGate();
  assert.match(gate, /ruff check/);
  assert.match(doc, /ruff/);
  assert.match(doc, /gate|ゲート/);
});

test("docs/aislop.md は knip の要否の結論と理由を記録する", () => {
  const doc = requireDoc(readDoc());
  assert.match(doc, /knip/);
  assert.match(doc, /導入しない|導入する/);
});

test("docs/aislop.md は make done と CI への組み込みを記録する", () => {
  const doc = requireDoc(readDoc());
  assert.match(doc, /make done/, "make done への組み込みを記録する");
  assert.match(doc, /nix-check/, "CI への組み込みを記録する");
  assert.ok(!/未導入/.test(doc), "未導入の記述を残さない");
});
