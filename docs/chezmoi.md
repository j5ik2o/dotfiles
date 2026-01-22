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
├── .chezmoi.toml.tmpl           # chezmoi 設定
├── .chezmoiignore               # 無視するファイル
└── private_dot_ssh/             # ~/.ssh/ にマッピング
    ├── private_id_rsa.github.tmpl    # 秘密鍵テンプレート
    └── id_rsa.github.pub.tmpl        # 公開鍵テンプレート
```

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
private_id_rsa.github.tmpl            →   id_rsa.github (mode 0600)
id_rsa.github.pub.tmpl                →   id_rsa.github.pub
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
{{ onepasswordRead "op://Private/GitHub SSH/private_key" }}
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
chezmoi diff ~/.ssh/id_rsa.github

# テンプレートの展開結果を確認
chezmoi execute-template < chezmoi/private_dot_ssh/private_id_rsa.github.tmpl
```

## 1Password 連携

### 前提条件

1. 1Password アプリがインストール済み
2. 1Password CLI (`op`) がインストール済み
3. アプリで「CLI との統合」が有効

### アイテムの追加

```bash
# SSH キーを追加
op item create \
  --category=Login \
  --title="GitHub SSH" \
  --vault="Private" \
  "private_key[password]=$(cat ~/.ssh/id_rsa.github)" \
  "public_key[text]=$(cat ~/.ssh/id_rsa.github.pub)"
```

### URI 形式

```
op://Vault名/アイテム名/フィールド名
```

例:
- `op://Private/GitHub SSH/private_key`
- `op://Personal/AWS Credentials/access_key_id`

### フィールド名の確認

```bash
op item get "GitHub SSH" --vault="Private"
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
.config/nvim-astro
.config/nvim-nvchad
.config/nvim-lazy
.config/nvim-lunar
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
chezmoi diff ~/.ssh/id_rsa.github
```

## 参考リンク

- [chezmoi 公式ドキュメント](https://www.chezmoi.io/)
- [chezmoi + 1Password](https://www.chezmoi.io/user-guide/password-managers/1password/)
- [1Password CLI](https://developer.1password.com/docs/cli/)
