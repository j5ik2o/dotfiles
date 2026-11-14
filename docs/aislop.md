# aislop のチェック

このゴール（issue #191 の縮小後の範囲）で入れるのは、aislop 0.20.1 の固定と `package-lock.json` の追跡、
理由付きの受け入れ一覧 `scripts/aislop-accepted.json`、初回 scan の指摘の切り分けの記録、
ruff と knip の要否の結論までである。

チェックスクリプト（`scripts/check-aislop.mjs`）と `make done` への組み込み、CI（`.github/workflows/nix-check.yml`）
への step 追加は**未導入**である。これらは j5ik2o/ci に置く正本を版固定で参照する方式で、横展開のときに導入する。
したがって、この変更のあとも `make done` は aislop を実行しない。

## 仕組み

- `package.json` の `devDependencies` に `aislop` を `0.20.1` で固定している。範囲指定はしない。
- `package-lock.json` を追跡し、`npm ci` で依存を揃える。確認は `./node_modules/.bin/aislop` を直接呼び、
  PATH 上の `aislop` や `npx` のレジストリ解決には頼らない。
- 実行時は `AISLOP_NO_TELEMETRY=1` と `AISLOP_NO_UPDATE_NOTIFIER=1` を設定する。
- スキャンは次の形で実行する。除外は `.codex-corporate/`、`.codex-personal/`、`references/` の 3 つだけで、
  `lint/vendored-paths.txt` の `root:` と範囲を一致させる。`packages/` は除外せず検査対象に含める。

  ```sh
  AISLOP_NO_TELEMETRY=1 AISLOP_NO_UPDATE_NOTIFIER=1 \
    ./node_modules/.bin/aislop scan --json \
      --exclude .codex-corporate/ --exclude .codex-personal/ --exclude references/
  ```

- `aislop scan --json` の `diagnostics[]` を、`engine` / `rule` / `filePath` / `message` の 4 キーと
  **件数**で `scripts/aislop-accepted.json` と照合する。`line` は照合に使わない。
  同一 4 キーが複数件出る場合、登録した `count` と実際の件数が一致しなければ未受け入れとして扱う。
- 合否の対象は `error` と `warning` のみ。`info` は合否に含めない。
- `aislop` 自身の baseline 機能（`aislop baseline write` / `ci.baseline`）は使わない。

## 受け入れ一覧

`scripts/aislop-accepted.json` の各エントリは `engine` / `rule` / `filePath` / `message` と、
正の整数 `count`（登録する指摘件数）と、空でない `reason` を持つ。理由が空のエントリや、
同じ 4 キーのエントリの重複、`count` を持たないエントリは受け入れとして扱わない。

`count` は 4 キーごとの「受理する指摘件数」である。`aislop` は同じ 4 キーの指摘を行ごとに 1 件ずつ出すため、
複数行に同じ指摘が出るファイルでは、実際の件数と `count` が一致しなければ未受け入れになる。
`line` は照合に使わないので、行番号がずれても件数が同じなら受け入れ済みのままである。

## 初回 scan の指摘の切り分け

初回 scan を `--exclude .codex-corporate/ --exclude .codex-personal/ --exclude references/` で絞った結果は
error 9 件・warning 19 件だった。`info` は `npm ci` 後の正規の状態で `package.json` の `knip/skipped` 1 件だった。

除外前の scan（除外なし）は error 13 / warning 33 / info 5 で、除外によって `.codex-corporate/` 配下の 10 件
（error 2・warning 6・info 2）と `.codex-personal/` 配下の 12 件（error 2・warning 8・info 2）が落ちる。
`references/` に該当する指摘は無かった。結果として error 13 − 4 = 9、warning 33 − 14 = 19、info 5 − 4 = 1 になる。
残る error 9 件と warning 19 件の合計 28 件は、すべて `scripts/aislop-accepted.json` に理由付きで登録した。
その場で修正した指摘は無い。issue の記載（error 13 / warning 33 / info 6）と実測の info 5 は 1 件差があるが、
実測を正とする。

| 分類 | 実際の指摘件数 | 登録した受け入れ件数 | 扱い | 理由 |
|------|----------------|----------------------|------|------|
| `.codex-corporate/` 配下の指摘 | 10（error 2・warning 6・info 2） | 0 | 除外 | 取り込み済みの上流コンテンツ。`lint/vendored-paths.txt` の `root:` に合わせて scan 対象から除外 |
| `.codex-personal/` 配下の指摘 | 12（error 2・warning 8・info 2） | 0 | 除外 | 取り込み済みの実行時状態。同上 |
| `config/pi/agent/extensions/content-guard.ts` の hallucinated-import | 2（error 2） | 2（`count`: 2） | 受け入れ | Pi 実行時環境が提供する `@earendil-works/pi-coding-agent` を import する拡張。2 行の同一 4 キーをまとめて `count`: 2 で受理 |
| `packages/dsh-tui-login.mjs` / `dsh-tui-models.mjs` の hallucinated-import | 7（error 7） | 7（7 エントリ各 `count`: 1） | 受け入れ | dsh と pi の実行時環境が提供するモジュールを import する接着コード。root の `package.json` へ依存を宣言せず実行時に解決する設計 |
| `packages/dsh-tui-login.mjs` の console-leftover | 10（warning 10） | 10（`count`: 10） | 受け入れ | CLI 接着コードが利用者へ出力するための `console.log/debug/info` が仕様。10 行の同一 4 キーをまとめて `count`: 10 で受理 |
| `packages/*-check.mjs` の console-leftover | 4（warning 4） | 4（4 エントリ各 `count`: 1） | 受け入れ | `*_check.mjs` は確認スクリプトで、結果を標準出力へ出すのが役割。検査対象には含めたまま受け入れる |
| `packages/dsh-tui-models.mjs` の hardcoded-url | 1（warning 1） | 1 | 受け入れ | Codex のモデル一覧エンドポイントの絶対 URL。環境依存の設定値ではない |
| `config/spark/namespace_relay.py` の complexity | 3（warning 3） | 3（3 エントリ各 `count`: 1） | 受け入れ | 今回の変更対象外の既存スクリプト。行数・ネストだけを理由に振る舞いを変えない |
| `packages/dsh-tui-models.mjs` の function-too-long | 1（warning 1） | 1 | 受け入れ | 実行時環境に依存する接着コードの一連の処理。範囲外の分割をしない |
| `package.json` の knip/skipped（info） | 1（info 1） | 0 | 合否対象外 | `info` は合否に含めない。knip を導入しない判断は下記 |

受け入れ一覧の登録件数は合計 28 件（18 エントリ）。実際の error/warning も 28 件で一致する。

### hallucinated-import の再 scan

hallucinated-import は `node_modules` の有無で結果が変わる。`npm ci` で `node_modules` を用意した正規の状態で
再 scan した結果を根拠に、上記のとおり修正ではなく理由付きの受け入れとして判断した。
`packages/dsh-tui-login.mjs` と `packages/dsh-tui-models.mjs` の指摘は、dsh と pi の実行時環境が提供する
モジュールを import する接着コードであるため、root の `package.json` に依存を足さない。

aislop 0.20.1 を `npm ci` した状態で除外 3 種（`.codex-corporate/`・`.codex-personal/`・`references/`）により
scan した実測は、hallucinated-import が `config/pi/agent/extensions/content-guard.ts` 2 件、
`packages/dsh-tui-login.mjs` 4 件、`packages/dsh-tui-models.mjs` 3 件で計 9 件、
severity 別では error 9・warning 19・info 1 だった。

## ruff と knip の判断

- **ruff**: 導入済み。`scripts/lint.sh` のゲート 4 が `ruff check --no-cache` を実行し、devShell の
  `lintTools` に `ruff` を含む。aislop 側で別途の設定は足さない。
- **knip**: 導入しない。aislop は `code-quality/knip/skipped` を `info` で出すだけで、合否には影響しない。
  導入すると knip の設定ファイルと依存が増えるが、この dotfiles リポジトリの利用範囲（Nix と Home Manager の設定、
  少数の `.mjs`/`.py` の接着コード）に対して未使用検出の利得が小さい。`info` としてログに残るので、
  必要になった時点で見直せる。
