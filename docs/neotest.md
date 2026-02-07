# Neotest これだけ

Neovim 内でテストを実行・結果表示・ジャンプまでできる。
`<Leader>` は `Space`。

## 主要キーマップ

| キー | 動作 |
|------|------|
| `Space t r` | 近いテストを実行 |
| `Space t t` | 現在ファイルのテストを実行 |
| `Space t T` | ワークスペース全体のテストを実行 |
| `Space t l` | 直前のテストを再実行 |
| `Space t s` | Summary を開閉 |
| `Space t o` | 失敗テストの出力を表示 |
| `Space t O` | Output Panel を開閉 |
| `Space t S` | テスト停止 |
| `Space t w` | watch のトグル |
| `Space t a` | テストにアタッチ |

## 対応アダプタ（このリポジトリ）

- Python: `neotest-python`（pytest / unittest）
- Rust: `rustaceanvim.neotest`
- Go: `neotest-go`
- Java: `neotest-java`
- Scala: `neotest-scala`

## 注意点

- 実行コマンドは各言語ツールに依存する  
  (`pytest`, `cargo`, `go`, `gradle`, `sbt` など)
- 失敗時は Summary / Output から該当箇所へジャンプできる
