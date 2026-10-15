import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import { credentialKey } from "@deepseek-ai/dsh-credentials";
import { openaiCodexProvider } from "@earendil-works/pi-ai/providers/openai-codex";
import { parseDocument } from "yaml";

async function writeAtomic(path, content) {
  const temporary = `${path}.${randomUUID()}.tmp`;
  await writeFile(temporary, content, { mode: 0o600 });
  await rename(temporary, path);
}

export async function prepareModels(store, selection, dshHome, fetchCatalog = fetch) {
  const name = selection.payload.name;
  const accountId = `openai-codex-${Buffer.from(name).toString("hex")}`;
  const key = credentialKey("llm-pi-ai", accountId);
  const record = await store.modifyRecord(key, async current => {
    if (current?.kind !== "grant") throw new Error(`${name} の認証がありません。再ログインしてください。`);
    if (current.payload.expires > Date.now() + 60000) return current;
    const payload = await openaiCodexProvider().auth.oauth.refresh(current.payload, AbortSignal.timeout(20000));
    return { kind: "grant", payload: JSON.parse(JSON.stringify(payload)) };
  });
  const response = await fetchCatalog("https://chatgpt.com/backend-api/codex/models?client_version=0.160.1", {
    headers: {
      Authorization: `Bearer ${record.payload.access}`,
      "ChatGPT-Account-Id": record.payload.accountId,
      originator: "codex_cli_rs",
    },
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) throw new Error(`${name} のモデル一覧を取得できませんでした（状態コード ${response.status}）。`);
  const data = await response.json();
  if (!Array.isArray(data.models)) throw new Error("モデル一覧の応答形式が不正です。");
  const models = data.models
    .filter(model => model.visibility === "list")
    .sort((a, b) => (a.priority ?? Infinity) - (b.priority ?? Infinity))
    .map(model => {
      if (typeof model.slug !== "string" || !model.slug || !Number.isInteger(model.context_window) || model.context_window <= 0) {
        throw new Error("モデル一覧に不正なモデル情報があります。");
      }
      const efforts = (model.supported_reasoning_levels ?? [])
        .map(level => level.effort)
        .filter(effort => ["minimal", "low", "medium", "high", "xhigh", "max"].includes(effort));
      return {
        id: model.slug,
        name: model.display_name ?? model.slug,
        contextWindow: model.context_window,
        maxTokens: Math.min(32768, model.context_window),
        input: model.input_modalities ?? ["text"],
        reasoningEfforts: efforts.length ? Object.fromEntries(efforts.map(effort => [effort, effort])) : false,
      };
    });
  if (!models.length) throw new Error(`${name} で利用できる Codex モデルがありません。`);

  const profileDirectory = join(dshHome, "profiles", "tui");
  const userPatch = join(profileDirectory, "cordis.patch.yml");
  let source;
  try {
    source = await readFile(userPatch, "utf8");
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
    source = "[]\n";
  }
  const document = parseDocument(source);
  if (document.errors.length) throw new Error("利用者のプロファイル設定を解析できませんでした。");
  const entries = document.toJS();
  if (!Array.isArray(entries)) throw new Error("プロファイル設定はプラグインの配列で指定してください。");
  const index = entries.findIndex(entry => entry.id === "agent-default-model");
  const configured = entries[index]?.config;
  const needsCodex = selection.payload.pendingModelSwitch || configured === undefined || configured.provider === "openai-codex";
  if (needsCodex) {
    const model = models.find(model => configured?.provider === "openai-codex" && model.id === configured.model) ?? models[0];
    // ローカルの文書ツリーだけを編集し、他の設定とコメントを保持する。
    if (index < 0) document.add({ id: "agent-default-model", config: { provider: "openai-codex", model: model.id } });
    else {
      document.setIn([index, "config", "provider"], "openai-codex");
      document.setIn([index, "config", "model"], model.id);
    }
    await mkdir(profileDirectory, { recursive: true, mode: 0o700 });
    await writeAtomic(userPatch, document.toString());
  }
  const directory = join(dshHome, "accounts", accountId);
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const patchPath = join(directory, "models.patch.json");
  const providerConfig = entries.find(entry => entry.id === "llm-pi-ai")?.config?.providers?.["openai-codex"] ?? {};
  await writeAtomic(patchPath, JSON.stringify([{
    id: "llm-pi-ai",
    config: { providers: { "openai-codex": {
      displayName: `OpenAI Codex (${name})`,
      ...(providerConfig.reasoning === undefined ? {} : { reasoning: providerConfig.reasoning }),
      models,
    } } },
  }], null, 2));
  await store.modifyRecord(credentialKey("dsh-tui", "openai-codex-account"), async current => {
    // 別プロセスが選択を変えた場合、その選択を上書きしない。
    return current?.payload.name === name ? { ...current, payload: { ...current.payload, pendingModelSwitch: false } } : current;
  });
  return patchPath;
}
