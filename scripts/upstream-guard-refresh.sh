#!/usr/bin/env bash
# upstream-guard の実行ファイルを、判定を途切れさせずに作り直す。
#
# 使い方: scripts/upstream-guard-refresh.sh [dotfiles のチェックアウト]
#
# ~/.local/bin/upstream-guard は <state>/result/bin/upstream-guard を指す。
# 新しい版は、いま使っていない側の out-link（<state>/slot-a か slot-b）に作り、
# 単体テストと check の入口の確認が通ってから、result を 1 回の rename で付け替える。
# 古い版は、もう片方の out-link に残る（GC から守られる）。途中で失敗したら result は変えない。

set -euo pipefail

repo=${1:-$(git rev-parse --show-toplevel)}
state=${UPSTREAM_GUARD_STATE:-$HOME/.local/state/upstream-guard}
system=${UPSTREAM_GUARD_SYSTEM:-$(nix eval --impure --raw --expr builtins.currentSystem)}

mkdir -p "$state"
current=$(readlink "$state/result" 2>/dev/null || true)
slot=a
if [[ -n $current && $(readlink "$state/slot-a" 2>/dev/null || true) == "$current" ]]; then
  slot=b
fi

nix build "$repo#checks.$system.upstream-guard" -o "$state/slot-$slot"
new=$(readlink "$state/slot-$slot")

# 全ボットに掛かる前に、新しい版を確かめる
python3 "$repo/tests/upstream_guard_test.py" >/dev/null 2>&1 || {
  echo "upstream-guard-refresh: 単体テストが失敗したので差し替えない" >&2
  exit 1
}
rc=0
"$new/bin/upstream-guard" check --cwd / -- 'gh pr merge 1 -R nrslib/takt' >/dev/null || rc=$?
if [[ $rc != 2 ]]; then
  echo "upstream-guard-refresh: 新しい版が拒否を返さない（終了コード $rc）ので差し替えない" >&2
  exit 1
fi
"$new/bin/upstream-guard" check --cwd / -- 'gh pr view 1 -R nrslib/takt' >/dev/null || {
  echo "upstream-guard-refresh: 新しい版が読み取りを通さないので差し替えない" >&2
  exit 1
}

# 一時のリンクを作り、rename(2) で result を置き換える（リンクが無い瞬間を作らない）
ln -sfn "$new" "$state/result.tmp"
python3 -c 'import os, sys; os.replace(sys.argv[1], sys.argv[2])' "$state/result.tmp" "$state/result"
echo "upstream-guard-refresh: $state/result -> $new（前の版: ${current:-なし}）"
