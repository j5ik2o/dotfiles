#!/usr/bin/env bash
#
# pi が書き換えた設定を dotfiles リポジトリへ回収する。
# Nix 管理のファイル (models.json, agents/, extensions/content-guard.ts) は
# リポジトリの実体を直接指しているため対象外。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_dir="${HOME}/.pi/agent"
dst_dir="${repo_root}/config/pi/agent"

if [ ! -f "${src_dir}/settings.json" ]; then
  echo "error: ${src_dir}/settings.json が見つかりません" >&2
  exit 1
fi

# lastChangelogVersion はホストごとの実行時状態なのでリポジトリに持ち込まない。
# リダイレクト先が空になるとリポジトリ側の設定を壊すため、一時ファイルへ
# 書いて jq の成功を確認してから置き換える。
tmp_settings="$(mktemp "${dst_dir}/.settings.json.XXXXXX")"
trap 'rm -f "${tmp_settings}"' EXIT
jq 'del(.lastChangelogVersion)' "${src_dir}/settings.json" > "${tmp_settings}"
mv "${tmp_settings}" "${dst_dir}/settings.json"
trap - EXIT

for name in pi-btw.json pi-statusline.json; do
  if [ -f "${src_dir}/${name}" ]; then
    cp "${src_dir}/${name}" "${dst_dir}/${name}"
  fi
done

echo "config/pi/agent へ回収しました。内容を確認してください:"
echo "  git diff -- config/pi"
