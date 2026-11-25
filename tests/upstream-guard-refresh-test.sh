#!/usr/bin/env bash
# scripts/upstream-guard-refresh.sh を偽の nix で走らせるテスト。
#
# ネットワークも ~/.local も触らない。nix は PATH の先頭に置いた偽物で差し替え、
# 「ビルド」した版は mktemp -d の下に作る。

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
refresh="$repo_root/scripts/upstream-guard-refresh.sh"

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

# --- 偽の nix -------------------------------------------------------------

# nix build <ref> -o <link>: 新しい「ストアのパス」を作り、link をそこへ向ける。
# FAKE_GUARD_BROKEN=1 のときは、何でも許可する壊れた版を作る。
bin="$root/bin"
mkdir -p "$bin" "$root/store"
cat >"$bin/nix" <<EOF
#!/usr/bin/env bash
set -euo pipefail
[[ \$1 == build ]] || exit 1
link=\$4
out=\$(mktemp -d "$root/store/XXXXXX-upstream-guard")
mkdir -p "\$out/bin"
if [[ \${FAKE_GUARD_BROKEN:-0} == 1 ]]; then
  printf '#!/bin/sh\nexit 0\n' >"\$out/bin/upstream-guard"
else
  printf '#!/bin/sh\nexec python3 %s "\$@"\n' "$repo_root/scripts/upstream_guard.py" >"\$out/bin/upstream-guard"
fi
chmod +x "\$out/bin/upstream-guard"
ln -sfn "\$out" "\$link"
EOF
chmod +x "$bin/nix"

state="$root/state"
run() {
  PATH="$bin:$PATH" UPSTREAM_GUARD_STATE="$state" UPSTREAM_GUARD_SYSTEM=test "$@" "$refresh" "$repo_root" >/dev/null 2>&1
}

# --- 1 回目: slot-a に作り、result を向ける --------------------------------

check "1 回目は成功する" run env
first=$(readlink "$state/result")
check "result は slot-a の版を指す" test "$first" = "$(readlink "$state/slot-a")"
check "一時のリンクは残らない" test ! -e "$state/result.tmp"

# --- 2 回目: もう片方の slot-b に作り、slot-a は前の版として残る -------------

check "2 回目は成功する" run env
second=$(readlink "$state/result")
check "result は slot-b の新しい版を指す" test "$second" = "$(readlink "$state/slot-b")"
check "前の版は slot-a に残る" test "$first" = "$(readlink "$state/slot-a")"
check "新しい版は前の版と違う" test "$first" != "$second"

# --- 壊れた版は差し替えない -------------------------------------------------

fails() { ! "$@"; }
check "拒否を返さない版では失敗する" fails run env FAKE_GUARD_BROKEN=1
check "壊れた版のときは result を変えない" test "$second" = "$(readlink "$state/result")"

if ((failures > 0)); then
  printf '%d 件失敗\n' "$failures" >&2
  exit 1
fi
