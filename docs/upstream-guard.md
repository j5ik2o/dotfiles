# upstream-guard

Orca が起動したボットとワーカーが、禁止の宛先（既定は `nrslib`）のリポジトリへマージや push をしようとしたとき、コマンドを実行前に止める PreToolUse フック。ボットはオーナーの gh のトークンで動き、そのトークンには上流（nrslib/takt）への push 権限がある。「上流の PR はこちらからマージしない。上流へ直接 push しない」という決まりを、誤操作の段階で止めるために置く。

## 目的と範囲

このフックの目的は、誤操作の防止。意図して隠した呼び出しを全部止めることではない。守りの主役は、決まり（上流の PR はこちらからマージしない、上流へ直接 push しない）と、上流の push 先の無効化。レビューの指摘は、次の線引きで扱う。

- 直す: フックが働かないもの、設定を壊すもの、ほかのフックを消すもの、ふつうの作業を誤って止めるもの、禁止の宛先が文字で書いてあるのに通るもの
- 直さずに「掛からない経路」に書く: 意図して形を変えないと起きないすり抜け（めずらしい道具やオプション、変数や glob で宛先を隠す形、作業場所を間接に変える形）

## 掛かる範囲

フックは Claude Code と Codex に登録し、Pi へは拡張として配る。どれも判定するのは、環境変数 `ORCA_AGENT_SESSION_ID` があるセッションだけ。Orca は、ボットとワーカー（構造化セッション）を起動するときにこの変数を渡し、端末のペインで手で起動したエージェントには渡さない。オーナーの対話のセッションでは、フックも拡張も何もせずに終わる。オーナーが手で打つ gh と git には何も挟まない。

| 対象 | 登録先 | 見るツール |
| --- | --- | --- |
| Claude Code | `~/.claude/settings.json` の `hooks.PreToolUse` | `Bash`、`Monitor` |
| Codex | `~/.codex/hooks.json` の `PreToolUse` と、`~/.codex/config.toml` の `hooks.state`（信頼の値） | `Bash` |
| Pi | `~/.pi/agent/extensions/upstream-guard.ts`（Home Manager が置く） | `bash`、`powershell` |

Claude Code と Codex は `"$HOME/.local/bin/upstream-guard" hook` を呼び、Pi の拡張は `upstream-guard check --cwd <cwd> -- '<command>'` を PATH から spawn する。どちらも同じ実行ファイル（Home Manager が置く。`modules/common.nix`、`packages/upstream-guard.nix`）と判定（`scripts/upstream_guard.py`）を使う。

Pi の拡張は、終了コード 2（拒否）のときだけ bash を止め、0 で警告（`warn`）が返ったときは通して文面を TUI とツール結果の本文へ出す。拡張の側の失敗（PATH に実行ファイルが無い・時間切れ・想定外の終了コード）は、コマンドを通して 1 行の警告を出す。ここで閉じると全ボットの bash が止まるため。振る舞いは `tests/pi-upstream-guard-test.mjs` と `make test-pi-guard` で固定する。

## 止めるもの

宛先が禁止の一覧に当たるときに止める。

- PR のマージ: `gh pr merge`（`-R`、URL、作業ディレクトリの既定の宛先、`GH_REPO`、`--auto`、`--admin`）、`gh pr update-branch`
- GitHub の API での書き換え: `gh api` と `curl` などでの `pulls/N/merge`、`merges`、`merge-upstream`、`git/refs` など `git/*`、`contents/*`、`releases`
- GraphQL の `enablePullRequestAutoMerge`、`mergePullRequest`、`enqueuePullRequest` など。GraphQL はノード ID で宛先を指すため宛先を決められないものとして扱い、クエリ・変数・読めるファイルなどに禁止の宛先の語があれば止め、無ければ警告して通す（下の「宛先を判定できないとき」）
- push: `git push`（remote 名、URL、`git@github.com:owner/repo`、`-C`、`--git-dir`、`GIT_DIR`、fetch と push の URL のどちらか、git のエイリアス）、`git send-pack`、`git subtree push`
- `gh repo sync <宛先>`、`gh release create/edit/delete/upload`、`gh repo delete/rename/archive`

パイプ、`&&`、`;`、サブシェル、`bash -c`、`eval`、`env VAR=…`、`xargs`、`find -exec`、ヒアドキュメント、コマンド置換、プロセス置換の中も見る。同じコマンドの中で `git config`、`git remote set-url`、`gh repo set-default` を実行したあとのマージと push は、書き換え後の宛先を読めないので止める。

判定するのは「解析した結果、実行される git や gh の呼び出しがあるか」で、行のどこかに語句があるかではない。

- 引数として渡す文（`--body`、`--text`、`-m`、`echo` や `cat` へのヒアドキュメント）は、実行されないので中を見ない。
- `python3` や `node` などのコードは解析しない。止めるのは、子プロセスの起動か HTTP の形（`subprocess`、`os.system`、`child_process`、`requests`、`fetch` など）があり、かつ禁止の宛先の文字列か push・マージのはっきりした形があるときだけ。
- 実行ファイルの名前が変数で決まるとき（`"${ORCA_CLI_COMMAND:-orca}"` など）は、引数の語の位置に `push` や `merge` があるときと、変数の中身が git や gh の push・マージに見えるときだけ止める。
- 解析できないときは、git・gh・hub・curl がコマンドの位置に現れ、その後ろに push・merge・api があるときだけ止める。

### 宛先を判定できないとき（2026-11-25 から）

宛先を決められないマージや push（変数で決まる宛先、git のリポジトリでない場所、中身の見えない GraphQL、解析できないコマンドなど）は、禁止の宛先の語がどこかに出てくるかで扱いを分ける。

- 出てこない: 止めずに通し、何を判定できなかったかを 1 行の警告（`additionalContext` と `systemMessage`）でモデルに渡す。`check` の入口は 1 行目に `warn` を出して 0 で終える。
- 出てくる: これまでどおり止める。
- 語を探す範囲は、コマンドの全文、値の決まらない変数の代入の元、作業ディレクトリと判定の中で引いた場所の remote（fetch と push の URL。insteadOf を通した後の形）、`GH_` と `GIT_` で始まる環境変数、読んだクエリのファイル。大文字小文字は区別しない。禁止の宛先が `owner/repo` の形なら、全体と owner と repo のどれが出てきても当てる。
- 宛先が禁止の宛先と決まったものは、これまでどおり止める。GraphQL の、宛先に関係なく止めていた mutation も、同じ考え方で扱う。

警告と拒否は、フックの入口で `~/.local/state/upstream-guard/warnings.log` と `denials.log` に 1 行 1 件の JSON で追記する。置き場は 0700、ファイルは 0600 で作り、すでに在るファイルも書く時に 0600 に直す。1 つのファイルが 1 MiB を超えたら `.1` に移し、古い `.1` は捨てる。大きさの確認、移動、追記は、ロックのファイル（`<記録>.lock`）で直列にする。理由の文（記録とモデルへ返す理由と警告）には、コマンドや設定から取った生の値（URL、ヘッダ、`git -c` の値、変数の中身、API のパスなど）を写さない。書くのは、何を見たかを示す固定の文、判定の種類、設定の一覧に在る禁止の宛先の名前、作業ディレクトリだけ。記録には、ほかにコマンドの先頭の語と長さを書く。2 つ目の守りとして、それでも文に入ったときのために、Authorization・Cookie のヘッダの値、認証の方式に続く値、GitHub のトークンの形、`token=` などの値（引用符で囲んだ値は閉じる引用符まで）、URL の `//…@` の部分（`@` が 2 つ以上あれば最後の `@` まで）を伏せる。中身は時刻、セッションの ID、作業ディレクトリ、判定の結果と理由、コマンドの先頭の語、コマンドの長さ、マージと push のどちらに見えたか。コマンドの全文は残さない（本文に秘密が入りうるため）。

`gh pr create`、`comment`、`view`、`review --approve`、issue の操作、読み取り、禁止でない宛先への操作は止めない。

## 禁止の宛先

既定の一覧は `scripts/upstream_guard.py` の `DEFAULT_BLOCKED`。`owner` か `owner/repo` で書き、大文字小文字は区別しない。足すときは次のどちらかを使う。どちらも足すだけで、既定の一覧を減らす手段はない。

- `~/.config/upstream-guard/extra-blocked`（1 行に 1 件）
- 環境変数 `UPSTREAM_GUARD_EXTRA_BLOCKED`（テスト用。空白かカンマで区切る）

## 設置と外し方

```sh
make apply                  # ~/.local/bin/upstream-guard と Pi の拡張を置く
upstream-guard install      # Claude と Codex の設定に 1 項目ずつ足す
upstream-guard uninstall    # 足した項目だけを消す
```

Pi は `~/.pi/agent/extensions/upstream-guard.ts` を `make apply` が置くので、`install` を呼ばない（呼んでも Claude Code と Codex の設定しか触らない）。`make apply` の後に `~/.pi/agent/extensions/upstream-guard.ts` が Nix のパッケージを指していることを確かめる。

拡張ごと緊急に止めるときは、ボットの起動環境へ `PI_UPSTREAM_GUARD_DISABLED=1` を渡す（`0` と `false` は止めない）。実行ファイルを外すと Claude Code・Codex・Pi のすべてが警告だけで通すようになるので、止めるより先にこちらを使う。

### 手で作ったリンクから make apply へ移るとき

PR のマージより前に `~/.local/bin/upstream-guard` を手で作ったリンク（`~/.local/state/upstream-guard/result/bin/upstream-guard` を指すもの）で入れていた場合は、`make apply` の前にそのリンクを取り除く。残したままだと、Home Manager の有効化が「Existing file '~/.local/bin/upstream-guard' would be clobbered」で止まる。

- `backupFileExtension = "backup"`（`flake.nix` の `home-manager.backupFileExtension`）が退避するのは、シンボリックリンクでない普通のファイルだけ。Home Manager の `modules/files/check-link-targets.sh` は、`[[ ! -L "$targetPath" && -n "$HOME_MANAGER_BACKUP_EXT" ]]` のときだけ `.backup` へ移す。リンクで、指す先が Home Manager の世代（`*-home-manager-files/*`）でないものは、退避されずに衝突として止まる（`b56bcd04` の Home Manager で確認）。
- 取り除いてから `make apply` が終わるまでの間は、実行ファイルが無いので、フックは判定をせず、警告を出してコマンドを通す（`実行ファイルが無いため…` の警告）。
- `make apply` の後は、`~/.local/bin/upstream-guard` が Nix のパッケージを直接指すので、`scripts/upstream-guard-refresh.sh` は効かない（実体を確かめて、効いていないと出して 0 以外で終える）。作り直しは `make apply` で行う。

```sh
mv ~/.local/bin/upstream-guard ~/.local/bin/upstream-guard.manual   # 手で作ったリンクを退避する
make apply
```

- `make apply` が失敗したら、退避したリンクを戻す（`mv ~/.local/bin/upstream-guard.manual ~/.local/bin/upstream-guard`）。戻さないと、フックは警告だけでコマンドを通し続ける。原因を直してから、もう一度リンクを退避して `make apply` を流す。たとえば macOS では、`make apply` は `apply-darwin` を呼び、`hosts/<ホスト名>.nix` が無く `FORCE` も無いと、`darwin-rebuild switch` の前に 1 で終わる（`Makefile` の `apply-darwin`）。
- `make apply` が成功したら、`~/.local/bin/upstream-guard.manual` は消してよい。

`install` と `uninstall` は何度実行しても同じ結果になる。書き換える前のファイルは `<ファイル>.bak-upstream-guard-<日時>` に残す。

- 設定ファイル（`settings.json`、`hooks.json`、`config.toml`）が無ければ、`install` が作る。置き場のディレクトリ（`~/.claude`、`~/.codex`）が無いときは、そのエージェントは入っていないとみなして登録せず、登録できなかった対象を表示して 0 以外で終える。
- 外すときは、フックの単位で自分の項目だけを外す。同じグループにほかのフックがあれば残し、空になったグループだけを消す。
- Codex の `hooks.json` と `config.toml` は一組で書く。途中で書き込みに失敗したら、書いた分を元に戻してから失敗で終える。戻せなかったときは、そのファイルと写しの場所を表示する。

登録するシェルの 1 行は `scripts/upstream-guard-hook.sh` に置き、`make lint` の ShellCheck を通す。Python の `HOOK_COMMAND` と同じであることは単体テストで確かめる。Orca が `~/.codex/hooks.json` を書き直して並びが変わると、Codex の信頼の値が合わなくなってフックが動かなくなる。そのときは `install` をもう一度実行する。

手で確かめるときは `upstream-guard check --cwd <作業ディレクトリ> -- '<コマンド>'` を使う。コマンドは実行せず、判定（`allow`、`warn`、`deny`）だけを出す。終了コードは `deny` だけが 2。

### 実行ファイルの作り直し

`scripts/upstream-guard-refresh.sh` が効くのは、フックが呼ぶ `~/.local/bin/upstream-guard` が `~/.local/state/upstream-guard/result/bin/upstream-guard` を指しているとき（PR のマージと `make apply` の前に、手で作ったリンク）だけ。`make apply` の前に、そのリンクを取り除く必要がある（上の「手で作ったリンクから make apply へ移るとき」。Home Manager はリンクを `.backup` へ退避しない）。`make apply` の後は Nix のパッケージを直接指すので、作り直しは `make apply` で行う。refresh は最後に実体を確かめ、`result` を指していなければ「効いていない」と出して 0 以外で終える。refresh は同時に 2 つ走らせない。差し替えは、push と同じ区切りに 1 回だけ行う運用にしている。

PR のマージと `make apply` の前に、手元の実行ファイルだけを作り直すときは `scripts/upstream-guard-refresh.sh` を使う。新しい版は、いま使っていない側の out-link（`~/.local/state/upstream-guard/slot-a` か `slot-b`）に作り、単体テストと `check` の入口（禁止の宛先へのマージは拒否、読み取りは許可）が通ってから、`result` のリンクを 1 回の rename で付け替える。前の版は、もう片方の out-link に残る。どこかで失敗したら `result` は変えない。作業の途中の版は、別のパスに作って `check` の入口で試す。全ボットに掛かっている実行ファイルには入れない。

### 表示の読み方

Claude Code は、フックの拒否を `PreToolUse:Bash hook error: [<登録のコマンド>]: <理由>` の形で出す。登録のコマンドの中には警告の文も書いてあるので、判定の結果は `]: ` の後ろを読む。警告は 2 種類あり、どちらもコマンドは止めない。

- `実行ファイルが無いため…`: `~/.local/bin/upstream-guard` が無いか、リンクが切れている
- `判定が終了コード N で失敗したため…`: 実行ファイルが 0（許可）と 2（拒否）以外で終わった

完全に外すときは、`upstream-guard uninstall` のあと、`modules/common.nix` の `.local/bin/upstream-guard` の項目を消して `make apply` する。

## 掛からない経路

- curl の URL の glob（`{a,b}` や `[1-3]`）は展開しない。`-g` の無い書き込みは、宛先を決められないものとして扱う（禁止の宛先の語が文字で書いてあれば止め、無ければ警告して通す）。語を glob で割ったもの（`nrsli{b,x}`）は警告だけで通る
- `export` していないシェル変数（`GH_REPO=…; gh …`）を、gh や git に渡る環境変数として扱う。引き継いだ環境と区別していない
- 先頭の語をコマンド置換で作り、その置換の中身の判定が「宛先を決められない」になったときは、コマンドの本体を調べずにその判定を返す。禁止の宛先の語がどこにも無ければ警告だけで通る
- `unset -f NAME`（関数の削除）も、同じ名前の変数を消したものとして扱う
- 子のシェル（`bash -c '…'`、丸括弧）の中の `unset` が、親の環境からも消えたものとして扱う
- `NAME=… env -i cmd` の、`env -i` より前の代入を、`cmd` に渡るものとして扱う
- 判定の中で git の設定を読むときは、対象リポジトリの `.git/config`（worktree は `commondir` の先、`extensions.worktreeConfig` 有効時は `config.worktree`、および `include` / `includeIf`・システム・グローバル設定）を直接読み、`GIT_CONFIG_COUNT` や `GIT_CONFIG_PARAMETERS` には頼らない。`GIT_CONFIG_COUNT` や `GIT_CONFIG_PARAMETERS` は、push 先に効く設定（`remote.*`、`branch.*`、`url.*`、`include.*`、`includeIf.*`）を差し替えているとき、値を解析できないとき、または `http.*` に禁止の宛先を含むときに拒否（または警告）に倒す
- GraphQL のクエリのファイルが FIFO などの特別なファイルだと、読むのを待ってフックが時間切れ（10 秒）になる
- curl の `--next` で、前の転送の宛先をコマンド置換で作り、後ろの転送の URL の語を `%` エンコードで書いたもの（`n%72slib` など）は、宛先を決められないものとして扱われ、禁止の宛先の語も見つからないので警告だけで通る
- `pushd` と `popd`、関数の定義の中の `cd` など、作業場所を間接に変える形は、実行の順を追わない（`popd` で戻った場所や、呼んでいない関数の中の `cd` を、そのとおりには扱わない）
- Orca の外のセッションと、Orca の端末のペインで動くエージェント（どちらも `ORCA_AGENT_SESSION_ID` がない）。オーナーの対話と見分けられないため、対象にしない
- 登録の項目そのものが消えたとき（`settings.json` や `hooks.json` の書き直しなど）。警告も出ない。実行ファイルが無い・壊れたときは、コマンドを止めずに警告だけを出す
- Pi の拡張が、PATH から `upstream-guard` を見つけられないとき（`~/.local/bin` が PATH に無いなど）。拡張は止めずに警告だけを出す。同じく、拡張が時間切れか想定外の終了コードを見たときも警告だけで通す（拡張で閉じると全ボットの bash が止まるため）。`PI_UPSTREAM_GUARD_DISABLED=1` を渡したセッションも対象外
- 実行ファイルの差し替えの間は、判定が働かない瞬間がありうる。`scripts/upstream-guard-refresh.sh` は rename で付け替えるので、ほぼ無くなる。`make apply` での置き換えは Home Manager の手順による
- 宛先を決められず、禁止の宛先の語も現れない形は、警告だけで通る。たとえば、別名の remote を insteadOf 以外の方法で差し替える（`~/.ssh/config` の Host の別名、`GIT_SSH_COMMAND`、資格情報の仕掛け）、変数やファイルに入れた URL（`git push "$(cat url.txt)"`）、スクリプトの中で組み立てた宛先、ブレース展開などで語を割ったもの（`nrsli{b..b}`）、GraphQL のノード ID だけで指すマージ
- GraphQL のクエリを、読めないファイルや決まらない変数で渡し、その中身をこのコマンドの外で作ったもの。中身を読めるファイルと、同じコマンドの中で作ったクエリは、マージや ref の書き換えの mutation の名前を探し、禁止の宛先の語があれば止め、無ければ警告して通す
- Codex の信頼の値と `hooks.json` の並びがずれたとき（Orca が項目の順を変えたなど）。Codex は黙ってフックを動かさなくなる。`upstream-guard install` を再実行すると直る
- インタープリタのコードで、子プロセスの起動や HTTP の形を名前で書かないもの（`getattr(os, "sys" + "tem")`、`__import__` に組み立てた名前を渡す、`new Function`、別のモジュールに起動を任せるなど）
- シェルを通らない経路: ブラウザの操作（Orca のブラウザ、Codex の browser・chrome・computer-use）、Codex の `node_repl` のような MCP のコード実行、Codex の GitHub のプラグイン（コネクタ）
- 中身を読まないもの: スクリプトのファイル（`bash x.sh`、`source`、`make`、`npm run`）、`python3 x.py` などのファイル、別名に複製した実行ファイル、Bash のツールの外で定義されたシェルのエイリアスと関数、gh のエイリアス、`sed` の `e` コマンド
- 隠すように組み立てたもの: `printf 'git pu%sh' s | bash` のような文字列の組み立て、base64 などで符号化した文字列、子プロセスの起動とは別の行で宛先を組み立てるコード
- 条件で実行されない `cd`（`false && cd X; git push`）は、実行されたものとして扱う。`cd -` は場所を決められないものとして扱う
- `git` の全体設定（`~/.gitconfig`）の `url.*.pushInsteadOf` で、URL を直接書いた push の宛先を差し替えるもの
- 範囲の外: `gh workflow run` や `repos/*/dispatches` での上流のワークフローの起動

誤って止める側に倒れるものもある。

- 宛先を決められないもののうち、禁止の宛先の語がどこかに出てくるもの（`nrslib` の remote がある場所での宛先なしの push、`GH_REPO` に `nrslib` がある変数の宛先など）。宛先を明示すれば通る
- 二重引用符の中のバッククォート（`--body "… \`git push\` …"`）は、シェルが実際に実行するので判定する。文として書くときは単一引用符か、ヒアドキュメントの区切りを引用符で囲む

## 試験のしかた

試験の入力は、ファイル（`tests/upstream_guard_test.py` の表など）に書き、判定の関数（`decide()`）か `upstream-guard check` に渡す。シェルのヒアドキュメントやコマンド行に貼らない。入力の中に区切りの行（`EOF` など）があると、そこでヒアドキュメントが閉じ、残りの行がコマンドとして実行される。2026-11-25 の独立レビューでは、この形で `git push` が走った。

本物の禁止の宛先への操作は、どんな形でも試さない。結合の確かめには、存在しないリポジトリか使い捨てのリポジトリを `extra-blocked` に一時的に足し、済んだら消す。
