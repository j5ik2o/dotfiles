#!/usr/bin/env bash
# scripts/nix-check-*.sh を偽の環境で走らせるテスト。
#
# ネットワークも $HOME も触らない。mise と node は PATH の先頭に置いた偽物で
# 差し替え、出力先は mktemp -d の下に作る。mise.toml は呼び出し元 cwd からの
# 相対パス config/mise/mise.toml で読み、PATH 追記は $GITHUB_PATH で差し替える。

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
path_script="$repo_root/scripts/nix-check-setup-node-path.sh"
version_script="$repo_root/scripts/nix-check-assert-node-version.sh"

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

bin="$root/bin"
mkdir -p "$bin"

# mise bin-paths の出力を MISE_TEST_BIN_PATHS で与える。stderr には WARN を出す。
# 偽の mise は引数を MISE_TEST_ARGS に記録する。呼び出し側が `--cd config/mise node`
# を渡しているかを確かめられるようにし、設定の取り違えをテストで検出する。
cat >"$bin/mise" <<'EOF'
#!/usr/bin/env bash
printf '%s' "$*" >"${MISE_TEST_ARGS:?}"
printf 'mise: WARN untrusted config\n' >&2
printf '%s' "${MISE_TEST_BIN_PATHS:-}"
EOF

# node --version の出力を NODE_TEST_VERSION で与える。
cat >"$bin/node" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${NODE_TEST_VERSION:?}"
EOF

chmod +x "$bin/mise" "$bin/node"

# config/mise/mise.toml を持つ擬似リポジトリを作る。
make_repo() {
  local dir=$1
  local mise_body=$2
  mkdir -p "$dir/config/mise"
  printf '%s\n' "$mise_body" >"$dir/config/mise/mise.toml"
}

# --- PATH 追加: 複数行を 1 行ずつ追記し空行は飛ばす -----------------------

case_dir="$root/path-multi"
repo="$case_dir/repo"
make_repo "$repo" '[tools]
node = "24"'
github_path="$case_dir/github_path"
: >"$github_path"

path_status=0
(
  cd "$repo" || exit 1
  PATH="$bin:$PATH" \
    MISE_TEST_BIN_PATHS='/home/u/.local/share/mise/installs/node/24/bin

/home/u/.local/share/mise/installs/node/24/libexec' \
    MISE_TEST_ARGS="$case_dir/mise-args" \
    GITHUB_PATH="$github_path" \
    bash "$path_script"
) >"$case_dir/path-multi.log" 2>&1 || path_status=$?

check "PATH 追加: 複数行は exit 0" test "$path_status" -eq 0
check "PATH 追加: mise bin-paths に --cd config/mise node を渡す" \
  test "$(cat "$case_dir/mise-args")" = "bin-paths --cd config/mise node"
check "PATH 追加: 空行を飛ばして 2 行追記する" \
  test "$(wc -l <"$github_path" | tr -d ' ')" -eq 2
check "PATH 追加: 1 行目を書く" \
  grep -qx '/home/u/.local/share/mise/installs/node/24/bin' "$github_path"
check "PATH 追加: 2 行目を書く" \
  grep -qx '/home/u/.local/share/mise/installs/node/24/libexec' "$github_path"
check "PATH 追加: 末尾に空行を残さない" \
  test "$path_status" -eq 0 -a -z "$(awk 'NF == 0' "$github_path")"

# --- PATH 追加: mise の出力が空なら失敗 -----------------------------------

case_dir="$root/path-empty"
github_path="$case_dir/github_path"
mkdir -p "$case_dir"
: >"$github_path"

path_status=0
(
  cd "$repo" || exit 1
  PATH="$bin:$PATH" \
    MISE_TEST_BIN_PATHS='' \
    MISE_TEST_ARGS="$case_dir/mise-args" \
    GITHUB_PATH="$github_path" \
    bash "$path_script"
) >"$case_dir/path-empty.log" 2>&1 || path_status=$?

check "PATH 追加: 空出力は失敗する" test "$path_status" -eq 1
check "PATH 追加: 空出力では何も追記しない" \
  test "$path_status" -eq 1 -a ! -s "$github_path"
check "PATH 追加: 空出力で理由を stderr に出す" \
  test "$path_status" -eq 1 -a -n "$(grep 'mise bin-paths' "$case_dir/path-empty.log")"

# --- 版確認: 一致すれば成功し両方の値をログに出す -------------------------

case_dir="$root/version-match"
repo="$case_dir/repo"
make_repo "$repo" '[tools]
node = "24"'

version_status=0
(
  cd "$repo" || exit 1
  PATH="$bin:$PATH" NODE_TEST_VERSION='v24.11.0' bash "$version_script"
) >"$case_dir/version-match.log" 2>&1 || version_status=$?

check "版確認: 一致は exit 0" test "$version_status" -eq 0
check "版確認: node --version をログに出す" \
  grep -q 'node --version: v24.11.0' "$case_dir/version-match.log"
check "版確認: mise.toml の値をログに出す" \
  grep -q 'config/mise/mise.toml node: 24' "$case_dir/version-match.log"

# --- 版確認: 一致しなければ失敗 -------------------------------------------

case_dir="$root/version-mismatch"
repo="$case_dir/repo"
make_repo "$repo" '[tools]
node = "24"'

version_status=0
(
  cd "$repo" || exit 1
  PATH="$bin:$PATH" NODE_TEST_VERSION='v22.5.1' bash "$version_script"
) >"$case_dir/version-mismatch.log" 2>&1 || version_status=$?

check "版確認: 不一致は失敗する" test "$version_status" -eq 1

# --- 版確認: 部分一致では通さない (major の完全一致のみ) ------------------

case_dir="$root/version-partial"
repo="$case_dir/repo"
make_repo "$repo" '[tools]
node = "4"'

version_status=0
(
  cd "$repo" || exit 1
  PATH="$bin:$PATH" NODE_TEST_VERSION='v14.0.0' bash "$version_script"
) >"$case_dir/version-partial.log" 2>&1 || version_status=$?

check "版確認: major の部分一致では失敗する" test "$version_status" -eq 1

# --- 版確認: mise.toml に node の版がなければ失敗 -------------------------

case_dir="$root/version-missing"
repo="$case_dir/repo"
make_repo "$repo" '[tools]
python = "3.15.2"'

version_status=0
(
  cd "$repo" || exit 1
  PATH="$bin:$PATH" NODE_TEST_VERSION='v24.11.0' bash "$version_script"
) >"$case_dir/version-missing.log" 2>&1 || version_status=$?

check "版確認: mise.toml に node がなければ失敗する" test "$version_status" -eq 1

# --- 結果 -----------------------------------------------------------------

if [ "$failures" -ne 0 ]; then
  printf '%d 件失敗\n' "$failures" >&2
  exit 1
fi
printf 'すべて成功\n'
