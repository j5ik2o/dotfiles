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

### macOS

#### 1. Xcode Command Line Tools

```bash
xcode-select --install
```

#### 2. Homebrew

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

#### 3. Nix

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
```

インストール後、シェルを再起動：

```bash
exec $SHELL
```

#### 4. dotfiles クローン

```bash
mkdir -p ~/Sources
cd ~/Sources
git clone git@github.com/j5ik2o/dotfiles.git
cd dotfiles
```

#### 5. 初回適用

```bash
make init
```

これにより：
- `/etc/nix/nix.conf`, `/etc/bashrc`, `/etc/zshrc` をバックアップ
- nix-darwin を初回セットアップ

初回は時間がかかります（Homebrew casks のダウンロードなど）。

#### 6. デフォルトシェルの変更（手動）

```bash
chsh -s /run/current-system/sw/bin/zsh
```

#### 7. 再起動

設定を完全に反映させるため、再起動またはログアウト→ログインしてください。

### Linux (Ubuntu/Debian)

#### 1. 前提パッケージ

```bash
sudo apt update
sudo apt install -y curl git xz-utils
```

#### 2. Nix

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
```

インストール後、シェルを再起動：

```bash
exec $SHELL
```

#### 3. dotfiles クローン

```bash
mkdir -p ~/Sources
cd ~/Sources
git clone git@github.com/j5ik2o/dotfiles.git
cd dotfiles
```

#### 4. 初回適用

```bash
make init
```

これにより Home Manager が初回セットアップされます。

#### 5. デフォルトシェルの変更（手動）

```bash
sudo sh -c "echo $HOME/.nix-profile/bin/zsh >> /etc/shells"
chsh -s $HOME/.nix-profile/bin/zsh
```

#### 6. シェル再起動

```bash
exec $SHELL
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

- [Neovim キーマップ (AstroNvim)](docs/neovim.md)
- [Neovim LSP これだけ](docs/lsp.md)
- [Neovim Tree-sitter これだけ](docs/tree-sitter.md)
- [chezmoi シークレット管理](docs/chezmoi.md)

## Neovim (AstroNvim)

AstroNvim ベースの設定。プラグイン管理は AstroNvim に委譲し、Nix は外部ツール（LSP、フォーマッター等）のみ提供。
edgy は使用しない。

複数ディストロを検証するため、`NVIM_APPNAME` で設定を分離。
- Astro (default): `nvim` / `nva`
- NvChad: `nvc`
- LazyVim: `nvl`
- LazyVim (Nix-managed): `nvn`
- LunarVim: `nvr`

起動エイリアスは `modules/programs/shell.nix` に定義済み。

**主なカスタム:**
- ターミナル: `Space t 1-4` で番号付きターミナル / `Esc Esc` でターミナルモード終了
- ウィンドウサイズ調整: `Space w h/l/j/k`, `Space w =`
- Neo-tree Buffers の TERMINALS は既存ターミナルへフォーカス

詳細は [docs/neovim.md](docs/neovim.md) 参照。

## テーマ

テーマは各アプリの設定に準拠。Neovim は AstroNvim の colorscheme 設定に従う。

## 注意事項

- `homebrew.onActivation.cleanup = "zap"` が設定されているため、`casks` リストにないアプリは削除されます
- 初回実行後、一部の設定は再ログインまたは再起動が必要です
