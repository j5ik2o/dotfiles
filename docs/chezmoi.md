# chezmoi シークレット管理

chezmoi + 1Password によるシークレット管理の詳細ドキュメント。

## 概要

```
Nix/home-manager  →  パッケージ、システム設定、アプリ設定
chezmoi           →  シークレット（SSH キー、トークンなど）
1Password         →  シークレットの安全な保管場所
```

## ディレクトリ構造

```
dotfiles/chezmoi/
├── .chezmoi.toml.tmpl              # chezmoi 設定
├── .chezmoiignore                  # 無視するファイル
└── private_dot_ssh/                # ~/.ssh/ にマッピング
    ├── private_config.tmpl         # ~/.ssh/config (mode 0600)
    ├── private_id_rsa_github.tmpl  # 秘密鍵 (mode 0600)
    ├── id_rsa_github.pub.tmpl      # 公開鍵 (mode 0644)
    ├── private_id_ed25519_dgx.tmpl
    ├── id_ed25519_dgx.pub.tmpl
    └── ...                         # 他の鍵も同じ規則
```

## 管理している鍵

| 鍵ファイル | 用途 | 1Password アイテム |
|---|---|---|
| `id_rsa_github` | 個人 GitHub (`j5ik2o.github.com`) | `SSH id_rsa_github` |
| `id_rsa_precena` | 法人 GitHub (`precena.github.com`) | `SSH id_rsa_precena` |
| `id_ed25519_reg9phak` | GitHub (`reg9phak.github.com`) | `SSH id_ed25519_reg9phak` |
| `id_ed25519_lan` | 自宅 LAN (`vega-nas`, `softether-vpn`, LAN 内の Mac) | `SSH id_ed25519_lan` |
| `id_ed25519_dgx` | DGX Spark / CRS (`spark1`〜`spark4`, `crs812`) | `SSH id_ed25519_dgx` |
| `id_ed25519_forgejo` | Forgejo (`forgejo`) | `SSH id_ed25519_forgejo` |
| `google_compute_engine` | gcloud の既定鍵 | `SSH google_compute_engine` |

ホストを追加するときは `private_config.tmpl` を編集します。鍵を追加するときは 1Password に `SSH <ファイル名>` の項目を作り、秘密鍵と公開鍵のテンプレートを追加します。

## ~/.ssh の整理方針

- 鍵ファイル名は `id_<種別>_<用途>` に統一する（例: `id_ed25519_dgx`, `id_rsa_github`）。
- `~/.ssh/config` も chezmoi が生成する。ホストの追加・変更は `private_config.tmpl` で行う。
- 使わなくなった鍵やバックアップは削除せず、`~/.ssh/archive/<日時>/` に退避する。
- 秘密鍵を改名すると、macOS の Keychain に保存されたパスフレーズは新しいパスに関連付かない。初回の SSH で一度だけパスフレーズを聞かれるので、入力すれば `UseKeychain` により再保存される。
- `id_ed25519_reg9phak` と `id_rsa_precena` はパスフレーズ付きのため、`BatchMode` では検証できない。対話で一度接続して確認する。

## 命名規則

chezmoi は**ファイル名の命名規則**でターゲットパスと属性を決定します。設定ファイルは不要です。

### プレフィックス

| プレフィックス | 効果 |
|--------------|------|
| `dot_` | `.` に変換（例: `dot_ssh` → `.ssh`） |
| `private_` | パーミッション 0600 (ファイル) / 0700 (ディレクトリ) |
| `empty_` | 空ファイルを作成 |
| `executable_` | 実行可能フラグを設定 |
| `readonly_` | 読み取り専用 |
| `symlink_` | シンボリックリンクを作成 |

### サフィックス

| サフィックス | 効果 |
|-------------|------|
| `.tmpl` | テンプレートとして処理（サフィックスは除去） |
| `.literal` | そのまま配置（テンプレート処理なし） |

### 変換例

```
ソース                                    ターゲット
──────────────────────────────────────────────────────────────
private_dot_ssh/                      →   ~/.ssh/ (mode 0700)
private_id_rsa_github.tmpl            →   id_rsa_github (mode 0600)
id_rsa_github.pub.tmpl                →   id_rsa_github.pub
private_config.tmpl                   →   config (mode 0600)
dot_config/private_dot_gitconfig      →   ~/.config/.gitconfig (mode 0600)
executable_dot_local/bin/myscript     →   ~/.local/bin/myscript (executable)
```

## テンプレート構文

chezmoi は Go テンプレートを使用します。

### 1Password からの読み取り

```
{{ onepasswordRead "op://Vault/Item/Field" }}
```

例:
```
{{ onepasswordRead "op://Private/SSH id_rsa_github/private_key" }}
```

### 条件分岐

```
{{ if eq .chezmoi.os "darwin" }}
# macOS 固有の設定
{{ else if eq .chezmoi.os "linux" }}
# Linux 固有の設定
{{ end }}
```

### 変数の使用

`.chezmoi.toml.tmpl` で定義した変数を使用:

```toml
# .chezmoi.toml.tmpl
[data]
  name = "j5ik2o"
  email = "j5ik2o@gmail.com"
```

```
# テンプレート内で使用
Git user: {{ .name }} <{{ .email }}>
```

### 組み込み変数

| 変数 | 説明 |
|-----|------|
| `.chezmoi.os` | OS 名 (`darwin`, `linux`, `windows`) |
| `.chezmoi.arch` | アーキテクチャ (`amd64`, `arm64`) |
| `.chezmoi.hostname` | ホスト名 |
| `.chezmoi.username` | ユーザー名 |
| `.chezmoi.homeDir` | ホームディレクトリ |

## コマンド

### 基本操作

```bash
# 初期化（dotfiles/chezmoi をソースとして使用）
make secrets-init

# 差分確認
make secrets-diff

# 適用
make secrets-apply
```

### 直接 chezmoi を使う場合

```bash
# ソースディレクトリを指定して実行
chezmoi --source=~/Sources/dotfiles/chezmoi apply

# 特定ファイルの差分
chezmoi diff ~/.ssh/id_rsa_github

# テンプレートの展開結果を確認
chezmoi execute-template < chezmoi/private_dot_ssh/private_id_rsa_github.tmpl
```

## 1Password 連携

### 前提条件

1. 1Password アプリがインストール済み
2. 1Password CLI (`op`) がインストール済み
3. アプリで「CLI との統合」が有効

### アイテムの追加

鍵ファイルを 1Password に登録します。値は `jq` で読み込み、シェルの履歴や引数に秘密鍵を残さないようにします。chezmoi は `op read --no-newline` を使うため、末尾改行はあらかじめ取り除きます。

```bash
tmp=$(mktemp); chmod 600 "$tmp"
jq -n \
  --arg title "SSH id_ed25519_example" \
  --rawfile priv ~/.ssh/id_ed25519_example \
  --rawfile pub ~/.ssh/id_ed25519_example.pub \
  '{title:$title, category:"LOGIN", vault:{name:"Private"}, fields:[
     {id:"private_key", label:"private_key", type:"CONCEALED", value:($priv|rtrimstr("\n"))},
     {id:"public_key",  label:"public_key",  type:"STRING",     value:($pub |rtrimstr("\n"))}]}' > "$tmp"
op item create --template "$tmp"
rm -f "$tmp"
```

### URI 形式

```
op://Vault名/アイテム名/フィールド名
```

例:
- `op://Private/SSH id_rsa_github/private_key`
- `op://Private/SSH id_ed25519_dgx/public_key`
- `op://Personal/AWS Credentials/access_key_id`

### フィールド名の確認

```bash
op item get "SSH id_rsa_github" --vault="Private"
```

## 新しいシークレットの追加

### 1. 1Password にアイテムを追加

```bash
op item create \
  --category=Login \
  --title="My Secret" \
  --vault="Private" \
  "api_key[password]=your-secret-value"
```

### 2. テンプレートファイルを作成

```bash
# 例: ~/.config/myapp/config にシークレットを含む設定を配置
mkdir -p chezmoi/dot_config/myapp
```

`chezmoi/dot_config/myapp/config.tmpl`:
```
api_key = "{{ onepasswordRead "op://Private/My Secret/api_key" }}"
```

### 3. 適用

```bash
make secrets-diff   # 確認
make secrets-apply  # 適用
```

## .chezmoiignore

Nix で管理しているファイルは chezmoi で管理しないよう除外:

```
# Nix で管理しているファイル
.config/zsh
.config/fish
.config/starship.toml
.config/git
.config/sheldon
.config/wezterm
.config/ghostty
.config/nvim
.config/helix

# OS 固有
.DS_Store
```

## トラブルシューティング

### 1Password 認証エラー

```
error: exec: "op": executable file not found in $PATH
```

→ `darwin-rebuild switch --flake .` で 1password-cli をインストール

### テンプレートエラー

```bash
# テンプレートの文法チェック
chezmoi execute-template < path/to/template.tmpl
```

### 差分が大きすぎる

```bash
# 特定ファイルのみ確認
chezmoi diff ~/.ssh/id_rsa_github
```

## 参考リンク

- [chezmoi 公式ドキュメント](https://www.chezmoi.io/)
- [chezmoi + 1Password](https://www.chezmoi.io/user-guide/password-managers/1password/)
- [1Password CLI](https://developer.1password.com/docs/cli/)

<!-- review-thread-gate test: このPRはマージしない -->
