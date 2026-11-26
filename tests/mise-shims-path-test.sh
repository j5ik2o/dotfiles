#!/usr/bin/env bash
# scripts/mise-shims-path.sh（.zshenv に埋め込む断片）を、zsh と sh で読ませるテスト。
#
# $HOME は mktemp -d に差し替え、利用者の .zshenv は読まない（zsh -f）。

# 子のシェルに渡すスクリプトは、子の側で展開させるため単引用符で書く。
# shellcheck disable=SC2016

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
snippet="$repo_root/scripts/mise-shims-path.sh"

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

shims="$root/.local/share/mise/shims"
parent="$root/takt-custom/bin"

failures=0

# run_path <shell> <PATH>: 断片を読んだ後の PATH を出す。
run_path() {
  local shell=$1 path=$2
  case "$shell" in
    zsh) env -i HOME="$root" PATH="$path" /bin/zsh -f -c '. "$1"; print -r -- "$PATH"' _ "$snippet" ;;
    sh) env -i HOME="$root" PATH="$path" /bin/sh -c '. "$1"; printf "%s\n" "$PATH"' _ "$snippet" ;;
  esac
}

expect() {
  local name=$1 want=$2 got=$3
  if [ "$got" = "$want" ]; then
    printf 'ok - %s\n' "$name"
  else
    printf 'not ok - %s\n  want: %s\n  got:  %s\n' "$name" "$want" "$got" >&2
    failures=$((failures + 1))
  fi
}

for shell in zsh sh; do
  # 親が先頭に置いたものの順を、shims がすでにあれば変えない。
  given="$parent:$shims:/usr/bin:/bin"
  expect "$shell: shims が PATH にあれば順を変えない" "$given" "$(run_path "$shell" "$given")"

  # shims が末尾にあっても積み直さない。
  given="$parent:/usr/bin:/bin:$shims"
  expect "$shell: shims が末尾にあっても動かさない" "$given" "$(run_path "$shell" "$given")"

  # launchd や cron の素の PATH では先頭に足す（/usr/bin より mise を優先）。
  expect "$shell: shims が無ければ先頭に足す" "$shims:/usr/bin:/bin" "$(run_path "$shell" "/usr/bin:/bin")"

  # 前方一致の別ディレクトリは shims とみなさない。
  given="$shims-old:/usr/bin"
  expect "$shell: 似た名前のディレクトリを shims とみなさない" "$shims:$given" "$(run_path "$shell" "$given")"
done

# 二度読んでも重ならない（入れ子の zsh -c）。
twice=$(env -i HOME="$root" PATH="/usr/bin:/bin" /bin/zsh -f -c '. "$1"; . "$1"; print -r -- "$PATH"' _ "$snippet")
expect "zsh: 二度読んでも shims は一つ" "$shims:/usr/bin:/bin" "$twice"

# 断片は読み手のシェルに変数を残さない。
leftover=$(env -i HOME="$root" PATH="/usr/bin" /bin/zsh -f -c '. "$1"; print -r -- "${_mise_shims-unset}"' _ "$snippet")
expect "zsh: 作業用の変数を残さない" "unset" "$leftover"

if ((failures > 0)); then
  printf '%d 件失敗\n' "$failures" >&2
  exit 1
fi
