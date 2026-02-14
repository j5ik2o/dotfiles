# Project Overview: dotfiles

## 目的
j5ik2oの個人dotfiles管理プロジェクト。Nix Flakes + Home Manager + nix-darwin を使い、macOS/Linux の開発環境を宣言的に構成する。

## 技術スタック
- **Nix Flakes**: パッケージ管理・環境構成の基盤
- **Home Manager**: ユーザー環境管理（シェル、エディタ、ツール設定）
- **nix-darwin**: macOSシステムレベル設定（Homebrew casks、システム設定含む）
- **chezmoi + 1Password**: シークレット管理（SSHキー等）
- **Neovim (LazyVim)**: エディタ（プラグインはNix管理、設定はLua）
- **zsh + sheldon + starship**: シェル環境

## 対応プラットフォーム
- macOS (aarch64-darwin, x86_64-darwin)
- Linux (x86_64-linux, aarch64-linux)

## Flake Inputs
- nixpkgs (unstable)
- home-manager
- nix-darwin
- nix-clawdbot
- catppuccin (テーマ)

## 個人プロジェクトのルール
- 破壊的変更を許容する（後方互換性を維持しない）
- `make gc` しても既存環境に悪影響がないようにする
- 日本語で応対すること
