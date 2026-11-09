#!/usr/bin/env bash
# 自前のコードだけを対象にした lint ゲート。
#
# 使い方:
#   scripts/lint.sh               全ゲート
#   scripts/lint.sh --format-only 整形チェックだけ (nixfmt / stylua)
#
# 「ベンダーか自前か」の判定は lint/vendored-paths.txt だけを根拠にする。

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

manifest="lint/vendored-paths.txt"
stylua_config="config/nvim/.stylua.toml"

gate="初期化"
trap 'echo "lint: 失敗 (${gate})" >&2' ERR

format_only=0
if [[ ${1:-} == "--format-only" ]]; then
  format_only=1
fi

# --- manifest の読み込み --------------------------------------------------

vendor_roots=()
vendor_files=()
while IFS= read -r line; do
  case $line in
    '' | '#'*) continue ;;
    'root: '*) vendor_roots+=("${line#root: }") ;;
    *) vendor_files+=("$line") ;;
  esac
done <"$manifest"

declare -A is_vendor=()
for file in ${vendor_files[@]+"${vendor_files[@]}"}; do
  is_vendor["$file"]=1
done

# 引数の pathspec に一致する追跡ファイルから、ベンダーを除いて出力する
own_files() {
  local file
  while IFS= read -r -d '' file; do
    if [[ -n ${is_vendor["$file"]:-} ]]; then
      continue
    fi
    printf '%s\n' "$file"
  done < <(git ls-files -z -- "$@")
}

# --- ゲート 1: ベンダー manifest の整合性 ---------------------------------

# ベンダーツリー配下の追跡ファイルがすべて manifest に載っているか、
# manifest の行がすべて実在するかを突き合わせる。
gate="ベンダー manifest"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

: >"$tmpdir/listed"
: >"$tmpdir/tracked"
if ((${#vendor_files[@]} > 0)); then
  printf '%s\n' "${vendor_files[@]}" >"$tmpdir/listed"
fi
if ((${#vendor_roots[@]} > 0)); then
  git ls-files -z -- "${vendor_roots[@]}" | tr '\0' '\n' >"$tmpdir/tracked"
fi
LC_ALL=C sort -o "$tmpdir/listed" "$tmpdir/listed"
LC_ALL=C sort -o "$tmpdir/tracked" "$tmpdir/tracked"

added=$(LC_ALL=C comm -13 "$tmpdir/listed" "$tmpdir/tracked")
removed=$(LC_ALL=C comm -23 "$tmpdir/listed" "$tmpdir/tracked")

if [[ -n $added ]]; then
  echo "エラー: ベンダーツリー配下に manifest 未登録のファイルがあります。" >&2
  echo "  $manifest へ追加してください:" >&2
  while IFS= read -r file; do
    echo "  + $file" >&2
  done <<<"$added"
fi
if [[ -n $removed ]]; then
  echo "エラー: manifest に載っているが存在しないファイルがあります。" >&2
  echo "  $manifest から削除してください:" >&2
  while IFS= read -r file; do
    echo "  - $file" >&2
  done <<<"$removed"
fi
if [[ -n $added || -n $removed ]]; then
  false
fi
echo "OK: ベンダー manifest ($(wc -l <"$tmpdir/tracked" | tr -d ' ') 件)"

# --- ゲート 2: 整形 -------------------------------------------------------

nix_files=()
while IFS= read -r file; do
  nix_files+=("$file")
done < <(own_files '*.nix')

lua_files=()
while IFS= read -r file; do
  lua_files+=("$file")
done < <(own_files '*.lua')

gate="nixfmt --check"
if ((${#nix_files[@]} > 0)); then
  nixfmt --check "${nix_files[@]}"
fi
echo "OK: nixfmt (${#nix_files[@]} 件)"

gate="stylua --check"
if ((${#lua_files[@]} > 0)); then
  stylua --check --config-path "$PWD/$stylua_config" "${lua_files[@]}"
fi
echo "OK: stylua (${#lua_files[@]} 件)"

if ((format_only)); then
  exit 0
fi

# --- ゲート 3: shellcheck -------------------------------------------------

sh_files=()
while IFS= read -r file; do
  sh_files+=("$file")
done < <(own_files '*.sh' '*.bash' '.githooks/*')

gate="shellcheck"
if ((${#sh_files[@]} > 0)); then
  shellcheck "${sh_files[@]}"
fi
echo "OK: shellcheck (${#sh_files[@]} 件)"

# --- ゲート 4: ruff -------------------------------------------------------

py_files=()
while IFS= read -r file; do
  py_files+=("$file")
done < <(own_files '*.py')

gate="ruff"
if ((${#py_files[@]} > 0)); then
  # --no-cache: 作業ツリーに .ruff_cache を作らない
  ruff check --no-cache "${py_files[@]}"
fi
echo "OK: ruff (${#py_files[@]} 件)"

# --- ゲート 5: deadnix ----------------------------------------------------

# --no-lambda-pattern-names: モジュール関数の `{ pkgs, lib }:` を未使用と
# みなさない (callPackage 由来の引数は意図的に使わないことがある)。
gate="deadnix"
if ((${#nix_files[@]} > 0)); then
  deadnix --fail --no-lambda-pattern-names "${nix_files[@]}"
fi
echo "OK: deadnix (${#nix_files[@]} 件)"
