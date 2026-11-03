# Spark 用エージェント起動スクリプト

DGX Spark (10.0.1.60) の vLLM に Claude Code と Codex をつなぐ起動スクリプト。
Home Manager で `~/.local/bin` と `~/.config`、`~/.local/share` に配るため、
どのホストのどの端末からでも `claude-spark` / `codex-spark` を実行できる。

## 配置先

| ファイル | 配置先 | 用途 |
|---|---|---|
| `config/spark/claude-spark` | `~/.local/bin/claude-spark` | Claude Code を Spark の vLLM につなぐ |
| `config/spark/codex-spark` | `~/.local/bin/codex-spark` | Codex を Spark の vLLM につなぐ |
| `config/spark/namespace_relay.py` | `~/.local/share/codex-spark/namespace_relay.py` | Codex の namespace 型ツールを function 型へ変換する中継 |
| `config/spark/claude-spark-mcp.json` | `~/.config/claude-spark/mcp.json` | claude-spark が使う SearXNG の MCP 設定 |

## 前提

- `claude` と `codex` は mise で導入済み (`config/mise/mise.toml`)
- 中継は Python 3 の標準ライブラリだけで動く。追加のパッケージは不要
- 10.0.1.60 に到達できること。LAN 外のホストでもコマンド自体は配置されるが、
  実行時に接続できない

## 更新

ファイルを直したら `make apply` する。`~/.local/bin` の既存ファイルは
Home Manager によって `.backup` へ退避され、Nix store へのリンクに置き換わる。

```sh
make apply
claude-spark --version
codex-spark --version
```

## 由来

`codex-spark` と `namespace_relay.py` は `dgx-spark-configuration` リポジトリの
`ops/codex-spark/` が元。いまは dotfiles 側を正として配布する。
`claude-spark` はこれまで `~/.local/bin` にだけ置いていたため、dotfiles が
唯一の管理元になる。

`codex-spark` の内部ではプロバイダ名を `tensorfold` のまま使っている。
これはスクリプト内のローカルな名前で、接続先は `http://10.0.1.60:8000`。
