import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { runInNewContext } from "node:vm";

const [root] = process.argv.slice(2);
const require = createRequire(join(root, "package.json"));
const { Context } = await import(pathToFileURL(require.resolve("@deepseek-ai/cordis")));
const { installModelSelection } = await import(pathToFileURL(require.resolve("@deepseek-ai/dsh-agent")));
const tuiDirectory = join(root, "node_modules", "@tomowang", "dsh-tui", "lib");
const source = await readFile(join(tuiDirectory, "index.js"), "utf8");
const appSource = await readFile(join(tuiDirectory, "tui", "TuiApp.js"), "utf8");
const { TuiStore } = await import(pathToFileURL(join(tuiDirectory, "tui", "store.js")));
const actionStart = source.indexOf("            setActiveModel(provider, model) {");
const actionEnd = source.indexOf("            openTrajectory() {", actionStart);
assert.ok(actionStart >= 0 && actionEnd > actionStart);
const action = source.slice(actionStart, actionEnd);
const original = { provider: "openai-codex", model: "gpt-6.1-sol" };
const next = { provider: "openai-codex", model: "gpt-6-astra" };
const selected = { current: original, assembled: undefined };
const store = new TuiStore({ events: [] });
const actions = runInNewContext(`({${action}})`, {
  selected, store, changingSelection: false,
  defaultModel: { saveSelection: async () => {} },
});
const ctx = new Context();
const dispose = installModelSelection(ctx, selected);
try {
  actions.setActiveModel(next.provider, next.model);
  await new Promise(resolve => setImmediate(resolve));
  const assembled = await ctx.waterfall(ctx, "system-prompt/assemble", {}, {}, async () => ({ variables: {} }));
  const request = await ctx.waterfall(ctx, "agent/request", {}, async () => original);
  assert.equal(request.model, next.model, "モデル選択後の推論が旧モデルのままです");
  assert.equal(assembled.variables.model, next.model);

  // 実際の描画コールバックを、保存済みの起動時モデルと異なる選択で評価する。
  const options = { ...original, getModelSelection: () => selected.current };
  const capture = { options, store, spinner: { current: () => "" }, buildBannerText: value => value, buildStatusBarText: value => value };
  const bannerStart = appSource.indexOf("new DynamicText(width => buildBannerText(");
  const bannerEnd = appSource.indexOf("));", bannerStart);
  const banner = appSource.slice(bannerStart + "new DynamicText(".length, bannerEnd);
  assert.equal(runInNewContext(`(${banner})`, capture)(80).model, next.model, "チャットの見出しが旧モデルのままです");
  const statusStart = appSource.indexOf("new DynamicText(() => {", appSource.indexOf("const statusBarText"));
  const statusEnd = appSource.indexOf("\n        });", statusStart);
  const status = appSource.slice(statusStart + "new DynamicText(".length, statusEnd) + "        }";
  assert.equal(runInNewContext(`(${status})`, capture)().model, next.model, "チャットの状態表示が旧モデルのままです");
  const failing = runInNewContext(`({${action}})`, {
    selected, store, changingSelection: false,
    defaultModel: { saveSelection: async () => { throw new Error("保存失敗"); } },
  });
  failing.setActiveModel(original.provider, original.model);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(selected.current.model, next.model);
  assert.match(store.getSnapshot().notice, /保存失敗/);
  console.log("モデル選択後の推論・チャット表示の同期、保存失敗時の保持: OK");
} finally {
  dispose();
  await ctx.fiber.dispose();
}
