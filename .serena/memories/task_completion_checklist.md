# Task Completion Checklist

## Nix設定を変更した場合

1. **フォーマット**: `make fmt` で全 .nix ファイルをフォーマット
2. **チェック**: `make check` で flake check を実行
3. **ビルド確認**: `make build` でビルドが通ることを確認
4. **適用**: ユーザーに `make apply` の実行を案内（自動実行しない）

## Neovim設定を変更した場合

1. **テスト**: `make nvim-test` でNeovim設定テストを実行
2. キャッシュクリアが必要な場合: `make nvim-clean`

## flake.nix を変更した場合

1. **フォーマット**: `make fmt`
2. **チェック**: `make check`
3. **ビルド**: `make build`

## コミット前の確認

- `make fmt` でフォーマット済みか
- `make check` でエラーがないか
- 不要な機能や「念のため」の設定を追加していないか
