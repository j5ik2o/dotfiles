#!/usr/bin/env bash
# scripts/install-muse.sh を偽の環境で走らせるテスト。
#
# ネットワークも $HOME も触らない。外部コマンドは PATH の先頭に置いた偽物で差し替え、
# インストール先は mktemp -d の下に作る。

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
installer="$repo_root/scripts/install-muse.sh"

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

# --- 偽の環境 -------------------------------------------------------------

# 配布ページの代わり。DMG リンクは \/ でエスケープされた形で置く。
page_fixture="$root/page.html"
cat >"$page_fixture" <<'EOF'
<a href="https:\/\/cdn.example.invalid\/Muse-2.0.dmg?X-Amz-Signature=deadbeef">Download</a>
EOF

bin="$root/bin"
mkdir -p "$bin"

cat >"$bin/curl" <<EOF
#!/usr/bin/env bash
prev=
out=
for arg in "\$@"; do
  if [ "\$prev" = "-o" ]; then out=\$arg; fi
  prev=\$arg
done
printf 'curl\n' >>"\$MUSE_TEST_FAKE_LOG"
if [ -z "\$out" ]; then exit 0; fi
cat "$page_fixture" >"\$out"
EOF

cat >"$bin/hdiutil" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "attach" ]; then
  prev=
  mount=
  for arg in "$@"; do
    if [ "$prev" = "-mountpoint" ]; then mount=$arg; fi
    prev=$arg
  done
  mkdir -p "$mount/Muse.app/Contents/MacOS"
  printf 'new\n' >"$mount/Muse.app/Contents/MacOS/muse"
fi
exit 0
EOF

cat >"$bin/ditto" <<'EOF'
#!/usr/bin/env bash
mkdir -p "$2"
/bin/cp -R "$1/." "$2/"
EOF

cat >"$bin/codesign" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-dv" ]; then
  printf 'TeamIdentifier=%s\n' "${MUSE_TEST_TEAM_ID:?}"
fi
exit 0
EOF

cat >"$bin/defaults" <<'EOF'
#!/usr/bin/env bash
if [ -z "${MUSE_TEST_INSTALLED_VERSION:-}" ]; then exit 1; fi
printf '%s\n' "$MUSE_TEST_INSTALLED_VERSION"
EOF

chmod +x "$bin/curl" "$bin/hdiutil" "$bin/ditto" "$bin/codesign" "$bin/defaults"

# 最後の入れ替えだけ失敗させる mv。戻す mv は通す。
failswap_bin="$root/bin-failswap"
mkdir -p "$failswap_bin"
cat >"$failswap_bin/mv" <<'EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  case $arg in
    */.Muse-staging/*)
      printf 'mv: swap denied\n' >&2
      exit 1
      ;;
  esac
done
exec /bin/mv "$@"
EOF
chmod +x "$failswap_bin/mv"

export MUSE_TEST_TEAM_ID=V9WTTPBFK9
export MUSE_TEST_FAKE_LOG="$root/curl.log"
: >"$MUSE_TEST_FAKE_LOG"

app_dir=
install_status=

# 偽のパスでインストーラを走らせ、終了コードを install_status に入れる。
run_installer() {
  local prefix_bin=$1
  local log=$2
  shift 2
  install_status=0
  PATH="$prefix_bin:$bin:$PATH" "$installer" \
    --app-dir "$app_dir" \
    --page-url "https://page.invalid/muse/download/" \
    --team-id V9WTTPBFK9 \
    "$@" >"$log" 2>&1 || install_status=$?
}

# --- 入れ替えが失敗しても既存アプリが残る ---------------------------------

case_dir="$root/swap-failure"
app_dir="$case_dir/applications"
mkdir -p "$app_dir/Muse.app/Contents/MacOS"
printf 'previous\n' >"$app_dir/Muse.app/Contents/MacOS/muse"
export MUSE_TEST_INSTALLED_VERSION=1.0

run_installer "$failswap_bin" "$root/swap-failure.log"

check "入れ替え失敗でも exit 0 (activation を止めない)" test "$install_status" -eq 0
check "既存アプリが残る" test -f "$app_dir/Muse.app/Contents/MacOS/muse"
check "既存アプリの中身が元のまま" test "$(cat "$app_dir/Muse.app/Contents/MacOS/muse")" = previous
check "ステージングが残らない" test ! -e "$app_dir/.Muse-staging"
check "バックアップが残らない" test ! -e "$app_dir/.Muse.app.old"
check "警告が出る" grep -q "Muse install failed" "$root/swap-failure.log"

# --- 正常時は入れ替わる (偽の環境が本物の経路を通ることの確認) ------------

case_dir="$root/swap-success"
app_dir="$case_dir/applications"
mkdir -p "$app_dir/Muse.app/Contents/MacOS"
printf 'previous\n' >"$app_dir/Muse.app/Contents/MacOS/muse"
export MUSE_TEST_INSTALLED_VERSION=1.0

run_installer "$bin" "$root/swap-success.log"

check "正常時は exit 0" test "$install_status" -eq 0
check "新しいアプリに入れ替わる" grep -q new "$app_dir/Muse.app/Contents/MacOS/muse"
check "古いアプリの控えは残らない" test ! -e "$app_dir/.Muse.app.old"
check "インストールを報告する" grep -q "Muse 2.0 installed" "$root/swap-success.log"

# --- dry-run は何も変えない ----------------------------------------------

case_dir="$root/dry-run"
app_dir="$case_dir/applications"
mkdir -p "$app_dir/Muse.app/Contents/MacOS"
printf 'previous\n' >"$app_dir/Muse.app/Contents/MacOS/muse"
export MUSE_TEST_INSTALLED_VERSION=1.0
: >"$MUSE_TEST_FAKE_LOG"

before=$(cd "$case_dir" && find . | LC_ALL=C sort)
run_installer "$bin" "$root/dry-run.log" --dry-run
after=$(cd "$case_dir" && find . | LC_ALL=C sort)

check "dry-run は exit 0" test "$install_status" -eq 0
check "dry-run はファイルを作らない" test "$before" = "$after"
check "dry-run はアプリを変えない" test "$(cat "$app_dir/Muse.app/Contents/MacOS/muse")" = previous
check "dry-run はネットワークを取りに行かない" test ! -s "$MUSE_TEST_FAKE_LOG"
check "dry-run は予定を出す" grep -q "^dry-run:" "$root/dry-run.log"

# --- 引数が足りなければ失敗する ------------------------------------------

app_dir="$root/args"
install_status=0
PATH="$bin:$PATH" "$installer" --app-dir "$app_dir" >/dev/null 2>&1 || install_status=$?
check "引数不足は exit 2" test "$install_status" -eq 2

# --- 結果 -----------------------------------------------------------------

if [ "$failures" -ne 0 ]; then
  printf '%d 件失敗\n' "$failures" >&2
  exit 1
fi
printf 'すべて成功\n'
