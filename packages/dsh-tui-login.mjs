import { Context } from "@deepseek-ai/cordis";
import { credentialKey, credentialKeyId, credentialKeyScope } from "@deepseek-ai/dsh-credentials";
import LocalCredentialProvider from "@deepseek-ai/dsh-credentials-local";
import { openaiCodexProvider } from "@earendil-works/pi-ai/providers/openai-codex";
import { spawnSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { prepareModels } from "./models.mjs";

const usage = `dsh-tui --login [アカウント名]: ChatGPT にログインし、そのアカウントを使用します。
dsh-tui --accounts: 保存済みアカウントを表示します（* は選択中）。
dsh-tui --account アカウント名: 次回起動から使うアカウントを選びます。
アカウント名にはメールアドレスを使えます。切り替え後は dsh-tui を起動し直してください。`;
const [command, argument, ...extra] = process.argv.slice(2);
if (process.argv.includes("--help")) {
  console.log(usage);
  process.exit(0);
}
if (extra.length || !["--login", "--accounts", "--account", "--current", "--prepare"].includes(command)
  || (["--accounts", "--current", "--prepare"].includes(command) && argument !== undefined)
  || (command === "--account" && argument === undefined)) {
  throw new Error(usage);
}

function accountName(value) {
  if (typeof value !== "string" || !/^[a-zA-Z0-9][a-zA-Z0-9@._+-]{0,127}$/.test(value)) {
    throw new Error("アカウント名は128文字以内の英数字と @ . _ + - で指定してください。");
  }
  return value.toLowerCase();
}

function accountKey(name) {
  return credentialKey("llm-pi-ai", `openai-codex-${Buffer.from(accountName(name)).toString("hex")}`);
}

function credentialEmail(credential) {
  // メールアドレスの表示・照合だけに使う。認証の検証は接続先が行う。
  try {
    const claims = JSON.parse(Buffer.from(credential.access.split(".")[1], "base64url").toString());
    const email = claims["https://api.openai.com/profile"]?.email ?? claims.email;
    return typeof email === "string" ? accountName(email) : undefined;
  } catch {
    // メールアドレスを含まないトークンでも、保存済み認証としては利用できる。
    return undefined;
  }
}

const selectionKey = credentialKey("dsh-tui", "openai-codex-account");
const ctx = new Context();
const controller = new AbortController();
const cancel = () => controller.abort(new Error("ログインを中止しました。"));
process.once("SIGINT", cancel);
process.once("SIGTERM", cancel);

try {
  await ctx.plugin(LocalCredentialProvider, {
    dshHome: process.env.DSH_HOME,
    watch: false,
  });
  const selected = await ctx.credentials.readRecord(selectionKey);
  const legacyKey = credentialKey("llm-pi-ai", "openai-codex");
  const legacy = await ctx.credentials.readRecord(legacyKey);
  if (legacy && !selected) {
    const name = credentialEmail(legacy.payload) ?? "default";
    // 保存・選択が完了してから旧レコードを削除し、移行失敗時にも認証を残す。
    await ctx.credentials.modifyRecord(accountKey(name), async current => current ?? legacy);
    await ctx.credentials.modifyRecord(selectionKey, async () => ({ kind: "grant", payload: { name, pendingModelSwitch: true } }));
    await ctx.credentials.deleteRecord(legacyKey);
  }
  const selection = await ctx.credentials.readRecord(selectionKey);
  const currentName = selection === undefined ? undefined : accountName(selection.payload.name);
  if (command === "--current") {
    if (currentName !== undefined) {
      if (!(await ctx.credentials.readRecord(accountKey(currentName)))) throw new Error("選択中のアカウントの認証がありません。再ログインしてください。");
      console.log(credentialKeyId(accountKey(currentName)));
    }
  } else if (command === "--prepare") {
    if (selection !== undefined) console.log(await prepareModels(ctx.credentials, selection, process.env.DSH_HOME));
  } else if (command === "--accounts") {
    const records = await ctx.credentials.listRecords();
    const names = records
      .filter(entry => credentialKeyScope(entry.key) === "llm-pi-ai" && credentialKeyId(entry.key).startsWith("openai-codex-"))
      .map(entry => Buffer.from(credentialKeyId(entry.key).slice("openai-codex-".length), "hex").toString())
      .sort();
    console.log(names.length ? names.map(name => `${name === currentName ? "*" : " "} ${name}`).join("\n") : "保存済みの ChatGPT アカウントはありません。");
  } else if (command === "--account") {
    const name = accountName(argument);
    if (!(await ctx.credentials.readRecord(accountKey(name)))) throw new Error(`${name} の認証がありません。dsh-tui --login ${name} で登録してください。`);
    await ctx.credentials.modifyRecord(selectionKey, async () => ({ kind: "grant", payload: { name, pendingModelSwitch: true } }));
    console.log(`${name} を選択しました。dsh-tui を起動し直してください。`);
  } else {
    const name = accountName(argument ?? currentName ?? "default");
    let chromeProfile;
    if (process.platform === "darwin" && name.includes("@")) {
      try {
        const state = JSON.parse(await readFile(join(process.env.HOME, "Library/Application Support/Google/Chrome/Local State"), "utf8"));
        chromeProfile = Object.entries(state.profile?.info_cache ?? {})
          .find(([, profile]) => profile.user_name?.toLowerCase() === name)?.[0];
      } catch (error) {
        // ブラウザー設定を読めなくてもログインは可能。別アカウントで開かずリンクを案内する。
        console.error(`Chrome のプロファイルを確認できませんでした: ${error.code ?? error.name}`);
      }
    }
    console.log(`${name} として保存します。ブラウザーで使用するアカウントを確認してください。`);
    const credential = await openaiCodexProvider().auth.oauth.login({
      signal: controller.signal,
      prompt: async (prompt) => {
        if (prompt.type === "select") return "browser";
        // ローカルのコールバックで完了する。手動入力待ちは認証側の中断通知で終了する。
        if (prompt.type === "manual_code") {
          return new Promise((resolve, reject) => {
            const signal = prompt.signal === undefined
              ? controller.signal
              : AbortSignal.any([prompt.signal, controller.signal]);
            if (signal.aborted) reject(signal.reason);
            else signal.addEventListener("abort", () => reject(signal.reason), { once: true });
          });
        }
        throw new Error(`未対応の認証入力: ${prompt.type}`);
      },
      notify: (event) => {
        if (event.type === "auth_url") {
          console.log(`ブラウザーで ChatGPT にログインしてください。\n${event.url}`);
          if (process.platform === "darwin" && name.includes("@") && chromeProfile === undefined) {
            console.log("対応する Chrome プロファイルがありません。使用するブラウザーで表示したリンクを開いてください。");
            return;
          }
          const opened = chromeProfile === undefined
            ? spawnSync("/usr/bin/open", [event.url], { stdio: "ignore" })
            : spawnSync("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", [`--profile-directory=${chromeProfile}`, event.url], { stdio: "ignore" });
          if (opened.error || opened.status !== 0) {
            console.error("ブラウザーを開けませんでした。表示したリンクを開いてください。");
          }
        } else if (event.type === "info" || event.type === "progress") {
          console.log(event.message);
        }
      },
    });
    const email = credentialEmail(credential);
    if (name.includes("@") && email !== undefined && name !== email) {
      throw new Error(`${email} でログインされました。${name} の認証は変更していません。ブラウザーのアカウントを切り替えて再実行してください。`);
    }
    await ctx.credentials.modifyRecord(accountKey(name), async () => ({
      kind: "grant",
      payload: credential,
    }));
    await ctx.credentials.modifyRecord(selectionKey, async () => ({ kind: "grant", payload: { name, pendingModelSwitch: true } }));
    console.log(`${name} の認証を保存・選択しました。dsh-tui の /model から OpenAI Codex を選べます。`);
  }
} finally {
  process.removeListener("SIGINT", cancel);
  process.removeListener("SIGTERM", cancel);
  await ctx.fiber.dispose();
}
