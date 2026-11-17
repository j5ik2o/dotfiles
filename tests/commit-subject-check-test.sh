#!/usr/bin/env bash
# scripts/check-commit-subject.sh を偽の git 状態で走らせるテスト。
#
# ネットワークも $HOME も触らない。git の状態は mktemp -d の下に作った
# 一時リポジトリで組み立て、スクリプトはそのリポジトリを cwd にして走らせる。

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
checker="$repo_root/scripts/check-commit-subject.sh"

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

# $HOME の gitconfig に依存させず、署名も切って一時リポジトリを作る
git_fixture() {
  local dir=$1
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
}

# 偽リポジトリに空コミットを 1 つ作り、その件名を HEAD にする
commit_subject() {
  local dir=$1
  local subject=$2
  git -C "$dir" -c user.name=test -c user.email=test@example.invalid \
    -c commit.gpgsign=false commit -q --allow-empty -m "$subject"
}

# 偽リポジトリの追跡ファイル tracked.txt にステージ済みの変更を作る
stage_tracked_change() {
  local dir=$1
  printf 'staged\n' >"$dir/tracked.txt"
  git -C "$dir" add tracked.txt
}

# 偽リポジトリの追跡ファイル tracked.txt に未ステージの変更を作る
modify_tracked_unstaged() {
  local dir=$1
  printf 'unstaged\n' >>"$dir/tracked.txt"
}

# 偽リポジトリを cwd にしてスクリプトを走らせ、終了コードを status に入れる
run_checker() {
  local dir=$1
  shift
  status=0
  ( cd "$dir" && bash "$checker" "$@" ) >"$root/stdout" 2>"$root/stderr" || status=$?
}

# --- (a) 追跡変更あり＋HEAD が takt 件名: 検査をスキップして通る ---------

case_a="$root/a"
git_fixture "$case_a"
commit_subject "$case_a" 'takt: implement something'
stage_tracked_change "$case_a"
modify_tracked_unstaged "$case_a"

run_checker "$case_a" --head

check "(a) 追跡変更ありでは takt 件名でも exit 0" test "$status" -eq 0
check "(a) スキップした旨を stderr に出す" grep -q 'スキップ' "$root/stderr"
check "(a) スキップの通知は stdout に出さない" test ! -s "$root/stdout"

# --- (b) 追跡変更なし＋HEAD が takt 件名: 従来どおり落ちる --------------

case_b="$root/b"
git_fixture "$case_b"
commit_subject "$case_b" 'takt: implement something'

run_checker "$case_b" --head

check "(b) 追跡変更なしでは takt 件名で exit 1" test "$status" -eq 1
check "(b) 形式違反の理由を stderr に出す" grep -q 'Conventional Commits' "$root/stderr"

# --- (c) 追跡変更なし＋HEAD が正しい件名: 通る --------------------------

case_c="$root/c"
git_fixture "$case_c"
commit_subject "$case_c" 'fix(ci): resolve node from config/mise when pre-installing'

run_checker "$case_c" --head

check "(c) 追跡変更なしの正しい件名は exit 0" test "$status" -eq 0
check "(c) 素通りを報告しない" sh -c "! grep -q 'スキップ' '$root/stderr'"

# --- (d) 未追跡の .takt 配下だけ＋HEAD が takt 件名: (b) と同じ -----------

case_d="$root/d"
git_fixture "$case_d"
commit_subject "$case_d" 'takt: implement something'
mkdir -p "$case_d/.takt"
printf 'run\n' >"$case_d/.takt/run.log"
printf 'log\n' >"$case_d/.takt-verify-done.log"

run_checker "$case_d" --head

check "(d) 未追跡ファイルでは素通りしない (exit 1)" test "$status" -eq 1

# --- (e) 追跡変更があっても --subject は常に検査する ---------------------

case_e="$root/e"
git_fixture "$case_e"
commit_subject "$case_e" 'fix(ci): resolve node from config/mise when pre-installing'
stage_tracked_change "$case_e"

run_checker "$case_e" --subject 'fix: nix files'
check "(e) --subject の形式違反は追跡変更があっても exit 1" test "$status" -eq 1

run_checker "$case_e" --subject 'fix(commit-subject): skip the head check while tracked changes are uncommitted'
check "(e) --subject の正しい題名は exit 0" test "$status" -eq 0

# --- (f) 追跡変更が未ステージだけでも素通りする -------------------------

case_f="$root/f"
git_fixture "$case_f"
commit_subject "$case_f" 'fix(ci): resolve node from config/mise when pre-installing'
stage_tracked_change "$case_f"
git -C "$case_f" -c user.name=test -c user.email=test@example.invalid \
  -c commit.gpgsign=false commit -q -m 'fix(ci): keep the tracked file'
commit_subject "$case_f" 'takt: implement something'
modify_tracked_unstaged "$case_f"

run_checker "$case_f" --head

check "(f) 未ステージの追跡変更でも takt 件名で exit 0" test "$status" -eq 0

# --- 結果 -----------------------------------------------------------------

if [ "$failures" -ne 0 ]; then
  printf '%d 件失敗\n' "$failures" >&2
  exit 1
fi
printf 'すべて成功\n'
