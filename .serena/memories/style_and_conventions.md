# Style and Conventions

## 言語・ファイル形式
- **Nix**: 主要言語。全設定を `.nix` ファイルで記述
- **Lua**: Neovim設定 (`config/nvim/`)
- **エンコーディング**: UTF-8
- **フォーマッター**: `nixfmt`（`nixfmt-rfc-style` は `nixfmt` に統合済み）

## Nixコーディングスタイル
- `nixfmt` でフォーマット（`make fmt`）
- コメントは日本語でセクション区切りに使用（例: `# ============================================================`）
- モジュール構成: 1ファイル1プログラム（`modules/programs/` 配下）
- `with pkgs;` パターンでパッケージリストを記述

## 設計パターン
- **宣言的構成**: 全設定はNix式で宣言的に記述
- **ホスト別設定**: `hosts/*.nix` でホスト固有のパラメータを定義
- **feature flags**: `dotfiles.features.clawdbot` のようなオプションでホスト別に機能を切り替え
- **overlay**: カスタムパッケージは `customOverlay` で追加
- **共通→OS別→ホスト別**: の順で設定をマージ

## 重要な注意事項
- `nixfmt-rfc-style` ではなく `nixfmt` を使うこと
- 使わない機能は設定しない（「あったほうがいいかも」で足さない）
- Neovimプラグインは Nix で管理（Home Managerの `programs.neovim.plugins`）
- Homebrew は `cleanup = "zap"` のため、casksリストにないアプリは削除される
