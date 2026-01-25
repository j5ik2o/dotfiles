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
