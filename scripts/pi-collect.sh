#!/usr/bin/env bash
#
# pi が書き換えた設定を dotfiles リポジトリへ回収する。
# Nix 管理のファイル (models.json, agents/, extensions/content-guard.ts) は
# リポジトリの実体を直接指しているため対象外。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_dir="${HOME}/.pi/agent"
dst_dir="${repo_root}/config/pi/agent"

if [ ! -d "${src_dir}" ]; then
  echo "error: ${src_dir} が見つかりません" >&2
  exit 1
fi

# lastChangelogVersion はホストごとの実行時状態なのでリポジトリに持ち込まない。
jq 'del(.lastChangelogVersion)' "${src_dir}/settings.json" > "${dst_dir}/settings.json"

for name in pi-btw.json pi-statusline.json; do
  if [ -f "${src_dir}/${name}" ]; then
    cp "${src_dir}/${name}" "${dst_dir}/${name}"
  fi
done

echo "config/pi/agent へ回収しました。内容を確認してください:"
echo "  git diff -- config/pi"
