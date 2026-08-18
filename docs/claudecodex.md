# claudecodex カンペ

Claude Code のUIから、ChatGPTのCodex認証を使ってGPT-5.6を呼び出す。

- ランチャー: `claudecodex`
- プロキシ: `claude-code-proxy`
- 接続先: `http://127.0.0.1:18765`
- 認証情報: macOS Keychainまたはユーザー設定ディレクトリ

通常の `claude` はAnthropicへ直接接続する。`claudecodex` で起動したプロセスだけがローカルプロキシを使う。

## 適用

```bash
make apply
exec zsh
```

## 初回認証

```bash
claude-code-proxy codex auth login
```

認証状態は次のコマンドで確認する。

```bash
claude-code-proxy codex auth status
```

## 起動とモデル選択

```bash
claudecodex
```

起動後に `/model` を実行すると、次の6モデルを選択できる。

モデルを選んだら `s` を押し、そのセッションだけに適用する。`Enter` を押すとClaude Code共通のデフォルトが変わり、通常の `claude` にも影響する。

| 表示名 | 上流モデル | 処理モード |
|---|---|---|
| GPT-5.6 Sol | `gpt-5.6-sol` | Standard |
| GPT-5.6 Sol (Fast) | `gpt-5.6-sol` | Fast |
| GPT-5.6 Terra | `gpt-5.6-terra` | Standard |
| GPT-5.6 Terra (Fast) | `gpt-5.6-terra` | Fast |
| GPT-5.6 Luna | `gpt-5.6-luna` | Standard |
| GPT-5.6 Luna (Fast) | `gpt-5.6-luna` | Fast |

Fastモデルは別の上流モデルではない。`-fast` 付きのローカル別名を `claude-code-proxy` が正式なモデルIDへ戻し、`service_tier: "priority"` を付けて送信する。

## 明示的な起動

モデルを起動時に指定したい場合だけ、Claude Codeの `--model` を使う。

```bash
claudecodex --model claude-gpt-5.6-sol-fast
claudecodex --model claude-gpt-5.6-terra
claudecodex --model claude-gpt-5.6-luna
```

## 更新

```bash
nix flake update claude-code-proxy claudecodex-src
make apply
```

`claude-code-proxy` と `claudecodex` のバージョンは `flake.lock` で固定する。OAuth認証情報はNix Storeへ含めない。
