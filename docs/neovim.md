# Neovim キーマップ カンペ (AstroNvim)

AstroNvim ベースの設定。標準キーマップは公式ドキュメントと `:WhichKey` を参照。

## 起動エイリアス

複数ディストロを検証するため、`NVIM_APPNAME` で設定を分離しています。
起動エイリアスは `modules/programs/shell.nix` に定義済みです。

- Astro (default): `nvim` / `nva`
- NvChad: `nvc`
- LazyVim: `nvl`
- LazyVim (Nix-managed): `nvn`
- LunarVim: `nvr`

## 参照

- AstroNvim docs: https://docs.astronvim.com/
- WhichKey: `:WhichKey`
- LSP これだけ: `docs/lsp.md`
- Tree-sitter これだけ: `docs/tree-sitter.md`

## カスタム追加

### ターミナル

| キー | 動作 |
|------|------|
| `Esc Esc` | ターミナルモード終了 |
| `Space t 1` | ターミナル #1 |
| `Space t 2` | ターミナル #2 |
| `Space t 3` | ターミナル #3 |
| `Space t 4` | ターミナル #4 |

メモ:
- 直接コマンドなら `:2ToggleTerm` のように番号付きで開ける。

### ウィンドウサイズ調整

| キー | 動作 |
|------|------|
| `Space w h` | 幅 -2 |
| `Space w l` | 幅 +2 |
| `Space w j` | 高さ -2 |
| `Space w k` | 高さ +2 |
| `Space w =` | サイズ均等化 |

### Neo-tree Buffers

- Buffers の TERMINALS をクリックしても新規ペインは作られず、既存ターミナルへフォーカスする。

## nvim-nix-lazy (Nix 管理の LazyVim)

`NVIM_APPNAME=nvim-nix-lazy` 用の構成。LazyVim は維持しつつ、プラグイン本体は Home Manager
(`programs.neovim.plugins`) で Nix 管理する。

### 仕組み

- Nix で `vimPlugins` をリンクファーム化し、`NVIM_NIX_LAZY_PLUGIN_DIR` に設定
- `config/nvim-nix-lazy/lua/config/lazy.lua` が `dev.path` をこのディレクトリに固定
- `lazy.nvim` の自動インストール/更新は無効化（Nix 以外から取得しない）

### 起動

- `nvn` (alias) または `NVIM_APPNAME=nvim-nix-lazy nvim`

### プラグイン追加/更新

- 追加: `modules/programs/neovim.nix` の `nvimNixLazyPlugins` に追加
- 更新: `nix flake update` → `make apply`（または `home-manager switch`）

### トラブル時の確認

- `:Lazy` でプラグインが Nix 由来になっているか確認
- `NVIM_NIX_LAZY_PLUGIN_DIR` が設定されているか `:echo $NVIM_NIX_LAZY_PLUGIN_DIR` で確認
