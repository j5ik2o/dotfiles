# Codebase Structure

## ディレクトリ構成
```
dotfiles/
├── flake.nix              # Nix Flake エントリポイント（全設定の起点）
├── flake.lock             # 依存関係のロックファイル
├── Makefile               # ビルド・適用・メンテナンスコマンド
├── darwin/                # nix-darwin (macOS) 設定
│   ├── default.nix        # darwin共通設定
│   ├── packages.nix       # macOS用パッケージ
│   ├── homebrew.nix       # Homebrew casks管理
│   ├── system-settings.nix # macOSシステム設定
│   └── hosts/             # ホスト固有のdarwin設定
├── hosts/                 # ホスト定義（ユーザー名、システム等）
│   ├── default.nix        # 全ホスト定義
│   ├── j5ik2o-mac-mini.nix
│   ├── j5ik2o-macbook-air.nix
│   └── ...
├── modules/               # Home Manager モジュール
│   ├── common.nix         # 共通設定・パッケージ
│   ├── darwin.nix         # macOS固有設定
│   ├── linux.nix          # Linux固有設定
│   ├── dotfiles.nix       # dotfiles optionsの定義
│   ├── user-info.nix      # ユーザー情報
│   └── programs/          # プログラム別設定
│       ├── neovim.nix     # Neovim
│       ├── zsh.nix        # zsh
│       ├── git.nix        # Git
│       ├── starship.nix   # Starship prompt
│       ├── ghostty.nix    # Ghostty terminal
│       ├── tmux.nix       # tmux
│       └── ...
├── config/                # アプリ設定ファイル
│   ├── nvim/              # Neovim Lua設定 (LazyVim)
│   ├── codex/             # Codex設定
│   ├── cliproxyapi/       # CLIProxyAPI設定
│   └── opencode/          # opencode設定
├── packages/              # カスタムNixパッケージ定義
│   ├── gwq.nix
│   ├── cliproxyapi.nix
│   ├── claude-code-acp.nix
│   └── takt.nix
├── chezmoi/               # シークレット管理 (1Password連携)
├── scripts/               # セットアップスクリプト
└── docs/                  # ドキュメント
```

## 設定の階層
1. `flake.nix` → 全体のエントリポイント、ホスト/ユーザーの組み合わせを生成
2. `hosts/*.nix` → ホスト定義（ユーザー名、システム、features）
3. `darwin/` → macOS固有のシステム設定
4. `modules/common.nix` → 全環境共通のパッケージ・設定
5. `modules/darwin.nix` / `modules/linux.nix` → OS別設定
6. `modules/programs/*.nix` → 各プログラムの個別設定
