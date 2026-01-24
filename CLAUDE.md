# Dotfiles Project Notes

## Nix

### パッケージ名の注意
- `nixfmt-rfc-style` は `nixfmt` に統合された。`nixfmt` を使うこと

### 仕組み
- nixpkgsはある時点のパッケージセット全体のスナップショット
- 特定パッケージだけバージョンアップは標準ではできない
- 同じflake.lockなら同じ環境が再現される

### flake inputs
- `nix flake update` で全inputs更新
- `nix flake update nixpkgs` で特定inputだけ更新

### ワークフロー
- `make update` → `make apply` → 問題あれば `make rollback`

## Neovim

### LazyVim
- LazyVim 本体はプラグイン側で管理され、直接編集しない
- 設定は `config/nvim` を正とする（`~/.config/nvim` へ同期）

### キャッシュ
- `make nvim-clean` で以下を削除:
  - `~/.local/share/nvim`
  - `~/.local/state/nvim`
  - `~/.cache/nvim`
- nix設定変更後、キャッシュ破棄が必要な場合あり

### 不要な設定を入れない
- 使わない機能は設定しない（marksman, markdownlintなど）
- 「あったほうがいいかも」で足さない

### 追加カスタム
- ターミナル: `Esc Esc` でターミナルモード終了、`Space t 1-4` で番号付きターミナル
- Neo-tree Buffers の TERMINALS は既存ターミナルへフォーカス
