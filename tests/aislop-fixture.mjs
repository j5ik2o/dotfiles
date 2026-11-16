import { join } from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const ACCEPTED_PATH = "scripts/aislop-accepted.json";
const PIN_PATH = "scripts/aislop-check-pin.json";
const CONFIG_PATH = ".aislop/config.yml";
const BOOTSTRAP_PATH = "scripts/aislop-check-bootstrap.mjs";
const EXCLUDED_ROOTS = [".codex-corporate/", ".codex-personal/", "references/"];

// 正本 check-aislop.mjs の compareFindings が突き合わせるキー。line は使わない。
export const FINDING_KEYS = ["engine", "rule", "file", "message"];

const keyOfFinding = (item) => JSON.stringify([item.engine, item.rule, item.file, item.message]);

export const finding = (overrides = {}) => {
  const base = {
    file: "packages/example.mjs",
    engine: "ai-slop",
    rule: "ai-slop/console-leftover",
    message: "console.log/debug/info statement left in production code",
    ...overrides,
  };
  return base;
};

export const readAccepted = (root) => require(join(root, ACCEPTED_PATH));

export const readPin = (root) => require(join(root, PIN_PATH));

export const acceptedFindings = (document) =>
  document.accepted.flatMap((group) => group.findings);

// 一覧の findings をキーごとに数える。同じ 4キーが複数あれば件数として数える。
export const countAccepted = (document) => {
  const counts = new Map();
  for (const item of acceptedFindings(document)) {
    const key = keyOfFinding(item);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return counts;
};

// scan の diagnostics（severity が error/warning のもの）を 4キーで数える。
export const countDiagnostics = (diagnostics) => {
  const counts = new Map();
  for (const item of diagnostics) {
    if (item.severity !== "error" && item.severity !== "warning") continue;
    const key = keyOfFinding({ engine: item.engine, rule: item.rule, file: item.filePath, message: item.message });
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return counts;
};

export const compareCounts = (document, diagnostics) => {
  const accepted = countAccepted(document);
  const scanned = countDiagnostics(diagnostics);
  const unlisted = [];
  for (const [key, count] of scanned) {
    const remaining = (accepted.get(key) ?? 0) - count;
    if (remaining < 0) unlisted.push({ key, count, accepted: accepted.get(key) ?? 0 });
  }
  const resolved = [];
  for (const [key, count] of accepted) {
    const remaining = count - (scanned.get(key) ?? 0);
    if (remaining > 0) resolved.push({ key, accepted: count, scanned: scanned.get(key) ?? 0 });
  }
  return { unlisted, resolved };
};

export const isExcluded = (filePath) => EXCLUDED_ROOTS.some((root) => filePath.startsWith(root));

export const judgedOnly = (diagnostics) =>
  diagnostics.filter((item) => item.severity === "error" || item.severity === "warning");

export { ACCEPTED_PATH, PIN_PATH, CONFIG_PATH, BOOTSTRAP_PATH, EXCLUDED_ROOTS };
