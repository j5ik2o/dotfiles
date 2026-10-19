# dotfiles

Nix + Home Manager + nix-darwin によるdotfiles管理

## 構成

```
dotfiles/
├── flake.nix           # Nix Flake エントリポイント
├── darwin/             # nix-darwin (macOS) 設定
├── home/               # Home Manager 設定
├── modules/            # 共通モジュール
│   └── programs/       # プログラム別設定
├── config/             # アプリ設定ファイル
│   └── nvim/           # Neovim 設定
├── chezmoi/            # シークレット管理 (1Password 連携)
│   └── private_dot_ssh/ # SSH キーテンプレート
├── docs/               # ドキュメント
│   └── neovim.md       # Neovim キーマップ
└── Makefile            # ビルド・適用コマンド
```

## クリーンインストール

```bash
./scripts/setup.sh
```

## 日常の使い方

### 設定を変更した後

```bash
make apply
```

### flake.lock を更新

```bash
make update
make apply
```

### ロールバック（問題が発生した場合）

```bash
make rollback
```

### ビルドだけ（適用しない）

```bash
make build
```

### ガベージコレクション

```bash
make gc
```

### DeepSeek Harness TUI

`dsh-tui` は npm 公開版の `@tomowang/dsh-tui 0.10.0` と対応する
`@deepseek-ai/dsh 0.2.1-rc.2` を依存 lockfile ごと Nix で固定する。既存の `dsh` コマンドとは別名で、
`DSH_HOME` を常に `~/.dsh-tui` に設定するため、`~/.dsh` の設定・認証・セッションは共有しない。

```bash
# 未登録の新規ファイルがある場合は Git にパスを登録する（commit は不要）
git add -N packages/dsh-tui*
nix build .#dsh-tui --out-link .tmp/dsh-tui
./.tmp/dsh-tui/bin/dsh-tui --version
./.tmp/dsh-tui/bin/dsh-tui --help
./.tmp/dsh-tui/bin/dsh-tui
```

通常の `make apply` 後は `dsh-tui` で起動できる。Home Manager の現行世代が
本体・プラグイン・Node を保持するので、`make gc` でも失われない。
全体適用前のビルド実体は `.tmp/dsh-tui` が GC root になる。

API キーは実行時の `DEEPSEEK_API_KEY`、または `~/.dsh-tui/.env` に設定する。
`.env` を作る場合は `chmod 600 ~/.dsh-tui/.env` とし、キーを Nix 設定や Git に書かない。
カスタマイズは `~/.dsh-tui/profiles/tui/cordis.patch.yml` に置く。
プロファイルの manifest と `node_modules` は起動ごとに Nix 側へリンクするため、
プラグインの追加・更新は `packages/dsh-tui-package.json` と lockfile を変更して再ビルドする。
`dsh plugin add` は Nix 側の manifest と `node_modules` に書けず、書けても次の起動で戻るため使わない。

既定モデルは OpenCode Go の `minimax-m3`。`opencode auth login` で登録済みの
`opencode-go` のキーを起動時に読み込む。別のキーを使う場合は
`OPENCODE_GO_API_KEY` を実行時の環境変数で指定する。
Ollama Cloud は OpenCode と同じ `http://localhost:11434/v1` のローカルサーバー経由で使う。
Ollama にログインしてサーバーを起動しておく（通常は Ollama アプリ、CLI なら `ollama serve`）。
TensorFold は DGX Spark 4 台の `http://10.0.1.60:8000/v1` で DeepSeek V4.1 Flash 1017 を使う。
鍵は不要で、既定では考えない。`/effort low`、`medium`、`high`、`max` で考える強さを選べる。
TUI の `/model` で `OpenCode Go`、`Ollama Cloud (local proxy)`、`TensorFold (DGX Spark x4)` のいずれかを選び、
`s` でモデル一覧を開いて `Enter` で切り替える。選択はユーザーの profile patch に保存される。
ウェブ検索（`web_search`）は、npm の `dsh-web-search-searxng` で NAS の SearXNG `http://10.0.1.30:8888` を使う。
鍵は不要で、DeepSeek 公式の検索は使わない。宛先は起動時の環境変数 `SEARXNG_URL` で変えられる。
検索は `/search?format=json` を使うため、宛先の SearXNG は `settings.yml` の `search.formats` に `json` を含める
（含めないと 403 で失敗する。NAS の SearXNG は設定済み）。
この包みが対応を表明しているのは dsh 0.1.7-rc.2 までで、npm が依存を解決できないため、
npm を通さずに公開ファイルをハッシュで固定して置く。0.2.1-rc.2 で検索できることは確かめてある。
profile patch で `web` の行を上書きする場合は、`searchProvider: searxng` も書く。行の設定は丸ごと置き換わるため、
書かないと SearXNG が選ばれなくなる。
OpenAI Codex は ChatGPT のサブスクリプションに含まれる Codex の利用枠で接続する。
メールアドレスを指定して、それぞれの ChatGPT アカウントを登録する。

```bash
dsh-tui --login j5ik2o@gmail.com
dsh-tui --login junichi.kato@ideo-plus.jp
dsh-tui --accounts
dsh-tui --account j5ik2o@gmail.com
dsh-tui
```

macOS ではメールアドレスに対応する Chrome プロファイルを探してログイン画面を開く。
対応するプロファイルがない場合は、表示されたリンクを使用するブラウザーで開く。
ログイン時は指定したアカウントを確認する。別のアカウントに自動ログインされる場合は、
ブラウザーでログアウトしてから再実行する。
`--accounts` は登録済みの名前を表示し、選択中のアカウントに `*` を付ける。
`--account メールアドレス` で保存済みの認証を選び直せる。切り替え後は `dsh-tui` を起動し直す。
実行中のセッションは起動時のアカウントを使い続ける。
`--login` を名前なしで実行すると、選択中のアカウントの認証を更新する。
以前の名前なしの認証は、トークンのメールアドレス（取得できない場合は `default`）で自動移行する。
起動時に選択中のアカウントのモデル一覧を接続先から取得する。
`/model` には `OpenAI Codex (メールアドレス)` と、そのアカウントの表示対象モデルだけが出る。
一覧でモデルを選ぶと、チャットのモデル表示と次の推論に即座に反映される。会話の作り直しは不要。
推論強度は起動後に `/effort` で現在値と対応する値を確認し、`/effort high` や
`/effort xhigh` で変更できる。変更は次の推論から反映され、設定にも保存される。
`/effort default` は接続先の既定値に戻す。モデルを変更すると、推論強度も接続先の既定値に戻る。
`--account` またはログイン後の初回起動では Codex に切り替え、前のモデルが使えない場合は
接続先の優先順で最初のモデルを選ぶ。選択したモデルが利用可能ならそのまま使う。
モデル一覧の取得に失敗した場合は、古い固定一覧で起動せずエラーで終了する。
認証情報は `~/.dsh-tui/.credentials.yaml` にアカウントごとに保存され、ログイン画面とターミナル画面で共有する。
トークンは接続プラグインが更新するため、API キーや既存の Codex トークンのコピーは不要。
ログイン処理は認証情報の保存後に終了する。中止するときは `Ctrl+C` を押す。
利用上限は契約プランに従う（[OpenAI の認証説明](https://developers.openai.com/codex/auth)）。

OpenCode Go、Ollama、TensorFold の接続先・モデル一覧の既定値は `packages/dsh-tui-providers.yml` で管理する。
Codex の一覧はアカウントごとの `~/.dsh-tui/accounts/*/models.patch.json` に生成し、
起動時の追加設定として読み込む。ユーザーの他の設定とコメントは保持する。
追加設定は `llm-pi-ai` の設定を丸ごと置き換えるため、同梱の接続先と、利用者の接続先ごとの上書きも含めて生成する。

[OpenCode Go の接続仕様](https://opencode.ai/docs/go/)に合わせて、
全 API 形式の推論リクエストに会話ごとの `x-opencode-session` を付けるローカルパッチも適用する。
[Ollama の OpenAI 互換 API](https://docs.ollama.com/api/openai-compatibility)を使うため、
Ollama の認証やモデルのダウンロードを Nix ビルドで行う必要はない。

Nix 版 Node と dsh の native addon の既知の不具合は、`--expose-internals` と
app-boot のローカルパッチで回避する。ビルド時に API キーなしでバージョン・設定合成・help を検証する。

## シークレット管理 (chezmoi + 1Password)

SSH キーなどのシークレットは chezmoi + 1Password CLI で管理します。

### 仕組み

- **Nix**: パッケージ、システム設定、アプリ設定を管理
- **chezmoi**: シークレット（SSH キー、トークンなど）を管理
- **1Password**: シークレットの安全な保管場所

### 初回セットアップ

#### 1. 1Password CLI の設定

1Password アプリを開き、**設定 → 開発者 → 「1Password CLI と連携」** にチェック

```bash
# 動作確認
op vault list
```

#### 2. SSH キーを 1Password に登録（初回のみ）

既存の SSH キーがある場合：

```bash
op item create \
  --category=Login \
  --title="GitHub SSH" \
  --vault="Private" \
  "private_key[password]=$(cat ~/.ssh/id_rsa.github)" \
  "public_key[text]=$(cat ~/.ssh/id_rsa.github.pub)"
```

#### 3. chezmoi でシークレットを適用

```bash
# 初期化
make secrets-init

# 差分確認
make secrets-diff

# 適用（1Password から SSH キーを取得）
make secrets-apply
```

### 新しいマシンでのセットアップ

```bash
# 1. dotfiles を適用（chezmoi がインストールされる）
make init-darwin

# 2. 1Password アプリにログイン & CLI 連携を有効化

# 3. シークレットを適用
make secrets-init
make secrets-apply
```

これで SSH キーが `~/.ssh/` に展開されます。

### シークレットの追加

新しいシークレットを追加する場合：

1. 1Password にアイテムを追加
2. `chezmoi/` 以下にテンプレートファイルを作成

テンプレート例（`chezmoi/private_dot_ssh/private_id_rsa.github.tmpl`）：

```
{{ onepasswordRead "op://Private/GitHub SSH/private_key" }}
```

ファイル名の規則：
- `private_` プレフィックス: パーミッション 0600
- `dot_`: ファイル名の先頭を `.` に変換
- `.tmpl` サフィックス: テンプレートとして処理

## Makefile ターゲット一覧

```bash
make help
```

| ターゲット | 説明 |
|-----------|------|
| `init` | **初回のみ**: 初回セットアップ（OS自動判定） |
| `apply` | 設定を適用（macOS: darwin-rebuild, Linux: home-manager） |
| `rollback` | 前の世代にロールバック |
| `build` | ビルドのみ（dry-run） |
| `update` | flake inputs を更新 |
| `check` | flake check 実行 |
| `gc` | Nix ガベージコレクション |
| `nvim-clean` | Neovim キャッシュ削除 |
| `fmt` | Nix ファイルをフォーマット |
| `secrets-init` | chezmoi 初期化 |
| `secrets-diff` | シークレットの差分表示 |
| `secrets-apply` | シークレットを 1Password から適用 |

## 新しいマシンの追加

1. `flake.nix` に新しい `darwinConfigurations` を追加
2. ホスト名を設定に合わせる、または既存設定を使用

## ドキュメント

- [Neovim キーマップ (LazyVim)](docs/neovim.md)
- [Neovim LSP これだけ](docs/lsp.md)
- [Neovim Tree-sitter これだけ](docs/tree-sitter.md)
- [Neo-tree これだけ](docs/neo-tree.md)
- [chezmoi シークレット管理](docs/chezmoi.md)

## Neovim (LazyVim)

LazyVim ベースの設定。プラグイン管理は LazyVim に委譲し、Nix は外部ツール（LSP、フォーマッター等）のみ提供。

LazyVim (Nix-managed, default): `nvim` (also via `vi`, `vim`)

起動エイリアスは `modules/programs/shell.nix` に定義済み。

**主なカスタム:**
- ターミナル: `Space t 1-4` で番号付きターミナル / `Esc Esc` でターミナルモード終了
- Neo-tree Buffers の TERMINALS は既存ターミナルへフォーカス

詳細は [docs/neovim.md](docs/neovim.md) 参照。

## テーマ

テーマは各アプリの設定に準拠。Neovim は LazyVim の colorscheme 設定に従う。

## 注意事項

- `homebrew.onActivation.cleanup = "zap"` が設定されているため、`casks` リストにないアプリは削除されます
- 初回実行後、一部の設定は再ログインまたは再起動が必要です
# amadeus-dlc.github.io
