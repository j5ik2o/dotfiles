#!/usr/bin/env bash
# Meta の Muse を配布ページから取得して ~/Applications へ入れる。
#
# Home Manager の activation 文字列に埋め込むと lint もテストもできないため、
# 単体のスクリプトに切り出した。ホスト固有の値はすべて引数で受け取る。
#
#   install-muse.sh --app-dir DIR --page-url URL --team-id ID [--dry-run]
#
# 外部コマンドは PATH から解決する。テストが偽のコマンドを差し込めるようにするため。
#
# 扱った失敗は activation を止めない契約なので、警告を出して exit 0 で終わる。
# 引数が足りない場合だけ exit 2。

set -euo pipefail

app_dir=
page_url=
team_id=
dry_run=0

warn() { printf 'WARNING: %s\n' "$*" >&2; }

# 扱った失敗をここで打ち切る。
give_up() {
  warn "$1"
  exit 0
}

usage() {
  printf 'usage: %s --app-dir DIR --page-url URL --team-id ID [--dry-run]\n' "${0##*/}" >&2
}

while (($# > 0)); do
  opt=$1
  case $opt in
    --dry-run)
      dry_run=1
      shift
      continue
      ;;
    --app-dir | --page-url | --team-id) ;;
    *)
      usage
      exit 2
      ;;
  esac
  if (($# < 2)); then
    usage
    exit 2
  fi
  case $opt in
    --app-dir) app_dir=$2 ;;
    --page-url) page_url=$2 ;;
    --team-id) team_id=$2 ;;
  esac
  shift 2
done

if [ -z "$app_dir" ] || [ -z "$page_url" ] || [ -z "$team_id" ]; then
  usage
  exit 2
fi

app="$app_dir/Muse.app"
# codesign はディレクトリ名が Muse.app でないと署名を検出しないため、
# 隠しディレクトリの中に Muse.app という名前で展開する。
staging_dir="$app_dir/.Muse-staging"
staging="$staging_dir/Muse.app"
backup="$app_dir/.Muse.app.old"

installed=
if [ -d "$app" ]; then
  installed=$(defaults read "$app/Contents/Info" CFBundleShortVersionString 2>/dev/null || true)
fi

if ((dry_run)); then
  # 更新の有無は配布ページを取らないと分からない。dry-run は通信も書き込みもしない。
  printf 'dry-run: Muse %s が %s にある\n' "${installed:-未インストール}" "$app"
  printf 'dry-run: 新しい版があれば %s から取得し、team %s の署名を検証して入れ替える\n' \
    "$page_url" "$team_id"
  exit 0
fi

if ! tmp=$(mktemp -d); then
  give_up "Muse tmpdir creation failed"
fi
mounted=0
cleanup() {
  if [ "$mounted" -eq 1 ]; then
    hdiutil detach "$tmp/mnt" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp"
  rm -rf "$staging_dir"
}
trap cleanup EXIT

# 素の curl は DMG リンクを含まない HTML を返し、UA だけでも 400 になる。
page="$tmp/page.html"
if ! curl -fsSL --connect-timeout 10 --max-time 60 \
  -A 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36' \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' \
  -H 'Accept-Language: en-US,en;q=0.9' \
  -H 'sec-ch-ua: "Chromium";v="141", "Not?A_Brand";v="24"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'Sec-Fetch-Dest: document' \
  -H 'Sec-Fetch-Mode: navigate' \
  -H 'Sec-Fetch-Site: none' \
  -H 'Sec-Fetch-User: ?1' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -o "$page" \
  "$page_url"; then
  give_up "Muse download page fetch failed"
fi

url=$(sed 's#\\/#/#g' "$page" | grep -oE 'https://[^"]+\.dmg\?[^"]+' | head -1 || true)
if [ -z "$url" ]; then
  give_up "Muse DMG link not found"
fi

path=$(printf '%s\n' "$url" | sed 's/?.*$//')
available=$(basename "$path" | sed 's/^Muse-//; s/\.dmg$//')
if [ -z "$available" ]; then
  give_up "Muse version parse failed"
fi

# 配布ページが古い DMG を指したときにダウングレードしない。
if [ -n "$installed" ] &&
  [ "$(printf '%s\n%s\n' "$installed" "$available" | sort -V | tail -n 1)" = "$installed" ]; then
  printf 'Muse %s is up to date\n' "$installed"
  exit 0
fi

# 署名付きクエリを落とすと CDN が 403 を返すため、URL はそのまま使う。
dmg="$tmp/Muse.dmg"
if ! curl -fsSL --connect-timeout 10 --max-time 600 -o "$dmg" "$url"; then
  give_up "Muse DMG download failed"
fi

mkdir -p "$tmp/mnt"
if ! hdiutil attach -nobrowse -readonly -mountpoint "$tmp/mnt" "$dmg" >/dev/null; then
  give_up "Muse DMG mount failed"
fi
mounted=1

mkdir -p "$app_dir"
rm -rf "$staging_dir"
mkdir -p "$staging_dir"
if ! ditto "$tmp/mnt/Muse.app" "$staging"; then
  give_up "Muse copy failed"
fi

if ! codesign --verify --deep --strict "$staging" >/dev/null 2>&1; then
  give_up "Muse signature verification failed"
fi
if [ "$(codesign -dv --verbose=2 "$staging" 2>&1 | sed -n 's/^TeamIdentifier=//p')" != "$team_id" ]; then
  give_up "Muse team identifier mismatch"
fi

rm -rf "$backup"
if [ -d "$app" ] && ! mv "$app" "$backup"; then
  give_up "Muse backup failed"
fi
if ! mv "$staging" "$app"; then
  # 入れ替えに失敗したら元のアプリを戻す。ここで失敗しても打てる手は無いので best-effort。
  if [ -d "$backup" ]; then
    mv "$backup" "$app" || true
  fi
  give_up "Muse install failed"
fi
rm -rf "$backup"

printf 'Muse %s installed\n' "$available"
