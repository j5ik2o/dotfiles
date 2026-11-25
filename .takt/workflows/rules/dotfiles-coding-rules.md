Nix の設定やスクリプトを計画、作成、実装、修正、またはレビューする場合は、次の dotfiles のコーディングルールに従ってください。

これらは make done（format-check と lint と commit-subject-check）で機械判定されるルールです。ゲートで落とされてから直すのではなく、書く時点で守ってください。ルールの正は Makefile と scripts/ の定義で、ここに書くのは事前提示用の要約です。食い違いがあれば Makefile 側に合わせてこちらを直します。

**書式**

- Nix のファイルは nixfmt の書式に合わせる。format-check は nixfmt --check を実行する
- Lua のファイルは stylua の書式に合わせる。format-check は stylua --check を実行する
- 書き終えたら、ゲートの前に自分で整形とチェックを済ませる。整形されていない差分を残さない

**コミット**

- 件名は Conventional Commits の形にし、原因を名乗る。commit-subject-check が機械判定する
- Co-Authored-By のトレイラーは付けない

**版数**

- ツールやコマンドの版数は config/mise/mise.toml だけに置く。コードや設定の中に版数を直書きしない
