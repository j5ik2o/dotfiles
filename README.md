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

## クリーンインストール (macOS)

### 1. Xcode Command Line Tools

```bash
xcode-select --install
```

### 2. Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

インストール後、表示される指示に従って PATH を設定：

```bash
# Apple Silicon Mac
eval "$(/opt/homebrew/bin/brew shellenv)"

# Intel Mac
eval "$(/usr/local/bin/brew shellenv)"
```

### 3. Nix

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
```

インストール後、シェルを再起動：

```bash
exec $SHELL
```

### 4. dotfiles クローン

```bash
mkdir -p ~/Sources
git clone https://github.com/j5ik2o/dotfiles.git ~/Sources/dotfiles
cd ~/Sources/dotfiles
```

### 5. 初回適用

```bash
make init-darwin
```

初回は `init-darwin` を使います。これにより：
- `/etc/nix/nix.conf`, `/etc/bashrc`, `/etc/zshrc` をバックアップ
- nix-darwin を初回セットアップ

初回は時間がかかります（Homebrew casks のダウンロードなど）。

### 6. 再起動

設定を完全に反映させるため、再起動またはログアウト→ログインしてください。

## 日常の使い方

### 設定を変更した後

```bash
make switch
```

### flake.lock を更新

```bash
make update
make switch
```

### ビルドだけ（適用しない）

```bash
make build
```

### ガベージコレクション

```bash
make gc
```

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
| `init-darwin` | **初回のみ**: nix-darwin 初回セットアップ |
| `switch` | 設定を適用（macOS: darwin-rebuild, Linux: home-manager） |
| `build` | ビルドのみ（dry-run） |
| `update` | flake inputs を更新 |
| `check` | flake check 実行 |
| `gc` | Nix ガベージコレクション |
| `fmt` | Nix ファイルをフォーマット |
| `secrets-init` | chezmoi 初期化 |
| `secrets-diff` | シークレットの差分表示 |
| `secrets-apply` | シークレットを 1Password から適用 |

## 新しいマシンの追加

1. `flake.nix` に新しい `darwinConfigurations` を追加
2. ホスト名を設定に合わせる、または既存設定を使用

## ドキュメント

- [Neovim キーマップ](docs/neovim.md)

## テーマ

すべて **Catppuccin Mocha** で統一：
- Neovim
- Ghostty
- WezTerm

## 注意事項

- `homebrew.onActivation.cleanup = "zap"` が設定されているため、`casks` リストにないアプリは削除されます
- 初回実行後、一部の設定は再ログインまたは再起動が必要です
