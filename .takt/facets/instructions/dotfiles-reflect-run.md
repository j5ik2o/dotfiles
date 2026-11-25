分類が「ユーザー側のみ」の変更を、実環境へ反映してください。

## 手順

1. 主チェックアウトが main で、未コミットの変更が無いことを確認する
2. flake.lock から home-manager の rev を読む
3. 次の形で反映する。
   `nix run github:nix-community/home-manager/<rev> -- switch -b backup --flake '.#j5ik2o-mac-mini'`
4. 反映後の確認をする。変更した設定が実物に表れていること（対象コマンド
   の出力、設定ファイルの symlink 先など）を確かめる

## 禁止

- sudo を実行しない
- make apply と make secrets-apply を実行しない
- 反映に失敗したら、無理に進めず、理由を報告して止まる

## 報告

reflect-report.md に、使った rev、反映コマンドの結果、確認の内容と
結果を書く。
