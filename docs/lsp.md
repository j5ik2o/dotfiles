# LSP これだけ知っておけばOK

## まず使うコマンド

- `:LspInfo`  
  いま開いているファイルで LSP が動いているか確認。
- `:Mason`  
  LSP サーバのインストール/更新。
- `:LspRestart`  
  LSP が怪しいときの再起動。

## 迷ったらこれ

1) `:LspInfo` でアタッチ確認  
2) 付いてなければ `:Mason` で該当サーバを入れる  
3) 直らなければ `:LspRestart`

## このリポジトリの設定場所

- LSP サーバの有効化: `config/nvim/lua/plugins/astrolsp.lua`
- Mason の自動インストール: `config/nvim/lua/plugins/mason.lua`

## 主要キーバインド（AstroNvim デフォルト）

前提: LSP がアタッチされたときのみ有効。`<Leader>` は `Space`。
`gd` / `gD` など **g で始まるものは Leader 不要**（ノーマルモードで `g` → `d` の順に押す）。

### 参照・移動

| キー | 動作 |
|------|------|
| `gd` | 定義へ移動 |
| `gD` | 宣言へ移動 |
| `gy` | 型定義へ移動 |
| `<Leader>lR` | 参照一覧 |
| `<Leader>lG` | ワークスペースシンボル検索 |

### 編集・補助

| キー | 動作 |
|------|------|
| `<Leader>la` | コードアクション |
| `<Leader>lA` | ソースアクション |
| `<Leader>lr` | リネーム |
| `<Leader>lf` | フォーマット（バッファ） |
| `gK` / `<Leader>lh` | シグネチャヘルプ |

### トグル系

| キー | 動作 |
|------|------|
| `<Leader>uf` | 自動フォーマット（バッファ） |
| `<Leader>uF` | 自動フォーマット（全体） |
| `<Leader>uL` | CodeLens トグル |
| `<Leader>uh` | Inlay Hints（バッファ） |
| `<Leader>uH` | Inlay Hints（全体） |
| `<Leader>uY` | Semantic Tokens（バッファ） |

### ビジュアルモード

| キー | 動作 |
|------|------|
| `<Leader>la` | コードアクション |
| `<Leader>lf` | 範囲フォーマット |

## 注意点（最低限）

- Lean4 は Mason では入らない。`elan`/`lake` が必要。
- JDK が必要なサーバ（例: Java, Scala/Metals）は `java` が PATH にあること。
