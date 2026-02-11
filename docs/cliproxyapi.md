# CLIProxyAPI カンペ

設定ファイルは Git 管理し、`make apply` で `~/.config/cliproxyapi/config.yaml` に展開される。

- 管理元: `config/cliproxyapi/config.yaml`
- 展開先: `~/.config/cliproxyapi/config.yaml`
- ログ: `~/.local/state/cliproxyapi.log`
- PID: `~/.local/state/cliproxyapi.pid`

## 適用

```bash
make apply
```

## 起動/停止/状態

```bash
make cliproxyapi-start
make cliproxyapi-status
make cliproxyapi-stop
make cliproxyapi-restart
```

```bash
tail -f ~/.local/state/cliproxyapi.log
```

## 疎通確認

`config/cliproxyapi/config.yaml` の `api-keys` にある値を使う。

```bash
CLIPROXYAPI_API_KEY='<client-api-key>' make cliproxyapi-test
```

```bash
curl -sS \
  -H "Authorization: Bearer <client-api-key>" \
  http://127.0.0.1:8317/v1/models
```

## 上流ログイン（OAuth）

```bash
make cliproxyapi-login-gemini
make cliproxyapi-login-codex
make cliproxyapi-login-claude
```

## クライアント設定

### Claude Code

```bash
export ANTHROPIC_BASE_URL='http://127.0.0.1:8317'
export ANTHROPIC_AUTH_TOKEN='<client-api-key>'
export ANTHROPIC_MODEL='claude-sonnet-4-5'
claude
```

### Codex CLI

`~/.codex/config.toml` に provider を追加する。

```toml
model_provider = "cliproxyapi"
model = "gpt-5"

[model_providers.cliproxyapi]
name = "CLIProxyAPI"
base_url = "http://127.0.0.1:8317/v1"
wire_api = "chat"
env_key = "OPENAI_API_KEY"
```

```bash
export OPENAI_API_KEY='<client-api-key>'
codex
```

### Gemini CLI

Gemini CLI は `cliproxyapi` 側の Google OAuth ログインを使う。

```bash
make cliproxyapi-login-gemini
gemini
```

### OpenCode

`~/.config/opencode/opencode.json` の provider 設定で `baseURL` と `apiKey` を指定する。

```json
{
  "provider": {
    "openai": {
      "options": {
        "baseURL": "http://127.0.0.1:8317/v1",
        "apiKey": "<client-api-key>"
      }
    }
  }
}
```

## モデル選択ガイド（具体例）

### まずやること

利用可能モデルを見てから選ぶ。

```bash
curl -sS \
  -H "Authorization: Bearer <client-api-key>" \
  http://127.0.0.1:8317/v1/models \
  | jq -r '.data[].id' | sort
```

### どの上流に行くか

基本は `model` 名で決まる。

- `claude-*` 系: Claude OAuth
- `gpt-*` / `o*` 系: Codex(OpenAI) OAuth
- `gemini-*` 系: Gemini OAuth

同じ系列で複数アカウントがある場合は `routing.strategy` で選択される。

- `round-robin`: 順番に使う（デフォルト）
- `fill-first`: 1アカウントを優先して使い切る

### CLI別の指定例

Claude Code:

```bash
export ANTHROPIC_MODEL='claude-sonnet-4-5-20250929'
claude
```

Codex CLI (`~/.codex/config.toml`):

```toml
model = "gpt-5"
```

Gemini CLI:

```bash
gemini -m gemini-2.5-pro
```

OpenCode:

```bash
opencode -m openai/gpt-5
```

### 運用で迷わないための固定名（推奨）

`config/cliproxyapi/config.yaml` でエイリアスを作って、クライアントはその名前だけ使う。

```yaml
oauth-model-alias:
  claude:
    - name: "claude-sonnet-4-5-20250929"
      alias: "claude-main"
  codex:
    - name: "gpt-5"
      alias: "codex-main"
  gemini-cli:
    - name: "gemini-2.5-pro"
      alias: "gemini-main"
```

適用後は以下のように指定する。

- Claude Code: `ANTHROPIC_MODEL=claude-main`
- Codex CLI: `model = "codex-main"`
- Gemini CLI: `gemini -m gemini-main`

不要モデルを見せたくない場合は `oauth-excluded-models` で隠せる。

## 補足

- `api-keys` は「このローカルプロキシへ入るためのキー」。
- 上流キーは `config.yaml` の各セクションで管理する（例: `gemini-api-key`, `codex-api-key`, `claude-api-key`, `openai-compatibility`）。
- `api-keys` を使わない運用にするには、`cliproxyapi` 側の実装変更が必要。
