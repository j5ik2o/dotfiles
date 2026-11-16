# Telescope カンペ (LazyVim)

Telescope は「ファイル検索/grep/履歴/各種一覧」をまとめて開けるピッカー。
このリポジトリでは `<Leader>` は `Space`。

## まずはこれ

- `:Telescope` で一覧を開く
- `:Telescope builtin` でビルトイン一覧

## よく使うキー

### ファイル/バッファ

| キー | 動作 |
|------|------|
| `Space Space` | ファイル検索 (プロジェクトRoot) |
| `Space f f` | ファイル検索 (プロジェクトRoot) |
| `Space f F` | ファイル検索 (cwd) |
| `Space f g` | git 管理ファイル検索 |
| `Space f r` | 最近開いたファイル (Root) |
| `Space f R` | 最近開いたファイル (cwd) |
| `Space f c` | config ファイル検索 |
| `Space ,` | バッファ切替 (最近使用順) |
| `Space f b` | バッファ一覧 (現在バッファ除外) |
| `Space f B` | バッファ一覧 (全て) |

### Grep / 検索

| キー | 動作 |
|------|------|
| `Space /` | 文字列検索 (Root, live_grep) |
| `Space s g` | 文字列検索 (Root) |
| `Space s G` | 文字列検索 (cwd) |
| `Space s w` | カーソル下の単語検索 (Root) |
| `Space s W` | カーソル下の単語検索 (cwd) |
| `Space s b` | 現在バッファ内あいまい検索 |
| `Space s R` | 前回の検索を再開 |

ビジュアルモード:

| キー | 動作 |
|------|------|
| `Space s w` | 選択範囲を検索 (Root) |
| `Space s W` | 選択範囲を検索 (cwd) |

### 便利系

| キー | 動作 |
|------|------|
| `Space s d` | Diagnostics 全体 |
| `Space s D` | Diagnostics (現在バッファ) |
| `Space s s` | シンボル検索 (現在バッファ) |
| `Space s S` | シンボル検索 (ワークスペース) |
| `Space s h` | help tags |
| `Space s k` | keymaps |
| `Space s o` | vim options |
| `Space s q` | quickfix |
| `Space s l` | loclist |
| `Space s m` | marks |
| `Space s M` | man pages |
| `Space s "` | registers |
| `Space s c` | コマンド履歴 |
| `Space s C` | コマンド一覧 |
| `Space s a` | autocommands |

### Git

| キー | 動作 |
|------|------|
| `Space g c` | commits |
| `Space g l` | commits |
| `Space g s` | git status |
| `Space g S` | git stash |

## LSP と連携（Telescope 版）

| キー | 動作 |
|------|------|
| `g d` | 定義へ移動（Telescope） |
| `g I` | 実装へ移動（Telescope） |
| `g y` | 型定義へ移動（Telescope） |
| `g r` | 参照一覧（Telescope） |

## Telescope 内のキー

Insert mode:

| キー | 動作 |
|------|------|
| `<C-t>` / `<A-t>` | Trouble で開く |
| `<A-i>` | 無視ファイルも含めて再検索 |
| `<A-h>` | 隠しファイルも含めて再検索 |
| `<C-Up>` / `<C-Down>` | 履歴を移動 |
| `<C-b>` / `<C-f>` | プレビューをスクロール |

Normal mode:

| キー | 動作 |
|------|------|
| `q` | 閉じる |

Flash.nvim が有効なら:

| キー | 動作 |
|------|------|
| `s` / `<C-s>` | 結果へジャンプ |

## メモ

- Root は LazyVim のルート検出（LSP/`git`/`cwd`）に従う
- `Space f F` / `Space s G` / `Space s W` は `cwd` 基準
