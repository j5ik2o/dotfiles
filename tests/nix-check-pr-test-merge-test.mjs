import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const workflow = readFileSync(new URL("../.github/workflows/nix-check.yml", import.meta.url), "utf8");
const script = workflow.match(/\n        id: resolve\n[^]*?\n          script: \|\n((?: {12}[^\n]+\n|\n)+)/)?.[1];
assert.ok(script, "the workflow contains the PR test merge script");
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const resolveMerge = new AsyncFunction("github", "context", "core", "setTimeout", script);

const oldBase = "1".repeat(40);
const currentBase = "2".repeat(40);
const eventHead = "3".repeat(40);
const newHead = "4".repeat(40);
const oldMerge = { sha: "5".repeat(40), parents: [{ sha: oldBase }, { sha: eventHead }] };
const currentMerge = { sha: "6".repeat(40), parents: [{ sha: currentBase }, { sha: eventHead }] };

async function run({ action = "edited", changes = { body: { from: "before" } }, merges, heads = [eventHead] }) {
  const base = { ref: "main", sha: oldBase };
  const context = {
    repo: { owner: "owner", repo: "repo" },
    payload: { action, changes, pull_request: { number: 1, base, head: { sha: eventHead } } },
  };
  const outputs = {};
  const failures = [];
  let mergeReads = 0;
  let pullReads = 0;
  const github = {
    rest: {
      pulls: {
        get: async () => ({ data: { base, head: { sha: heads[Math.min(pullReads++, heads.length - 1)] } } }),
      },
      git: {
        getRef: async ({ ref }) => {
          if (ref === "heads/main") return { data: { object: { type: "commit", sha: currentBase } } };
          assert.equal(ref, "pull/1/merge");
          const merge = merges[Math.min(mergeReads++, merges.length - 1)];
          return { data: { object: { type: "commit", sha: merge.sha } } };
        },
        getCommit: async ({ commit_sha }) => ({ data: merges.find(({ sha }) => sha === commit_sha) }),
      },
    },
  };
  const core = {
    info() {},
    setOutput(name, value) { outputs[name] = value; },
    setFailed(message) { failures.push(message); },
  };
  await resolveMerge(github, context, core, (callback) => callback());
  return { outputs, failures, mergeReads };
}

for (const [label, event] of [
  ["本文編集", {}],
  ["タイトル編集", { changes: { title: { from: "before" } } }],
  ["開き直し", { action: "reopened", changes: {} }],
]) {
  test(`${label}でイベントの base SHA が古くても現在の両親を持つ試験マージを採用する`, async () => {
    const { outputs, failures } = await run({ ...event, merges: [currentMerge] });
    assert.deepEqual(failures, []);
    assert.deepEqual(outputs, { sha: currentMerge.sha, "base-sha": currentBase });
  });
}

test("古いベースで作られた試験マージを取り直す", async () => {
  const { outputs, failures, mergeReads } = await run({ merges: [oldMerge, currentMerge] });
  assert.deepEqual(failures, []);
  assert.deepEqual(outputs, { sha: currentMerge.sha, "base-sha": currentBase });
  assert.equal(mergeReads, 2);
});

test("試験マージのベースが古いままなら失敗する", async () => {
  const { outputs, failures, mergeReads } = await run({ merges: [oldMerge] });
  assert.deepEqual(outputs, {});
  assert.match(failures[0], /No test merge matched/);
  assert.equal(mergeReads, 6);
});

test("イベントの head が古い場合は試験マージを採用しない", async () => {
  const { outputs, failures, mergeReads } = await run({ merges: [oldMerge], heads: [newHead] });
  assert.deepEqual(outputs, {});
  assert.match(failures[0], /PR head or base ref changed/);
  assert.equal(mergeReads, 0);
});

test("試験マージ取得中に head が変わった場合は成功を出さない", async () => {
  const { outputs, failures } = await run({ merges: [currentMerge], heads: [eventHead, newHead] });
  assert.deepEqual(outputs, {});
  assert.match(failures[0], /PR head or base ref changed/);
});
