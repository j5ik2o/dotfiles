# Neovim キーマップ カンペ (LazyVim)

LazyVim ベースの設定。標準キーマップは公式ドキュメントと `:WhichKey` を参照。

## 起動エイリアス

起動エイリアスは `modules/programs/shell.nix` に定義済みです。

- LazyVim (Nix-managed, default): `nvim` (also via `vi`, `vim`)

## 参照

- WhichKey: `:WhichKey`
- LSP これだけ: `docs/lsp.md`
- Tree-sitter これだけ: `docs/tree-sitter.md`
- Neo-tree これだけ: `docs/neo-tree.md`

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

### Diagnostics

コード中には表示せず、別ビューで確認する。

| キー | 動作 |
|------|------|
| `Space x x` | Diagnostics を Trouble で表示 |
| `Space x X` | 現在バッファの Diagnostics を Trouble で表示 |
| `Space x l` | Diagnostics を loclist に表示 |

### Neo-tree Buffers

- Buffers の TERMINALS をクリックしても新規ペインは作られず、既存ターミナルへフォーカスする。

### Copilot / Copilot Chat

`<Leader>` は `Space`。

**Copilot**

- 初回ログイン: `:Copilot auth`
- 状態確認: `:Copilot status`
- 次/前の提案: `Alt-]` / `Alt-[`

**Copilot Chat**

- 開閉: `Space a a`
- クイックチャット: `Space a q`
- クリア: `Space a x`
- プロンプト選択: `Space a p`
- 送信: `Ctrl-s`（チャットバッファ内）

## nvim (Nix 管理の LazyVim)

デフォルトの `~/.config/nvim` 用の構成。LazyVim は維持しつつ、プラグイン本体は Home Manager
(`programs.neovim.plugins`) で Nix 管理する。

### 仕組み

- Nix で `vimPlugins` をリンクファーム化し、`NVIM_PLUGIN_DIR` に設定
- `config/nvim/lua/config/lazy.lua` が `dev.path` をこのディレクトリに固定
- `lazy.nvim` の自動インストール/更新は無効化（Nix 以外から取得しない）

### 起動

- `nvim` (または `vi` / `vim`)

### プラグイン追加/更新

- 追加: `modules/programs/neovim.nix` の `nvimPlugins` に追加
- 更新: `nix flake update` → `make apply`（または `home-manager switch`）

### トラブル時の確認

- `:Lazy` でプラグインが Nix 由来になっているか確認
- `NVIM_PLUGIN_DIR` が設定されているか `:echo $NVIM_PLUGIN_DIR` で確認
