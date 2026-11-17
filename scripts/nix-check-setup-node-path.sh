#!/usr/bin/env bash
# config/mise の node の bin を $GITHUB_PATH へ引き継ぐ。
#
# install は node を置くだけで PATH を足さないため、後続 step が runner 既定の
# Node で動かないように config/mise の bin を渡す。stderr には trust の WARN が
# 出るので捨て、空なら静かに進まず失敗させる。mise は PATH から解決する。

set -euo pipefail

dirs=$(mise bin-paths --cd config/mise node 2>/dev/null)
if [ -z "$dirs" ]; then
  echo "mise bin-paths が空を返した（config/mise の node を解決できない）" >&2
  exit 1
fi

# 空行は PATH の要素ではないので書かない。
printf '%s\n' "$dirs" | while IFS= read -r dir; do
  if [ -n "$dir" ]; then
    printf '%s\n' "$dir" >>"$GITHUB_PATH"
  fi
done
