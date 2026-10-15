import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtemp, readFile, rm, stat } from "node:fs/promises";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [root, binary] = process.argv.slice(2);
const require = createRequire(join(root, "package.json"));
const load = name => import(pathToFileURL(require.resolve(name)));
const { Context } = await load("@deepseek-ai/cordis");
const { credentialKey } = await load("@deepseek-ai/dsh-credentials");
const { default: LocalCredentialProvider } = await load("@deepseek-ai/dsh-credentials-local");
const home = await mkdtemp(join(tmpdir(), "dsh-tui-accounts-"));
const dshHome = join(home, ".dsh-tui");
const env = { ...process.env, HOME: home, DSH_HOME: dshHome };
const first = "first@example.com";
const second = "second@example.com";
const key = name => credentialKey("llm-pi-ai", `openai-codex-${Buffer.from(name).toString("hex")}`);
const token = email => ({
  kind: "grant",
  payload: {
    type: "oauth",
    access: `test.${Buffer.from(JSON.stringify({ email })).toString("base64url")}.test`,
    refresh: `test-refresh-${email}`,
    expires: Date.now() + 60000,
  },
});
async function withStore(run) {
  const ctx = new Context();
  try {
    await ctx.plugin(LocalCredentialProvider, { dshHome, watch: false });
    return await run(ctx.credentials);
  } finally {
    await ctx.fiber.dispose();
  }
}
const command = (...args) => execFileSync(binary, args, { env, encoding: "utf8" }).trim();
const selectedId = () => execFileSync(process.execPath, [join(root, "login.mjs"), "--current"], { env, encoding: "utf8" }).trim();
try {
  assert.match(command("--accounts"), /保存済み.*ありません/);
  const legacy = token(first);
  const other = token(second);
  await withStore(async store => {
    await store.modifyRecord(credentialKey("llm-pi-ai", "openai-codex"), async () => legacy);
    await store.modifyRecord(key(second), async () => other);
  });
  assert.match(command("--accounts"), /\* first@example.com/);
  const firstId = selectedId();
  assert.equal(firstId, `openai-codex-${Buffer.from(first).toString("hex")}`);
  await withStore(async store => {
    assert.deepEqual(await store.readRecord(key(first)), legacy);
    assert.equal(await store.readRecord(credentialKey("llm-pi-ai", "openai-codex")), undefined);
  });
  command("--account", second);
  assert.match(command("--accounts"), /\* second@example.com/);
  assert.notEqual(selectedId(), firstId);
  const before = await readFile(join(dshHome, ".credentials.yaml"), "utf8");
  const missing = spawnSync(binary, ["--account", "missing@example.com"], { env, encoding: "utf8" });
  assert.notEqual(missing.status, 0);
  assert.match(missing.stderr, /認証がありません/);
  assert.equal(await readFile(join(dshHome, ".credentials.yaml"), "utf8"), before);
  // 選択を変えた後も、起動済みプロセスの更新は元のアカウントだけに届く。
  const refreshed = { ...legacy, payload: { ...legacy.payload, refresh: "test-refreshed-first" } };
  const script = `
    import { Context } from ${JSON.stringify(pathToFileURL(require.resolve("@deepseek-ai/cordis")).href)};
    import LocalCredentialProvider from ${JSON.stringify(pathToFileURL(require.resolve("@deepseek-ai/dsh-credentials-local")).href)};
    import { recordKeyFor } from ${JSON.stringify(pathToFileURL(require.resolve("@deepseek-ai/dsh-llm-pi-ai")).href)};
    const ctx = new Context();
    try {
      await ctx.plugin(LocalCredentialProvider, { dshHome: process.env.DSH_HOME, watch: false });
      await ctx.credentials.modifyRecord(recordKeyFor("openai-codex"), async () => (${JSON.stringify(refreshed)}));
    } finally { await ctx.fiber.dispose(); }
  `;
  execFileSync(process.execPath, ["--input-type=module", "-e", script], { env: { ...env, DSH_CODEX_CREDENTIAL_ID: firstId } });
  await withStore(async store => {
    assert.deepEqual(await store.readRecord(key(first)), refreshed);
    assert.deepEqual(await store.readRecord(key(second)), other);
  });
  command("--account", first);
  assert.equal(selectedId(), firstId);
  assert.equal((await stat(join(dshHome, ".credentials.yaml"))).mode & 0o777, 0o600);
  console.log("アカウントの移行・切り替え・更新先の分離: OK");
} finally {
  await rm(home, { recursive: true, force: true });
}
