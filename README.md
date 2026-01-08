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

### 5. 適用

```bash
make switch
```

初回は時間がかかります（Homebrew casks のダウンロードなど）。

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

## Makefile ターゲット一覧

```bash
make help
```

| ターゲット | 説明 |
|-----------|------|
| `switch` | 設定を適用（macOS: darwin-rebuild, Linux: home-manager） |
| `build` | ビルドのみ（dry-run） |
| `update` | flake inputs を更新 |
| `check` | flake check 実行 |
| `gc` | Nix ガベージコレクション |
| `fmt` | Nix ファイルをフォーマット |

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
