import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { runInNewContext } from "node:vm";

const [root] = process.argv.slice(2);
const require = createRequire(join(root, "package.json"));
const load = name => import(pathToFileURL(require.resolve(name)));
const { Context } = await load("@deepseek-ai/cordis");
const { installModelSelection } = await load("@deepseek-ai/dsh-agent");
const { ReasoningEffortId } = await load("@deepseek-ai/dsh-llm");
const directory = join(root, "node_modules/@tomowang/dsh-tui/lib");
const { CustomEditor } = await import(pathToFileURL(join(directory, "tui/CustomEditor.js")));
const { TuiStore } = await import(pathToFileURL(join(directory, "tui/store.js")));
let command;
let sent;
const editor = {
  shellMode: false, deps: { history: [] }, setShellMode() {}, addToHistory() {},
  actions: { recordHistory() {}, effort: value => { command = value; }, send: value => { sent = value; } },
};
CustomEditor.prototype.handleSubmit.call(editor, "/effort xhigh");
assert.equal(command, "xhigh", "推論強度のコマンドが処理されていません");
assert.equal(sent, undefined, "コマンドがモデルに送信されています");
CustomEditor.prototype.handleSubmit.call(editor, "/effort");
assert.equal(command, "");

const source = await readFile(join(directory, "index.js"), "utf8");
const start = source.indexOf("            async effort(value) {");
const end = source.indexOf("            openTrajectory() {", start);
assert.ok(start >= 0 && end > start);
const selected = { current: { provider: "openai-codex", model: "gpt-6.1-sol" }, assembled: undefined };
const store = new TuiStore({ events: [] });
let saved;
let failSave = false;
let resolveInfo = async () => ({ reasoning: { defaultEffort: "high", efforts: [{ id: "low" }, { id: "high" }, { id: "xhigh" }] } });
const actions = runInNewContext(`({${source.slice(start, end)}})`, {
  selected, store, ReasoningEffortId, changingSelection: false,
  ctx: { get: () => ({ resolveModelInfo: (...args) => resolveInfo(...args) }) },
  defaultModel: { saveSelection: async next => {
    if (failSave) throw new Error("保存失敗");
    saved = next;
  } },
});
const routing = new Context();
const dispose = installModelSelection(routing, selected);
try {
  await actions.effort("");
  assert.match(store.getSnapshot().notice, /high/);
  assert.equal(saved, undefined);
  await routing.waterfall(routing, "system-prompt/assemble", {}, {}, async () => ({ variables: {} }));
  await actions.effort("xhigh");
  assert.equal(selected.current.reasoningEffort, "xhigh");
  assert.equal(saved.reasoningEffort, "xhigh");
  const inProgress = await routing.waterfall(routing, "agent/request", {}, async () => selected.current);
  assert.equal(inProgress.reasoningEffort, undefined, "進行中の推論の強度が途中で変わっています");
  await routing.waterfall(routing, "system-prompt/assemble", {}, {}, async () => ({ variables: {} }));
  const next = await routing.waterfall(routing, "agent/request", {}, async () => ({}));
  assert.equal(next.reasoningEffort, "xhigh");
  await actions.effort("unsupported");
  assert.equal(selected.current.reasoningEffort, "xhigh");
  assert.match(store.getSnapshot().notice, /使用可能/);
  failSave = true;
  await actions.effort("low");
  assert.equal(selected.current.reasoningEffort, "xhigh");
  assert.match(store.getSnapshot().notice, /保存失敗/);
  failSave = false;
  await actions.effort("default");
  assert.equal(selected.current.reasoningEffort, undefined);
  assert.equal(saved.reasoningEffort, undefined);
  // 非同期の確認中にモデル選択が割り込んでも、古いモデルに戻さない。
  let release;
  resolveInfo = () => new Promise(resolve => { release = resolve; });
  const pending = actions.effort("high");
  actions.setActiveModel("openai-codex", "gpt-6-astra");
  assert.equal(selected.current.model, "gpt-6.1-sol");
  release({ reasoning: { efforts: [{ id: "high" }] } });
  await pending;
  assert.equal(selected.current.reasoningEffort, "high");
  console.log("推論強度コマンド・次の推論への反映・入力検証・失敗時と変更中の保持: OK");
} finally {
  dispose();
  await routing.fiber.dispose();
}
