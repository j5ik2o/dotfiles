# Neo-tree これだけ知っておけばOK

## まず使うキー

| キー | モード | 動作 |
|------|--------|------|
| `<Leader>e` | Normal | Neo-tree を開く |
| `Enter` | Neo-tree | ファイルを開く |
| `Y` | Neo-tree | 絶対パスをコピー |
| `yr` | Neo-tree | プロジェクトルートからの相対パスをコピー |

## 相対パスの基準 (yr)

以下のいずれかが見つかったディレクトリをプロジェクトルートとして扱う。
見つからない場合は `:pwd` を使用。

- `.git`
- `pyproject.toml`
- `package.json`
- `Cargo.toml`
- `go.mod`
- `Makefile`
- `flake.nix`

## このリポジトリの設定場所

- `config/nvim/lua/plugins/neo-tree.lua`

## カスタム挙動

- Buffers の TERMINALS は既存ターミナルへフォーカス
