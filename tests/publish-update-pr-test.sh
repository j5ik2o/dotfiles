#!/usr/bin/env bash
# scripts/publish-update-pr.sh を、一時の bare リポジトリ (origin) と偽の gh で走らせるテスト。
#
# ネットワークも $HOME も触らない。gh は PATH の偽物に差し替え、呼ばれた引数を記録する。

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
publisher="$repo_root/scripts/publish-update-pr.sh"

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

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

title="chore(nix): update flake inputs"
branch=automation/update

# 偽の gh: pr list は $GH_PR_LIST の JSON に --jq を当てて返し、呼び出しを $GH_LOG に残す
mkdir -p "$root/bin"
cat >"$root/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$GH_LOG"
if [ "$1 $2" = "pr list" ]; then
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "--jq" ]; then
      printf '%s' "${GH_PR_LIST:-[]}" | jq -r "$2"
      exit 0
    fi
    shift
  done
fi
EOF
chmod +x "$root/bin/gh"
export PATH="$root/bin:$PATH"

commit_file() {
  local dir=$1 content=$2 subject=$3
  printf '%s\n' "$content" >"$dir/lock"
  git -C "$dir" add lock
  git -C "$dir" commit -q -m "$subject"
}

# origin (bare) と、main に 1 コミットある作業コピーを作る
setup() {
  local name=$1
  local dir="$root/$name"
  git init -q --bare -b main "$dir/origin.git"
  git init -q -b main "$dir/seed"
  commit_file "$dir/seed" v1 "init"
  git -C "$dir/seed" push -q "$dir/origin.git" main
  printf '%s' "$dir"
}

# origin の main から作業コピーを取り、更新のコミットを HEAD に作る
updated_clone() {
  local dir=$1 content=$2
  rm -rf "$dir/work"
  git clone -q "$dir/origin.git" "$dir/work"
  commit_file "$dir/work" "$content" "$title"
}

run_publisher() {
  local dir=$1
  : >"$dir/gh.log"
  (cd "$dir/work" && GH_LOG="$dir/gh.log" bash "$publisher" "$branch" main "$title") \
    >"$dir/out" 2>&1
}

branch_tip() { git -C "$1/origin.git" rev-parse --verify --quiet "refs/heads/$branch"; }
created_pr() { grep -q '^pr create' "$1/gh.log"; }
not() { ! "$@"; }

open_pr='[{"url":"https://example.invalid/pull/1","isCrossRepository":false}]'
fork_pr='[{"url":"https://example.invalid/pull/9","isCrossRepository":true}]'

# 1. 枝も PR も無い: push して PR を作る
d=$(setup new)
updated_clone "$d" v2
GH_PR_LIST='[]' run_publisher "$d"
check "new: pushes the update branch" test "$(branch_tip "$d")" = "$(git -C "$d/work" rev-parse HEAD)"
check "new: creates a PR" created_pr "$d"

# 2. 開いた PR の枝が同じ中身・同じ基底: push も PR 作成もしない
d=$(setup same)
updated_clone "$d" v2
GH_PR_LIST='[]' run_publisher "$d"
before=$(branch_tip "$d")
updated_clone "$d" v2
GH_PR_LIST=$open_pr run_publisher "$d"
check "same: keeps the branch tip" test "$(branch_tip "$d")" = "$before"
check "same: does not create a PR" not created_pr "$d"

# 3. 中身が変わった: 枝を作り直し、既存の PR は作らない
d=$(setup changed)
updated_clone "$d" v2
GH_PR_LIST='[]' run_publisher "$d"
updated_clone "$d" v3
GH_PR_LIST=$open_pr run_publisher "$d"
check "changed: replaces the branch" test "$(branch_tip "$d")" = "$(git -C "$d/work" rev-parse HEAD)"
check "changed: does not create a PR" not created_pr "$d"

# main に追加のコミットを積む
advance_main() {
  local dir=$1 file=$2 content=$3
  git -C "$dir/seed" pull -q "$dir/origin.git" main
  printf '%s\n' "$content" >"$dir/seed/$file"
  git -C "$dir/seed" add "$file"
  git -C "$dir/seed" commit -q -m "main: $file"
  git -C "$dir/seed" push -q "$dir/origin.git" main
}

# 4. main に無関係の変更が入っただけ: マージ結果が同じなので push しない
d=$(setup unrelated)
updated_clone "$d" v2
GH_PR_LIST='[]' run_publisher "$d"
before=$(branch_tip "$d")
advance_main "$d" README "docs"
updated_clone "$d" v2
GH_PR_LIST=$open_pr run_publisher "$d"
check "unrelated main change: keeps the branch tip" test "$(branch_tip "$d")" = "$before"

# 5. main が同じ行を別の値に変え、枝と競合する: 新しい main の上に作り直す
d=$(setup conflict)
updated_clone "$d" v3
GH_PR_LIST='[]' run_publisher "$d"
advance_main "$d" lock v2
updated_clone "$d" v3
GH_PR_LIST=$open_pr run_publisher "$d"
check "conflicting main change: moves the branch onto the new main" \
  git -C "$d/origin.git" merge-base --is-ancestor main "refs/heads/$branch"
check "conflicting main change: pushes the fresh update" \
  test "$(branch_tip "$d")" = "$(git -C "$d/work" rev-parse HEAD)"

# 6. 枝に人の修正が載っている: 上書きしない
d=$(setup manual)
updated_clone "$d" v2
GH_PR_LIST='[]' run_publisher "$d"
git -C "$d/work" fetch -q origin
git -C "$d/work" checkout -q -b fix "origin/$branch"
commit_file "$d/work" v2-fixed "fix: build with the new input"
git -C "$d/work" push -q origin "HEAD:refs/heads/$branch"
manual=$(branch_tip "$d")
updated_clone "$d" v3
GH_PR_LIST=$open_pr run_publisher "$d"
check "manual: keeps the manual commit" test "$(branch_tip "$d")" = "$manual"
check "manual: warns" grep -q '::warning::' "$d/out"

# 7. 同じ名前の枝の PR がフォークにしか無い: 本体の PR を作る
d=$(setup fork)
updated_clone "$d" v2
GH_PR_LIST=$fork_pr run_publisher "$d"
check "fork: creates a PR in this repository" created_pr "$d"

if [ "$failures" -ne 0 ]; then
  printf '%d failure(s)\n' "$failures" >&2
  exit 1
fi
