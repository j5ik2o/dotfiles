# dotfiles の規約（全ステップ共通）

dotfiles（Nix と Home Manager によるマシンの設定管理）で作業する際の規約。
正はリポジトリの文書（AGENTS.md、CLAUDE.md、Makefile）であり、本ファセットは
その実行用要約である。矛盾したらリポジトリの文書が優先する。

## 緑の判定

- 緑の判定は `make done` のみである（commit-subject-check、format-check、
  check、test-activation、lint の一式）。部分的な実行の成功を緑と言わない
- check は全システムの flake 評価とビルドを含むため、時間がかかる

## 版数と配置

- ツールやコマンドの版数は `config/mise/mise.toml` だけに置く。
  単独パッケージだけの版上げはしない（dotfiles 全体の更新として扱う）
- 配置は Nix と Home Manager で行い、定義は `modules/` に置く。
  `chezmoi/` は秘密情報だけを扱う
- GUI アプリは Homebrew cask、CLI は Nix で入れる

## コミット

- 件名は Conventional Commits で、原因を名乗る
- Co-Authored-By のトレイラーは付けない

## 反映の分割

- ユーザー側の Home Manager は、flake.lock で固定した home-manager で
  反映してよい。形は `nix run github:nix-community/home-manager/<rev> --
  switch -b backup --flake '.#<host>'` で、rev は flake.lock から読む
- `make apply`（nix-darwin、sudo が要る）と `make secrets-apply` は
  オーナー専用である。実行せず、「make apply 待ち」「make secrets-apply
  待ち」と報告する。sudo は実行しない
- 未マージの変更を実環境へ反映しない。反映はマージ後に main に対して行う

## プルリクエスト

- main のブランチ保護の必須チェックは `Check unresolved comments` である
- レビューボット（CodeRabbit、Bugbot など）のコメントは無視しない。
  読み、中身で判断し、直すか、理由を述べて反論する。未解決のスレッドが
  残るプルリクエストをマージ可能と言わない

## 値の確認

- Run の ID、ターミナル、モデル、作業ツリーなどの現在の値は、推測で
  既定値に埋めない。リポジトリと CLI の実物で確認し、確認できない値は
  「未確認」と書く

## 作業範囲

- ゴールやタスクで指定された範囲の外は書かない。範囲外の変更が必要に
  なったら、勝手に広げず、報告して止まる
- ボード（プロジェクト #6「dotfiles」）の状態移動のうち、自動ルールで動かない分は manager がゴールごとに行う。対象 issue のタスクを投入する時点で `.takt/scripts/board-move.sh <issue番号> "In Progress"` を実行し、ゴールのプルリクエストを作成した時点で `.takt/scripts/board-move.sh <issue番号> "In Review"` を実行する。追加時の Todo、終了時の Done、マージ時の Done、再オープン時の Todo は GitHub の自動ルールが担うので触らない。対象 issue が無いゴールでは実行しない。

## 見回りの記録

- 見回りでは、failed と pending のタスクごとに、次の手と、その手を
  実行する条件を作業記録（ゴールの workLog）へ書く
- 対応した結果は、ゴールごとに作業記録へ残す

## ドメインの値の型

- ドメインの概念を表す値を専用の型（ドメインプリミティブ）にする決まり（正は ddd-principles の方針ページ knowledge/positions/domain-model-usage-decisions.md の規則 value-object/type-domain-values/use-a-dedicated-type、2026-10-21 に加藤が決定）は、ドメインモデルを持つ開発プロジェクトに向けたものである
- このリポジトリは Nix と Home Manager によるマシンの設定を扱うプロジェクトであり、ドメインモデルを持つ開発プロジェクトではないため、この決まりを必須としては適用しない（2026-11-14 にオーナーが判断した）
- 補助的なスクリプトで不変条件を持つ値を扱う場合は、専用の型にするか、値を受け取る境界での検証に集める形を参考にしてよいが、機械ゲートにはしない
