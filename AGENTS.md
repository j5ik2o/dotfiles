# Dotfiles プロジェクト メモ

Nix + Home Manager + nix-darwin で管理する個人用 dotfiles。

緑の定義は `make done` ひとつだけ。`format-check` → `check` → `test-activation` → `lint` の順に走る。

## ルールと強制手段

強制欄が空のルールは置かない。空欄は飾りの印になる。

| ルール | 強制 |
| --- | --- |
| flake の output 名・platform・home パスを変えない | `checks.flake-outputs` |
| 管理対象ファイルを `force = true` で上書きしない。バックアップ拡張子を必ず設定する。手で編集したファイルは `make apply` を生き延びる | `checks.backup-policy` |
| unfree の許可は `homeConfigurations` と `darwinConfigurations` で一致させる | `checks.unfree-parity` |
| `checks.<system>.*` に並ぶ自作パッケージはビルドできる状態を保つ | その derivation のビルド（`make check`） |
| Nix は `nixfmt`、Lua は `stylua` で整形する | `make lint`（devShell 固定版） |
| shell は shellcheck、Python は ruff、未使用の Nix 束縛は deadnix を通す | `make lint` |
| ベンダーの範囲は `lint/vendored-paths.txt` だけが決める。配下に足したファイルは manifest に載せる | `scripts/lint.sh` の manifest ゲート |
| シェルは `scripts/*.sh` に置き、`tests/` のテストで振る舞いを固定する。Nix 文字列の中にシェルを書かない | shellcheck と `make test-activation`。Nix 文字列の中はどちらも届かず判断 |
| 配備は Nix（Home Manager, `modules/`）。`chezmoi/` は秘密情報だけ。同じパスを両方に持たせない | 判断（`docs/chezmoi.md`） |
| ツールの版は `config/mise/mise.toml` だけが持つ。単一パッケージだけの版上げはしない | 判断 |
| GUI アプリは Homebrew cask、CLI は Nix | 判断（オペレータの指示） |
| `references/`, `.codex-personal/`, `.codex-corporate/` は上流由来の内容とコミット済み実行時状態。編集しない | 判断（範囲は manifest が示す） |
| 使う当てのない設定オプションを足さない | 判断 |
| 個人用なので破壊的変更を許容する。`make gc` の後も既存環境が壊れないようにする | 判断 |
| 日本語で応対する | 判断 |
| コミット件名は Conventional Commits に合わせ、対象ではなく原因を書く | `commit-subject`（CI。PR タイトルと、1 コミットの PR ならその主題も見る）と `make commit-subject-check`（HEAD） |

Neovim、chezmoi、各ツールの詳細は `docs/` にある。
