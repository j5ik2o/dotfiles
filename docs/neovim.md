# Neovim キーマップ カンペ (LazyVim)

> LazyVim ベースの設定。詳細は https://www.lazyvim.org/keymaps 参照

## 基本操作

| キー | 動作 |
|------|------|
| `Space` | Leader キー |
| `Space w` | 保存 (LazyVim) |
| `Space q q` | 全終了 (:qa) |
| `:qa!` | 全終了（強制・保存なし） |
| `Esc` | 検索ハイライト解除 |

## ウィンドウ操作

| キー | 動作 |
|------|------|
| `Ctrl+h/j/k/l` | ウィンドウ移動（左/下/上/右） |
| `Ctrl+↑/↓/←/→` | ウィンドウリサイズ |
| `Space w -` | 水平分割 |
| `Space w |` | 垂直分割 |
| `Space w d` | ウィンドウ削除 |
| `Space w h/l` | ウィンドウ幅 -2/+2 (カスタム) |
| `Space w j/k` | ウィンドウ高さ -2/+2 (カスタム) |
| `Space w =` | ウィンドウサイズ均等化 (カスタム) |

## バッファ操作

| キー | 動作 |
|------|------|
| `Space ,` | バッファ一覧 (Telescope) |
| `Space f b` | バッファ検索 (Telescope) |
| `Space b b` | 直前のバッファに切り替え |
| `Shift+h` | 前のバッファ |
| `Shift+l` | 次のバッファ |
| `Space b d` | バッファ削除 |
| `Space b D` | 他のバッファを全削除 |
| `Space b p` | バッファをピン |

## ファイル検索 (Telescope)

| キー | 動作 |
|------|------|
| `Space Space` | ファイル検索 (root) |
| `Space f f` | ファイル検索 (root) |
| `Space f F` | ファイル検索 (cwd) |
| `Space /` | 文字列検索 (grep) |
| `Space s g` | 文字列検索 (grep) |
| `Space f r` | 最近開いたファイル |
| `Space s h` | ヘルプ検索 |
| `Space s t` | TODO検索 |
| `Space s s` | シンボル検索 |
| `Space s S` | ワークスペースシンボル |

## ファイルエクスプローラー (Neo-tree)

| キー | 動作 |
|------|------|
| `Space e` | Neo-tree トグル (root) |
| `Space E` | Neo-tree トグル (cwd) |
| `Space f e` | Neo-tree (root) |
| `Space f E` | Neo-tree (cwd) |

### Neo-tree 内操作

| キー | 動作 |
|------|------|
| `Enter` / `o` | 開く / 展開 |
| `s` | 垂直分割で開く |
| `S` | 水平分割で開く |
| `a` | 新規作成 |
| `d` | 削除 |
| `r` | リネーム |
| `y` | コピー |
| `x` | カット |
| `p` | ペースト |
| `R` | リフレッシュ |
| `?` | ヘルプ |

## ターミナル

### 基本操作 (LazyVim)

| キー | 動作 |
|------|------|
| `Ctrl+/` | ターミナル トグル (root) |
| `Ctrl+_` | ターミナル トグル (root) |
| `Space f t` | ターミナル (root) |
| `Space f T` | ターミナル (cwd) |
| `Esc Esc` | ターミナルモード終了 |

### 複数ターミナル (toggleterm)

| キー | 動作 |
|------|------|
| `Ctrl+\` | ターミナル トグル |
| `Space t f` | フローティングターミナル |
| `Space t h` | 水平ターミナル |
| `Space t v` | 垂直ターミナル |
| `Space t 1` | ターミナル #1 |
| `Space t 2` | ターミナル #2 |
| `Space t 3` | ターミナル #3 |
| `Space t 4` | ターミナル #4 |
| `Space t S` | ターミナル選択 |
| `Space t N` | ターミナル名変更 |
| `Space t a` | 全ターミナル トグル |

### ターミナルからのウィンドウ移動

| キー | 動作 |
|------|------|
| `Ctrl+h` | 左ウィンドウへ |
| `Ctrl+j` | 下ウィンドウへ |
| `Ctrl+k` | 上ウィンドウへ |
| `Ctrl+l` | 右ウィンドウへ |

## Git

### Lazygit

| キー | 動作 |
|------|------|
| `Space g g` | Lazygit (root) |
| `Space g G` | Lazygit (cwd) |
| `Space g l` | Lazygit ログ |
| `Space g f` | Lazygit 現在ファイル履歴 |

### Gitsigns (hunk 操作)

| キー | 動作 |
|------|------|
| `]h` | 次の hunk へ |
| `[h` | 前の hunk へ |
| `Space g h s` | hunk をステージ |
| `Space g h r` | hunk をリセット |
| `Space g h S` | バッファ全体をステージ |
| `Space g h u` | ステージ取り消し |
| `Space g h R` | バッファ全体をリセット |
| `Space g h p` | hunk をプレビュー |
| `Space g h b` | 行の blame 表示 |
| `Space g h B` | blame バッファ |

## 診断

| キー | 動作 |
|------|------|
| `Space x x` | 診断一覧 (Trouble) |
| `Space x X` | バッファ診断 |
| `Space x L` | Location List |
| `Space x Q` | Quickfix List |
| `Space c d` | 行の診断表示 |
| `[d` | 前の診断へ |
| `]d` | 次の診断へ |
| `[e` | 前のエラーへ |
| `]e` | 次のエラーへ |
| `[w` | 前の警告へ |
| `]w` | 次の警告へ |

## LSP (コード操作)

| キー | 動作 |
|------|------|
| `gd` | 定義へジャンプ |
| `gr` | 参照一覧 |
| `gI` | 実装へジャンプ |
| `gy` | 型定義へジャンプ |
| `gD` | 宣言へジャンプ |
| `K` | ホバー（ドキュメント表示） |
| `gK` | シグネチャヘルプ |
| `Space c r` | リネーム |
| `Space c a` | コードアクション |
| `Space c f` | フォーマット |
| `Space c l` | Lsp Info |
| `Space c R` | Rust アクション (Rust) |

## 高速移動 (flash.nvim)

| キー | 動作 |
|------|------|
| `s` | Flash ジャンプ |
| `S` | Flash Treesitter |
| `r` | Remote Flash (Operator-pending) |
| `R` | Treesitter Search |
| `Ctrl+s` | Toggle Flash Search |

## コメント

| キー | 動作 |
|------|------|
| `gc` | コメントトグル (行) |
| `gcc` | 現在行をコメント |
| `gco` | 下に行追加してコメント |
| `gcO` | 上に行追加してコメント |
| `gcA` | 行末にコメント追加 |

## サラウンド (mini.surround)

| キー | 動作 |
|------|------|
| `gsa` | サラウンド追加 |
| `gsd` | サラウンド削除 |
| `gsr` | サラウンド変更 |
| `gsf` | 関数呼び出しを検索 |
| `gsh` | 左右のサラウンドをハイライト |
| `gsn` | 隣接行数を更新 |

例: `gsa iw"` → 単語を `"` で囲む

## 編集

| キー | 動作 |
|------|------|
| `Alt+j` | 行を下に移動 |
| `Alt+k` | 行を上に移動 |
| `<` (Visual) | インデント減（維持） |
| `>` (Visual) | インデント増（維持） |

## Treesitter

| キー | 動作 |
|------|------|
| `Ctrl+Space` | 選択開始/拡大 |
| `Backspace` | 選択縮小 |

## UI トグル

| キー | 動作 |
|------|------|
| `Space u f` | 自動フォーマット トグル |
| `Space u s` | スペリング トグル |
| `Space u w` | ワードラップ トグル |
| `Space u l` | 行番号 トグル |
| `Space u L` | 相対行番号 トグル |
| `Space u d` | 診断 トグル |
| `Space u c` | conceal トグル |
| `Space u h` | インレイヒント トグル |
| `Space u n` | 通知 トグル |

## which-key

| キー | 動作 |
|------|------|
| `Space` を押して待つ | キーマップヘルプ表示 |

## Leader キーグループ一覧 (LazyVim)

| プレフィックス | グループ |
|---------------|---------|
| `Space f` | Find/File |
| `Space b` | Buffer |
| `Space c` | Code |
| `Space g` | Git |
| `Space s` | Search |
| `Space t` | Terminal (toggleterm) |
| `Space u` | UI |
| `Space w` | Window |
| `Space x` | Diagnostics/Quickfix |
| `Space q` | Quit/Session |
| `Space <tab>` | Tab |

## VS Code風 IDE レイアウト

```
+------------+------------------------+
|            |                        |
|  Neo-tree  |       Editor           |
|  (Space e) |                        |
|            +------------------------+
|            |  Terminal (Ctrl+\)     |
+------------+------------------------+
```

### クイックセットアップ

1. `Space e` → Neo-tree を開く（左パネル固定）
2. `Ctrl+\` → 下部にターミナル（toggleterm）
3. `Ctrl+h/l` でパネル間移動
4. `Space g g` → Lazygit でコミット

### 複数ターミナル活用

1. `Space t 1` → ターミナル #1 を開く
2. `Space t 2` → ターミナル #2 を開く（別プロセス用）
3. `Space t S` → ターミナル選択で切り替え
4. `Space t a` → 全ターミナルを一括トグル

### Git ワークフロー

1. `Space g g` → Lazygit を開く（フル画面）
2. `]h` / `[h` → hunk 間を移動
3. `Space g h s` → hunk をステージ
4. `Space g h p` → hunk をプレビュー

## Rust 開発 (extras.lang.rust)

| キー | 動作 |
|------|------|
| `Space c R` | Rust アクション |
| `K` | rust-analyzer ホバー |

Cargo.toml 内:
| キー | 動作 |
|------|------|
| `Space c c` | crates.nvim アクション |

## 追加情報

- LazyVim 公式キーマップ: https://www.lazyvim.org/keymaps
- LazyVim Extras: https://www.lazyvim.org/extras
