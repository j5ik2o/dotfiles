#!/usr/bin/env bash
# claude / codex のバージョンを、mise のレジストリではなく上流の一次情報に合わせる。
#
#   claude : https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md の先頭見出し
#   codex  : https://github.com/openai/codex/releases の最新安定版 (prerelease は除外)
#
# mise 側のバックエンドは minimum_release_age やレジストリ更新の遅延で
# 上流より古いバージョンを返すことがあるため、この 2 つは明示的に上書きする。
#
# 必要な環境変数: GH_TOKEN (gh CLI 用)

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mise_toml="${repo_root}/config/mise/mise.toml"

if [[ ! -f "${mise_toml}" ]]; then
  echo "error: ${mise_toml} not found" >&2
  exit 1
fi

# mise.toml の `key = "version"` 行を書き換える。
# key は TOML のキー表記そのまま (例: claude / "npm:@openai/codex")。
# キーには @ や : が含まれるため、正規表現ではなくリテラル前方一致で処理する。
update_tool() {
  local key="$1" version="$2"
  local prefix="${key} = \""
  local tmp
  tmp="$(mktemp)"

  awk -v prefix="${prefix}" -v line="${key} = \"${version}\"" '
    index($0, prefix) == 1 { found = 1; old = $0; print line; next }
    { print }
    END {
      if (!found) exit 1
      if (old != line) printf "CHANGED\t%s\n", old > "/dev/stderr"
    }
  ' "${mise_toml}" >"${tmp}" 2>"${tmp}.log" || {
    rm -f "${tmp}" "${tmp}.log"
    echo "error: key ${key} not found in ${mise_toml}" >&2
    exit 1
  }

  if [[ -s "${tmp}.log" ]]; then
    mv "${tmp}" "${mise_toml}"
    echo "${key}: $(cut -f2 "${tmp}.log") -> ${key} = \"${version}\""
  else
    rm -f "${tmp}"
    echo "${key}: ${version} (up to date)"
  fi
  rm -f "${tmp}.log"
}

# --- claude: CHANGELOG.md の先頭バージョン ---
claude_version="$(
  gh api repos/anthropics/claude-code/contents/CHANGELOG.md \
    --jq '.content' | base64 -d | sed -nE 's/^## ([0-9]+\.[0-9]+\.[0-9]+)$/\1/p' | head -1
)"

if [[ -z "${claude_version}" ]]; then
  echo "error: failed to resolve claude version from CHANGELOG.md" >&2
  exit 1
fi

# --- codex: GitHub の最新安定リリース (タグは rust-vX.Y.Z 形式) ---
codex_tag="$(
  gh release list --repo openai/codex --exclude-pre-releases --limit 1 \
    --json tagName --jq '.[0].tagName'
)"
codex_version="${codex_tag#rust-v}"

if [[ -z "${codex_version}" || "${codex_version}" == "${codex_tag}" ]]; then
  echo "error: failed to resolve codex version from releases (tag=${codex_tag})" >&2
  exit 1
fi

update_tool 'claude' "${claude_version}"
update_tool '"npm:@openai/codex"' "${codex_version}"
