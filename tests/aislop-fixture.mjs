import { join } from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const ACCEPTED_PATH = "scripts/aislop-accepted.json";
const EXCLUDED_ROOTS = [".codex-corporate/", ".codex-personal/", "references/"];

export const REQUIRED_KEYS = ["engine", "rule", "filePath", "message"];

const ACCEPTED_KEYS = [...REQUIRED_KEYS, "count", "reason"];

const keyOf = (item) => JSON.stringify([item.engine, item.rule, item.filePath, item.message]);

export const finding = (overrides = {}) => {
  const base = {
    filePath: "packages/example.mjs",
    engine: "ai-slop",
    rule: "ai-slop/console-leftover",
    severity: "warning",
    message: "console.log/debug/info statement left in production code",
    help: "",
    line: 1,
    column: 1,
    category: "AI Slop",
    fixable: true,
    ...overrides,
  };
  if (overrides.severity === undefined) delete base.severity;
  return base;
};

export const readAccepted = (root) => require(join(root, ACCEPTED_PATH));

export const groupFindings = (findings) => {
  const counts = new Map();
  for (const item of findings) {
    const key = keyOf(item);
    const group = counts.get(key) ?? {
      engine: item.engine,
      rule: item.rule,
      filePath: item.filePath,
      message: item.message,
      count: 0,
    };
    group.count += 1;
    counts.set(key, group);
  }
  return [...counts.values()];
};

export const acceptedIndex = (entries) => new Map(entries.map((entry) => [keyOf(entry), entry]));

export const reconcile = (findings, entries) => {
  const index = acceptedIndex(entries);
  const seen = new Set();
  const missing = [];
  const mismatched = [];
  for (const group of groupFindings(findings)) {
    const key = keyOf(group);
    seen.add(key);
    const entry = index.get(key);
    if (!entry) {
      missing.push(group);
      continue;
    }
    if (entry.count !== group.count) mismatched.push({ group, entry });
  }
  const extra = entries.filter((entry) => !seen.has(keyOf(entry)));
  return { missing, mismatched, extra };
};

export const isExcluded = (filePath) => EXCLUDED_ROOTS.some((root) => filePath.startsWith(root));

// docs/aislop.md「合否の対象は error と warning のみ。info は合否に含めない」の唯一の判定。
// severity を持たない診断は、実 scan（aislop 0.20.1, node_modules 有り）で全件 severity を
// 持つことを確認済み。想定外の欠落は合否対象に含めず、呼び出し側の assertion（件数一致）で検出する。
const isJudged = (item) => item.severity === "error" || item.severity === "warning";

export const judgedOnly = (diagnostics) => diagnostics.filter(isJudged);

export const acceptanceOf = (diagnostics, entries) => {
  const { missing, mismatched } = reconcile(judgedOnly(diagnostics), entries);
  return [...missing, ...mismatched.map((item) => item.group)];
};

export const acceptedKeys = Object.freeze(ACCEPTED_KEYS.slice());
