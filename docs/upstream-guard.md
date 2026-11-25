# upstream-guard

Orca が起動したボットとワーカーが、禁止の宛先（既定は `nrslib`）のリポジトリへマージや push をしようとしたとき、コマンドを実行前に止める PreToolUse フック。ボットはオーナーの gh のトークンで動き、そのトークンには上流（nrslib/takt）への push 権限がある。「上流の PR はこちらからマージしない。上流へ直接 push しない」という決まりを、誤操作の段階で止めるために置く。

## 掛かる範囲

フックは Claude Code と Codex の両方に登録する。ただし判定するのは、環境変数 `ORCA_AGENT_SESSION_ID` があるセッションだけ。Orca は、ボットとワーカー（構造化セッション）を起動するときにこの変数を渡し、端末のペインで手で起動したエージェントには渡さない。オーナーの対話のセッションでは、フックは何もせずに終わる。オーナーが手で打つ gh と git には何も挟まない。

| 対象 | 登録先 | 見るツール |
| --- | --- | --- |
| Claude Code | `~/.claude/settings.json` の `hooks.PreToolUse` | `Bash`、`Monitor` |
| Codex | `~/.codex/hooks.json` の `PreToolUse` と、`~/.codex/config.toml` の `hooks.state`（信頼の値） | `Bash` |

どちらも `"$HOME/.local/bin/upstream-guard" hook` を呼ぶ。この実行ファイルは Home Manager が置く（`modules/common.nix`、`packages/upstream-guard.nix`）。

## 止めるもの

宛先が禁止の一覧に当たるときに止める。

- PR のマージ: `gh pr merge`（`-R`、URL、作業ディレクトリの既定の宛先、`GH_REPO`、`--auto`、`--admin`）、`gh pr update-branch`
- GitHub の API での書き換え: `gh api` と `curl` などでの `pulls/N/merge`、`merges`、`merge-upstream`、`git/refs` など `git/*`、`contents/*`、`releases`
- GraphQL の `enablePullRequestAutoMerge`、`mergePullRequest`、`enqueuePullRequest` など。GraphQL はノード ID で宛先を指すため、宛先に関係なく止める
- push: `git push`（remote 名、URL、`git@github.com:owner/repo`、`-C`、`--git-dir`、`GIT_DIR`、fetch と push の URL のどちらか、git のエイリアス）、`git send-pack`、`git subtree push`
- `gh repo sync <宛先>`、`gh release create/edit/delete/upload`、`gh repo delete/rename/archive`

パイプ、`&&`、`;`、サブシェル、`bash -c`、`eval`、`env VAR=…`、`xargs`、`find -exec`、ヒアドキュメント、コマンド置換、プロセス置換の中も見る。同じコマンドの中で `git config`、`git remote set-url`、`gh repo set-default` を実行したあとのマージと push は、書き換え後の宛先を読めないので止める。

判定するのは「解析した結果、実行される git や gh の呼び出しがあるか」で、行のどこかに語句があるかではない。

- 引数として渡す文（`--body`、`--text`、`-m`、`echo` や `cat` へのヒアドキュメント）は、実行されないので中を見ない。
- `python3` や `node` などのコードは解析しない。止めるのは、子プロセスの起動か HTTP の形（`subprocess`、`os.system`、`child_process`、`requests`、`fetch` など）があり、かつ禁止の宛先の文字列か push・マージのはっきりした形があるときだけ。
- 実行ファイルの名前が変数で決まるとき（`"${ORCA_CLI_COMMAND:-orca}"` など）は、引数の語の位置に `push` や `merge` があるときと、変数の中身が git や gh の push・マージに見えるときだけ止める。
- 解析できないときは、git・gh・hub・curl がコマンドの位置に現れ、その後ろに push・merge・api があるときだけ止める。

`gh pr create`、`comment`、`view`、`review --approve`、issue の操作、読み取り、禁止でない宛先への操作は止めない。

## 禁止の宛先

既定の一覧は `scripts/upstream_guard.py` の `DEFAULT_BLOCKED`。`owner` か `owner/repo` で書き、大文字小文字は区別しない。足すときは次のどちらかを使う。どちらも足すだけで、既定の一覧を減らす手段はない。

- `~/.config/upstream-guard/extra-blocked`（1 行に 1 件）
- 環境変数 `UPSTREAM_GUARD_EXTRA_BLOCKED`（テスト用。空白かカンマで区切る）

## 設置と外し方

```sh
make apply                  # ~/.local/bin/upstream-guard を置く
upstream-guard install      # Claude と Codex の設定に 1 項目ずつ足す
upstream-guard uninstall    # 足した項目だけを消す
```

`install` と `uninstall` は何度実行しても同じ結果になる。書き換える前のファイルは `<ファイル>.bak-upstream-guard-<日時>` に残す。

- 設定ファイル（`settings.json`、`hooks.json`、`config.toml`）が無ければ、`install` が作る。置き場のディレクトリ（`~/.claude`、`~/.codex`）が無いときは、そのエージェントは入っていないとみなして登録せず、登録できなかった対象を表示して 0 以外で終える。
- 外すときは、フックの単位で自分の項目だけを外す。同じグループにほかのフックがあれば残し、空になったグループだけを消す。
- Codex の `hooks.json` と `config.toml` は一組で書く。途中で書き込みに失敗したら、書いた分を元に戻してから失敗で終える。戻せなかったときは、そのファイルと写しの場所を表示する。

登録するシェルの 1 行は `scripts/upstream-guard-hook.sh` に置き、`make lint` の ShellCheck を通す。Python の `HOOK_COMMAND` と同じであることは単体テストで確かめる。Orca が `~/.codex/hooks.json` を書き直して並びが変わると、Codex の信頼の値が合わなくなってフックが動かなくなる。そのときは `install` をもう一度実行する。

手で確かめるときは `upstream-guard check --cwd <作業ディレクトリ> -- '<コマンド>'` を使う。コマンドは実行せず、判定だけを出す。

### 実行ファイルの作り直し

PR のマージと `make apply` の前に、手元の実行ファイルだけを作り直すときは `scripts/upstream-guard-refresh.sh` を使う。新しい版は、いま使っていない側の out-link（`~/.local/state/upstream-guard/slot-a` か `slot-b`）に作り、単体テストと `check` の入口（禁止の宛先へのマージは拒否、読み取りは許可）が通ってから、`result` のリンクを 1 回の rename で付け替える。前の版は、もう片方の out-link に残る。どこかで失敗したら `result` は変えない。作業の途中の版は、別のパスに作って `check` の入口で試す。全ボットに掛かっている実行ファイルには入れない。

### 表示の読み方

Claude Code は、フックの拒否を `PreToolUse:Bash hook error: [<登録のコマンド>]: <理由>` の形で出す。登録のコマンドの中には警告の文も書いてあるので、判定の結果は `]: ` の後ろを読む。警告は 2 種類あり、どちらもコマンドは止めない。

- `実行ファイルが無いため…`: `~/.local/bin/upstream-guard` が無いか、リンクが切れている
- `判定が終了コード N で失敗したため…`: 実行ファイルが 0（許可）と 2（拒否）以外で終わった

完全に外すときは、`upstream-guard uninstall` のあと、`modules/common.nix` の `.local/bin/upstream-guard` の項目を消して `make apply` する。

## 掛からない経路

- Orca の外のセッションと、Orca の端末のペインで動くエージェント（どちらも `ORCA_AGENT_SESSION_ID` がない）。オーナーの対話と見分けられないため、対象にしない
- 登録の項目そのものが消えたとき（`settings.json` や `hooks.json` の書き直しなど）。警告も出ない。実行ファイルが無い・壊れたときは、コマンドを止めずに警告だけを出す
- 実行ファイルの差し替えの間は、判定が働かない瞬間がありうる。`scripts/upstream-guard-refresh.sh` は rename で付け替えるので、ほぼ無くなる。`make apply` での置き換えは Home Manager の手順による
- GraphQL のクエリを、読めないファイルや決まらない変数で渡し、その中身をこのコマンドの外で作ったもの。中身を読めるファイルと、同じコマンドの中で作ったクエリは、マージや ref の書き換えの mutation の名前を探して止める
- Codex の信頼の値と `hooks.json` の並びがずれたとき（Orca が項目の順を変えたなど）。Codex は黙ってフックを動かさなくなる。`upstream-guard install` を再実行すると直る
- インタープリタのコードで、子プロセスの起動や HTTP の形を名前で書かないもの（`getattr(os, "sys" + "tem")`、`__import__` に組み立てた名前を渡す、`new Function`、別のモジュールに起動を任せるなど）
- シェルを通らない経路: ブラウザの操作（Orca のブラウザ、Codex の browser・chrome・computer-use）、Codex の `node_repl` のような MCP のコード実行、Codex の GitHub のプラグイン（コネクタ）
- 中身を読まないもの: スクリプトのファイル（`bash x.sh`、`source`、`make`、`npm run`）、`python3 x.py` などのファイル、別名に複製した実行ファイル、Bash のツールの外で定義されたシェルのエイリアスと関数、gh のエイリアス、`sed` の `e` コマンド
- 隠すように組み立てたもの: `printf 'git pu%sh' s | bash` のような文字列の組み立て、base64 などで符号化した文字列、子プロセスの起動とは別の行で宛先を組み立てるコード
- 条件で実行されない `cd`（`false && cd X; git push`）は、実行されたものとして扱う。`cd -` は場所を決められないものとして扱う
- `git` の全体設定（`~/.gitconfig`）の `url.*.pushInsteadOf` で、URL を直接書いた push の宛先を差し替えるもの
- 範囲の外: `gh workflow run` や `repos/*/dispatches` での上流のワークフローの起動

誤って止める側に倒れるものもある。

- git のリポジトリでない場所（`/tmp` など）での、宛先を書かない `git push` と、`-R` のない `gh pr merge`。宛先を決められないので止める
- 実行ファイルの名前や宛先が、決まらない変数で決まるもの（`cd "$WT" && git push`、`git push "$REMOTE"` など）。宛先を明示すれば通る
- GraphQL のマージや ref の書き換えの mutation は、宛先に関係なく止める。自分のリポジトリでは `gh pr merge -R owner/repo` を使う
- 二重引用符の中のバッククォート（`--body "… \`git push\` …"`）は、シェルが実際に実行するので判定する。文として書くときは単一引用符か、ヒアドキュメントの区切りを引用符で囲む

## 試験のしかた

試験の入力は、ファイル（`tests/upstream_guard_test.py` の表など）に書き、判定の関数（`decide()`）か `upstream-guard check` に渡す。シェルのヒアドキュメントやコマンド行に貼らない。入力の中に区切りの行（`EOF` など）があると、そこでヒアドキュメントが閉じ、残りの行がコマンドとして実行される。2026-11-25 の独立レビューでは、この形で `git push` が走った。

本物の禁止の宛先への操作は、どんな形でも試さない。結合の確かめには、存在しないリポジトリか使い捨てのリポジトリを `extra-blocked` に一時的に足し、済んだら消す。
