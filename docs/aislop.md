# aislop のチェック

aislop の検査ロジックはこのリポジトリに持たない。j5ik2o/ci の `aislop/` に置く正本
（`check-aislop.mjs` と `check-aislop.test.mjs`）を、タグ `aislop-check-v5` に版固定して参照する。
検査は `make done` と CI（`.github/workflows/nix-check.yml`）に組み込み済みで、他のゲートと同じ扱いで合否を決める。

このドキュメントは、aislop 0.20.1 の固定、受け入れ一覧 `scripts/aislop-accepted.json`（v2 形式）と
初回 scan の指摘の切り分け、ruff と knip の要否の結論を記録する。

## 仕組み

- `scripts/aislop-check-bootstrap.mjs` は j5ik2o/ci の `aislop/bootstrap.mjs` の無編集の写しである。
  検査本体（`check-aislop.mjs`）はリポジトリに置かない。
- `scripts/aislop-check-pin.json` が、正本の取得を SHA-256 で固定する。
  `ref` はタグ `aislop-check-v5`、`files` はそのタグでの `check-aislop.mjs` と
  `check-aislop.test.mjs` の SHA-256 である。取得したファイルがハッシュと一致しなければ、
  検査は失敗し、取得したファイルは検査に使わない。取得したファイルは利用者キャッシュ
  （既定 `~/.cache/aislop-check/<ref>/`、`XDG_CACHE_HOME` があればその配下、`AISLOP_CHECK_CACHE_DIR`
  で変更可。相対パスを指定した場合は絶対パスへ解決する）に置き、次回からはハッシュが合う限りそれを使う。
  リポジトリの外に置くのは、`npm ci` が `node_modules` を消すたびに検証済みキャッシュまで失わないようにするためで、
  あわせて取得した正本ファイルが aislop のスキャン対象に入らないようにするためでもある。
  解決後の置き場所がリポジトリの中になる場合は、書き込みの前に理由を出して失敗する。
- `package.json` の `devDependencies` に `aislop` を `0.20.1` で固定している。範囲指定はしない。
  `package-lock.json` を追跡し、`npm ci` で依存を揃える。
- `package.json` の `check:aislop` は `nix develop --command node scripts/aislop-check-bootstrap.mjs check`、
  `test:aislop` は `node scripts/aislop-check-bootstrap.mjs test` である。
  `check:aislop` が devShell に入るのは、aislop の `format`/`lint` エンジンが呼び出し元 PATH の
  ruff の有無で結果を変えるためで、devShell の ruff を採用環境として固定する。
  `make done` は `aislop-check` ターゲット（`npm ci` のあと `check:aislop`）を回す。
- 実行時は `AISLOP_NO_TELEMETRY=1` と `AISLOP_NO_UPDATE_NOTIFIER=1` を設定する。これは正本の検査が
  `aislop scan` に渡す。
- スキャンは正本の検査が `aislop scan --json` を実行する。除外は正本の検査に `--exclude` を渡す口が無いため、
  `.aislop/config.yml` の `exclude` で与える。除外は `.codex-corporate/`、`.codex-personal/`、`references/`
  の 3 つだけで、`lint/vendored-paths.txt` の `root:` と範囲を一致させる。`packages/` は除外せず検査対象に含める。
- `aislop scan --json` の `diagnostics[]` を、`engine` / `rule` / `file` / `message` の 4 キーと
  **件数**で `scripts/aislop-accepted.json` と照合する。`line` は照合に使わない。
- 合否の対象は `error` と `warning` のみ。`info` は合否に含めない。
- 空振りは通さない。対象ファイルが 0 件、または対象ファイル数を確認できないときは失敗する。
  エンジンが止まったときは、検査側が欠けた道具を実際に導入していないことを確かめ、欠落が `missingToolsAllowed` に
  挙がっているときだけ通す。止まらずに欠けた道具を記録した場合も、許可されていない道具なら失敗する。
  受け入れ一覧の `engines` に挙げたエンジンの記録が scan に無ければ失敗する。
- `aislop` 自身の baseline 機能（`aislop baseline write` / `ci.baseline`）は使わない。

## 受け入れ一覧

`scripts/aislop-accepted.json` は v2 形式で、`engines`、`missingToolsAllowed`、`accepted[]` を持つ。
各 `accepted[]` の要素は `reason`（空でない理由）と `findings[]` を持つ。`findings[]` の各要素は
`engine` / `rule` / `file` / `message` の 4 キーだけを持つ。

同じ 4 キーの指摘が複数行にあるときは、`findings` にその数だけ並べる。`aislop` は同じ 4 キーの指摘を
行ごとに 1 件ずつ出すため、`findings` の件数が実際の件数と一致しなければ未受け入れになる。
`line` は照合に使わないので、行番号がずれても件数が同じなら受け入れ済みのままである。

`engines` は scan の結果に実測で現れる `ai-slop` / `code-quality` / `format` / `lint` / `security` を挙げる。
`missingToolsAllowed` には、`npm ci` では導入されず欠落してよい道具の理由を書く（現在は `ruff`。
devShell の採用環境では導入されるが、devShell を使わずに直接起動した場合の欠落を許す）。

## 初回 scan の指摘の切り分け

採用環境（`nix develop`、ruff 0.17.3）で `.aislop/config.yml` の除外（`.codex-corporate/`・`.codex-personal/`・`references/`）を
効かせた scan は error 9 件・warning 22 件だった。`info` は `npm ci` 後の正規の状態で `package.json` の `knip/skipped` 1 件だった。

同じ採用環境で除外なしで scan すると error 33 / warning 208 / info 5 で、除外によって `.codex-corporate/` 配下の 94 件
（error 11・warning 81・info 2）と `.codex-personal/` 配下の 120 件（error 13・warning 105・info 2）が落ちる。
`references/` に該当する指摘は無かった。結果として error 33 − 24 = 9、warning 208 − 186 = 22、info 5 − 4 = 1 になる。
除外する 3 ディレクトリにも Python があるため、devShell の ruff は除外前の scan でそこにも format/lint の指摘を出す。
issue の記載（error 13 / warning 33 / info 6）は ruff を入れない環境の測定で、採用環境の値ではない。
残る error 9 件と warning 22 件の合計 31 件は、すべて `scripts/aislop-accepted.json` に理由付きで登録した（下の表は、その後に加わった分も含む）。
その場で修正した指摘は無い。

| 分類 | 実際の指摘件数 | 登録した受け入れ件数 | 扱い | 理由 |
|------|----------------|----------------------|------|------|
| `.codex-corporate/` 配下の指摘 | 94（error 11・warning 81・info 2） | 0 | 除外 | 取り込み済みの上流コンテンツ。`lint/vendored-paths.txt` の `root:` に合わせて scan 対象から除外 |
| `.codex-personal/` 配下の指摘 | 120（error 13・warning 105・info 2） | 0 | 除外 | 取り込み済みの実行時状態。同上 |
| `config/pi/agent/extensions/{content-guard,upstream-guard}.ts` の hallucinated-import | 2（error 2、初回）→ 3（`upstream-guard.ts` を足した後） | 3（findings 3 件） | 受け入れ | Pi 実行時環境が提供する `@earendil-works/pi-coding-agent` を import する拡張。同じ 4 キーでもファイルが違えば別に数え、findings 3 件で受理 |
| `packages/dsh-tui-login.mjs` / `dsh-tui-models.mjs` の hallucinated-import | 7（error 7） | 7（7 エントリ各 findings 1 件） | 受け入れ | dsh と pi の実行時環境が提供するモジュールを import する接着コード。root の `package.json` へ依存を宣言せず実行時に解決する設計 |
| `packages/dsh-tui-login.mjs` の console-leftover | 10（warning 10） | 10（findings 10 件） | 受け入れ | CLI 接着コードが利用者へ出力するための `console.log/debug/info` が仕様。10 行の同一 4 キーを findings 10 件で受理 |
| `packages/*-check.mjs` の console-leftover | 4（warning 4） | 4（4 エントリ各 findings 1 件） | 受け入れ | `*_check.mjs` は確認スクリプトで、結果を標準出力へ出すのが役割。検査対象には含めたまま受け入れる |
| `packages/dsh-tui-models.mjs` の hardcoded-url | 1（warning 1） | 1 | 受け入れ | Codex のモデル一覧エンドポイントの絶対 URL。環境依存の設定値ではない |
| `config/spark/namespace_relay.py` の complexity | 3（warning 3） | 3（3 エントリ各 findings 1 件） | 受け入れ | 今回の変更対象外の既存スクリプト。行数・ネストだけを理由に振る舞いを変えない |
| `packages/dsh-tui-models.mjs` の function-too-long | 1（warning 1） | 1 | 受け入れ | 実行時環境に依存する接着コードの一連の処理。範囲外の分割をしない |
| `scripts/aislop-check-bootstrap.mjs` の file-too-large | 1（warning 1） | 1 | 受け入れ | j5ik2o/ci の正本の無編集の写しで 510 行。写しは正本とバイト一致させる決まりのためこのリポジトリでは分割できず、分割は正本側の判断 |
| `scripts/upstream_guard.py` の file-too-large | 1（warning 1） | 1 | 受け入れ | `packages/upstream-guard.nix` が 1 ファイルとして配る Python。分けると配り方（モジュールの探索パス）が変わる（#229） |
| `config/spark/namespace_relay.py` / `scripts/clean-commit-msg.py` の python-formatting | 2（warning 2） | 2（findings 2 件） | 受け入れ | devShell の ruff が見る既存の Python。裁定により今回の整形は変更対象外。整形したら一覧から消す |
| `package.json` の knip/skipped（info） | 1（info 1） | 0 | 合否対象外 | `info` は合否に含めない。knip を導入しない判断は下記 |

受け入れ一覧の登録件数は合計 33 件（21 エントリ）。実際の error/warning も 33 件で一致する。
初回の scan は 31 件だった。`scripts/upstream_guard.py` の file-too-large（#229）と、Pi の拡張を 2 本にしたときの
`upstream-guard.ts` の hallucinated-import 1 件が加わって 33 件になった。

### hallucinated-import の再 scan

hallucinated-import は `node_modules` の有無で結果が変わる。`npm ci` で `node_modules` を用意した正規の状態で
再 scan した結果を根拠に、上記のとおり修正ではなく理由付きの受け入れとして判断した。
`packages/dsh-tui-login.mjs` と `packages/dsh-tui-models.mjs` の指摘は、dsh と pi の実行時環境が提供する
モジュールを import する接着コードであるため、root の `package.json` に依存を足さない。

aislop 0.20.1 を `npm ci` した状態で除外 3 種（`.codex-corporate/`・`.codex-personal/`・`references/`）により
scan した実測は、hallucinated-import が `config/pi/agent/extensions/content-guard.ts` 2 件、
`config/pi/agent/extensions/upstream-guard.ts` 1 件、`packages/dsh-tui-login.mjs` 4 件、
`packages/dsh-tui-models.mjs` 3 件で計 10 件、severity 別では error 10・warning 22・info 1 だった。warning 22 件のうち 2 件は、devShell の ruff が
`config/spark/namespace_relay.py` と `scripts/clean-commit-msg.py` に出す `python-formatting` である。

## ruff と knip の判断

- **ruff**: 導入済み。`scripts/lint.sh` のゲート 4 が `ruff check --no-cache` を実行し、devShell の
  `lintTools` に `ruff` を含む。`check:aislop` も `nix develop` 経由で走るため、aislop の `format`/`lint`
  エンジンは devShell の ruff で Python の format/lint を実行する。除外対象外の Python は
  `config/spark/namespace_relay.py` と `scripts/clean-commit-msg.py` の 2 ファイルで、整形は今回の
  変更対象外のため `scripts/aislop-accepted.json` に理由付きで登録している。整形した場合は正本 checker が
  resolved として落とすので、そのときは一覧から消す。
- **knip**: 導入しない。aislop は `code-quality/knip/skipped` を `info` で出すだけで、合否には影響しない。
  導入すると knip の設定ファイルと依存が増えるが、この dotfiles リポジトリの利用範囲（Nix と Home Manager の設定、
  少数の `.mjs`/`.py` の接着コード）に対して未使用検出の利得が小さい。`info` としてログに残るので、
  必要になった時点で見直せる。
