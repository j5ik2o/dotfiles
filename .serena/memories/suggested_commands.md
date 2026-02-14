# Suggested Commands

## 日常ワークフロー
| コマンド | 説明 |
|---------|------|
| `make apply` | 設定を適用（macOS: darwin-rebuild, Linux: home-manager） |
| `make build` | ビルドのみ（dry-run、適用しない） |
| `make plan` | ビルド＋差分表示（terraform plan のように） |
| `make rollback` | 前の世代にロールバック |
| `make update` | flake inputs を更新 |

## 推奨ワークフロー
```
make update → make apply → 問題あれば make rollback
```

## チェック・テスト
| コマンド | 説明 |
|---------|------|
| `make check` | `nix flake check --no-build` |
| `make check-update` | パッケージ更新の差分確認（lockfileは変更しない） |
| `make nvim-test` | Neovim設定テスト |
| `make host-info` | 検出されたホスト/設定情報を表示 |

## フォーマット
| コマンド | 説明 |
|---------|------|
| `make fmt` | 全 .nix ファイルをフォーマット（nixfmt使用） |

## クリーンアップ
| コマンド | 説明 |
|---------|------|
| `make clean` | ビルド成果物 (result, .direnv) を削除 |
| `make nvim-clean` | Neovimキャッシュ削除 (share/state/cache) |
| `make zsh-clean` | zshキャッシュ削除 (sheldon, starship等) |
| `make gc` | Nixガベージコレクション |
| `make gc-old` | 30日以上前の世代を削除 |

## シークレット管理
| コマンド | 説明 |
|---------|------|
| `make secrets-init` | chezmoi初期化 |
| `make secrets-diff` | シークレットの差分確認 |
| `make secrets-apply` | 1Passwordからシークレット適用 |

## CLIProxyAPI
| コマンド | 説明 |
|---------|------|
| `make cliproxyapi-start` | バックグラウンドで起動 |
| `make cliproxyapi-stop` | 停止 |
| `make cliproxyapi-status` | 状態確認 |

## 初回セットアップ
| コマンド | 説明 |
|---------|------|
| `make init` | 初回インストール（OS自動判定） |
| `make init-darwin` | macOS初回セットアップ |
| `make init-linux` | Linux初回セットアップ |

## システムコマンド (Darwin)
| コマンド | 説明 |
|---------|------|
| `git` | バージョン管理 |
| `rg` (ripgrep) | 高速テキスト検索 |
| `fd` | 高速ファイル検索 |
| `jq` / `yq` | JSON/YAML処理 |
| `bat` | catの高機能版 |
| `eza` | lsの高機能版 |
| `fzf` | ファジーファインダー |
| `gh` | GitHub CLI |
| `ghq` | リポジトリ管理 |
| `jj` | Git互換VCS (jujutsu) |
