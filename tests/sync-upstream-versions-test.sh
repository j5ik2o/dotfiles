#!/usr/bin/env bash
# scripts/sync-upstream-versions.sh を、一時のリポジトリ配置と偽の gh で走らせるテスト。
#
# ネットワークも $HOME も触らない。偽の gh は GitHub の contents API と同じく、
# 1MB を超える CHANGELOG.md の中身を JSON では返さず、raw の指定でだけ返す。

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

failures=0

check() {
  local name=$1
  shift
  if "$@"; then
    printf 'ok - %s\n' "$name"
  else
    printf 'not ok - %s\n' "$name" >&2
    failures=$((failures + 1))
  fi
}

# 先頭の見出しが 2.1.331 で、1MB を超える CHANGELOG.md
{
  printf '# Changelog\n\n## 2.1.331\n\n- latest\n\n'
  for i in $(seq 330 -1 1); do
    printf '## 2.1.%d\n\n' "$i"
    head -c 4000 /dev/zero | tr '\0' 'x'
    printf '\n\n'
  done
} >"$root/CHANGELOG.md"

mkdir -p "$root/bin"
cat >"$root/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"Accept: application/vnd.github.raw"*contents/CHANGELOG.md*)
    cat "$CHANGELOG" ;;
  *contents/CHANGELOG.md*)
    # 1MB を超えるファイルの JSON は content が空 (encoding: none)。--jq .content の結果も空
    echo "" ;;
  "release list"*)
    echo "rust-v0.172.0" ;;
  *)
    echo "unexpected gh call: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$root/bin/gh"

work="$root/repo"
mkdir -p "$work/scripts" "$work/config/mise"
cp "$repo_root/scripts/sync-upstream-versions.sh" "$work/scripts/"
cat >"$work/config/mise/mise.toml" <<'EOF'
[tools]
claude = "2.1.322"
"npm:@openai/codex" = "0.167.2"
EOF

PATH="$root/bin:$PATH" CHANGELOG="$root/CHANGELOG.md" \
  bash "$work/scripts/sync-upstream-versions.sh" >"$root/out" 2>&1
status=$?

check "fixture CHANGELOG.md is over 1MB" test "$(wc -c <"$root/CHANGELOG.md")" -gt 1048576
check "exits 0" test "$status" -eq 0
check "writes the claude version from the first heading" \
  grep -qx 'claude = "2.1.331"' "$work/config/mise/mise.toml"
check "writes the codex version from the latest release" \
  grep -qx '"npm:@openai/codex" = "0.172.0"' "$work/config/mise/mise.toml"

if [ "$failures" -ne 0 ]; then
  cat "$root/out" >&2
  printf '%d failure(s)\n' "$failures" >&2
  exit 1
fi
