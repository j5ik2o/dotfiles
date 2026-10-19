import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [root] = process.argv.slice(2);
const require = createRequire(join(root, "package.json"));
const load = name => import(pathToFileURL(require.resolve(name)));
const { Context } = await load("@deepseek-ai/cordis");
const { credentialKey } = await load("@deepseek-ai/dsh-credentials");
const { default: LocalCredentialProvider } = await load("@deepseek-ai/dsh-credentials-local");
const { default: Llm } = await load("@deepseek-ai/dsh-llm");
const PiAi = await load("@deepseek-ai/dsh-llm-pi-ai");
const { parse } = await load("yaml");
const { prepareModels } = await import(pathToFileURL(join(root, "models.mjs")));
const home = await mkdtemp(join(tmpdir(), "dsh-models-check-"));
const ctx = new Context();
const selectionKey = credentialKey("dsh-tui", "openai-codex-account");
const names = ["personal@example.com", "work@example.com"];
// 鍵の値がない接続先はモデル一覧が空になるので、起動スクリプトと同じ仮の値を入れる。
process.env.DSH_TENSORFOLD_API_KEY ??= "tensorfold";
const ids = ["gpt-6-luna", "gpt-6.1-sol"];
try {
  await ctx.plugin(LocalCredentialProvider, { dshHome: home, watch: false });
  const profilePath = join(home, "profiles", "tui", "cordis.patch.yml");
  await mkdir(join(home, "profiles", "tui"), { recursive: true });
  await writeFile(profilePath, "# 利用者のコメント\n- id: agent-default-model\n  config:\n    provider: openai-codex\n    model: gpt-5.4-mini\n- id: custom-plugin\n  config:\n    keep: true\n- id: llm-pi-ai\n  config:\n    providers:\n      openai-codex:\n        reasoning: high\n");
  for (const [index, name] of names.entries()) {
    const accountKey = credentialKey("llm-pi-ai", `openai-codex-${Buffer.from(name).toString("hex")}`);
    await ctx.credentials.modifyRecord(accountKey, async () => ({ kind: "grant", payload: {
      type: "oauth", access: `test-access-${index}`, refresh: `test-refresh-${index}`,
      accountId: `test-account-${index}`, expires: Date.now() + 3600000,
    } }));
    const selection = await ctx.credentials.modifyRecord(selectionKey, async () => ({ kind: "grant", payload: { name, pendingModelSwitch: true } }));
    const fetchCatalog = async (url, options) => {
      assert.match(url, /\/codex\/models\?client_version=/);
      assert.equal(options.headers.Authorization, `Bearer test-access-${index}`);
      assert.equal(options.headers["ChatGPT-Account-Id"], `test-account-${index}`);
      return { ok: true, json: async () => ({ models: [
        { slug: ids[index], display_name: ids[index], visibility: "list", context_window: 272000, input_modalities: ["text"], supported_reasoning_levels: [{ effort: "medium" }, { effort: "high" }, { effort: "ultra" }] },
        { slug: "hidden-model", visibility: "hide" },
      ] }) };
    };
    const patchPath = await prepareModels(ctx.credentials, selection, home, fetchCatalog);
    const patch = JSON.parse(await readFile(patchPath, "utf8"));
    assert.deepEqual(patch[0].config.providers["openai-codex"].models.map(model => model.id), [ids[index]]);
    assert.equal(patch[0].config.providers["openai-codex"].reasoning, "high", "生成したモデル一覧が接続先の推論強度を消しています");
    assert.match(patch[0].config.providers["openai-codex"].displayName, new RegExp(name));
    // patch は llm-pi-ai の config を丸ごと置き換えるので、同梱の接続先も残す。
    for (const provider of ["opencode-go", "ollama-cloud", "tensorfold"]) {
      assert.ok(patch[0].config.providers[provider], `生成したモデル一覧が ${provider} を消しています`);
    }
    const source = await readFile(profilePath, "utf8");
    assert.match(source, /利用者のコメント/);
    const config = parse(source);
    assert.equal(config.find(entry => entry.id === "agent-default-model").config.model, ids[index]);
    assert.equal(config.find(entry => entry.id === "custom-plugin").config.keep, true);
    // 実際の接続アダプターのモデル表示も、同梱一覧ではなく取得した一覧になる。
    const display = new Context();
    try {
      await display.plugin(Llm);
      await display.plugin(PiAi, patch[0].config);
      assert.deepEqual((await display.llm.listModels("openai-codex")).map(model => model.id), [ids[index]]);
      assert.deepEqual((await display.llm.listModels("tensorfold")).map(model => model.id), ["deepseek-v4.1-flash"]);
    } finally { await display.fiber.dispose(); }
    await assert.rejects(prepareModels(ctx.credentials, selection, home, async () => ({ ok: false, status: 503 })), /503/);
    assert.equal(await readFile(profilePath, "utf8"), source);
  }
  console.log("アカウント別モデル表示・非対応モデルの置換・設定の保持: OK");
} finally {
  await ctx.fiber.dispose();
  await rm(home, { recursive: true, force: true });
}
