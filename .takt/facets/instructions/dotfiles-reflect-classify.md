マージされたプルリクエストの差分を読み、反映の種類を判定してください。
編集はしません。読み取りと報告だけです。

## 参照するもの

- タスク本文で指定されるプルリクエストの差分（gh などで実物を読む）
- knowledge の dotfiles-rules（分類の基準）

## 判定

- 差分が modules/ や config/ など、ユーザー側 Home Manager の対象だけ
  なら「ユーザー側のみ」
- darwin/ 配下や nix-darwin の設定を含むなら「darwin 側を含む」
- chezmoi/ 配下や秘密情報に関わる変更を含むなら「秘密情報を含む」
- 判定に必要な情報が読めなければ「判定できない」

## 報告

reflect-classification.md に、判定と根拠（対象ファイルの一覧）を書く。
darwin 側を含む場合は「make apply 待ち」、秘密情報を含む場合は
「make secrets-apply 待ち」と明記する。
