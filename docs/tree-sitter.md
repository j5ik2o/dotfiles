# Tree-sitter これだけ知っておけばOK

## まず使うコマンド

- `:TSInstall <lang>`  
  例: `:TSInstall go`
- `:TSInstallInfo`  
  何が入っているか確認。
- `:TSUpdate`  
  まとめて更新。

## 迷ったらこれ

1) `:TSInstallInfo` で対象言語が入っているか確認  
2) 入ってなければ `:TSInstall <lang>`  
3) まだ変なら `:TSUpdate`

## このリポジトリの設定場所

- 追加インストール対象: `config/nvim-astro/lua/plugins/treesitter.lua`

## 主要キーバインド（Textobjects）

前提: Tree-sitter が有効なバッファでのみ有効。

### 選択（オブジェクト）

| キー | 動作 |
|------|------|
| `af` / `if` | function outer / inner |
| `ac` / `ic` | class outer / inner |
| `ak` / `ik` | block outer / inner |
| `ao` / `io` | loop outer / inner |
| `aa` / `ia` | parameter outer / inner |
| `a?` / `i?` | conditional outer / inner |

### 移動

| キー | 動作 |
|------|------|
| `]f` / `[f` | 次/前の function start |
| `]F` / `[F` | 次/前の function end |
| `]k` / `[k` | 次/前の block start |
| `]K` / `[K` | 次/前の block end |
| `]a` / `[a` | 次/前の parameter start |
| `]A` / `[A` | 次/前の parameter end |

### スワップ

| キー | 動作 |
|------|------|
| `>F` / `<F` | 次/前の function と入れ替え |
| `>K` / `<K` | 次/前の block と入れ替え |
| `>A` / `<A` | 次/前の parameter と入れ替え |

## 注意点（最低限）

- 一部言語はビルド時に依存が必要（C コンパイラ等）。
