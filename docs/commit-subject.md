# コミットサブジェクトのゲート

主題には「何が悪くて何を変えたか」を書きます。対象やファイル名だけを書くと、
次に読む人が不変条件を推測し直すことになり、また壊します。

## 悪い主題の定義

次のどれかに当たる主題は `make commit-subject-check` が落とします。

- 説明がパスやファイル名だけ: `fix: mise.toml`, `fix: nix files`, `refactor: flake.nix`
- 説明が領域語だけで原因がない: `fix: neovim`, `fix: path`, `fix: default shell`
- 説明が中身のない語だけ: `fix: bug`, `fix: bugs`
- 説明が空: `fix:`

## 良い主題

Conventional Commits の形式で、説明が原因と変更を語っているもの。

```
fix(ci): resolve node from config/mise when pre-installing
feat(darwin): add OpenMTP cask to mac studio
chore(nix): update flake inputs
```

## 判定

説明を単語に割り、その全部が「パス」「領域語」「中身のない語」で
埋まっている場合だけ落とします。原因を語る語が 1 つでもあれば通します。
判定に使う語彙は `scripts/check-commit-subject.sh` にあります。

`Merge ...` と `Revert ...` は git が主題を生成するため対象外です。

## どこで動くか

- CI: PR タイトルを検証します。このリポジトリは squash マージなので、
  PR タイトルがそのままサブジェクトになります。
- ローカル: `make commit-subject-check` が HEAD のサブジェクトを検証します。
  `make done` にも含まれます。
- フック: `make hooks` で `commit-msg` フックを有効にすると、
  コミットする前に同じ判定が走ります。フックはスキップできるので、
  ゲートとして数えるのは CI だけです。

過去のコミットは検証しません。見るのはこれから入る 1 件だけです。

## 有効化

```
make hooks          # commit-msg フックを有効にする (任意)
make commit-subject-check   # HEAD の主題を今すぐ確認する
```
