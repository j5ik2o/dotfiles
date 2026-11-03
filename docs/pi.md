# pi 設定の管理

`~/.pi/agent` の設定を `config/pi/agent` に置き、Home Manager で各ホストへ配る。
pi 本体のバージョンは `config/mise/mise.toml` で管理している。

## 管理対象と方式

pi が起動中に書き換えるファイルは Nix の読み取り専用リンクにできないため、
方式を分けている。

| パス | 方式 | 理由 |
|---|---|---|
| `models.json` | Nix リンク | pi は読むだけ |
| `agents/*.md` | Nix リンク | pi は読むだけ |
| `extensions/content-guard.ts` | Nix リンク | pi は読むだけ |
| `settings.json` | activation でコピー | モデル切替・テーマ・パッケージ導入で pi が保存する |
| `pi-btw.json` | activation でコピー | プラグインが保存する |
| `pi-statusline.json` | activation でコピー | プラグインが保存する |

コピー対象は `make apply` のたびにリポジトリの内容で上書きされる。上書き前に
内容が違えば `~/.pi/agent/.dotfiles-backup/` へ直前のファイルを退避する。

## 管理しないもの

次のファイルは他のツールが所有しているか、ホスト固有・実行時データのため管理しない。

- `extensions/orca-*.ts` — Orca が上書きする
- `extensions/herdr-agent-state.ts` — Herdr が上書きする
- `extensions/subagent/` — 置かない。`npm:pi-subagents` が `subagent` ツールを
  提供するため、手動コピーが残っているとツール名が衝突して pi が起動しない。
  activation で見つけた場合は `.dotfiles-backup/subagent-legacy/` へ退避する
- `auth.json`, `trust.json`, `sessions/`, `pstack/`, `git/`, `npm/`,
  `models-store.json`, `provider-failover-state.json` — 資格情報・実行時データ
- `skills/` — Orca のスキル管理 (`~/.agents/skills` への symlink)

## モデル一覧の更新

`models.json` の `id` は、サーバーの `/v1/models` が返す ID と完全一致させる。
pi は静的な定義なので、サーバー側のモデルが変わっても自動では追従しない。

```sh
curl -s http://10.0.1.60:8000/v1/models | jq -r '.data[].id'
```

セットアップを変えたときは、次の 3 か所を更新して `make apply` する。

- `config/pi/agent/models.json` の `models`
- `config/pi/agent/settings.json` の `defaultModel`
- `config/pi/agent/pi-btw.json` の `model`

## 運用

TUI でモデルやステータスラインを変えたときは、変更をリポジトリへ回収してから
コミットする。回収しないまま `make apply` すると、コピー対象の変更は
リポジトリの内容で上書きされる。

```sh
make pi-collect   # ~/.pi/agent の変更を config/pi/agent へ回収
git diff -- config/pi
git add config/pi && git commit
```

`lastChangelogVersion` はホストごとの実行時状態なので、回収時に取り除いている。

新しいエージェント定義を足すときは `config/pi/agent/agents/` に `.md` を置き、
`git add` してから `make apply` する。flake は git 管理下のファイルしか
評価しないため、未追跡のファイルは反映されない。
