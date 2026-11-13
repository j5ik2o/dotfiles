#!/usr/bin/env bash
# scripts/coordinator-switch.sh を偽の環境で走らせるテスト。
#
# ネットワークも $HOME も触らない。外部コマンド (orca / gh / date) は PATH の
# 先頭に置いた偽物で差し替え、対象リポジトリと引き継ぎ文書は mktemp -d の下に
# 作る。偽 orca は worktree create の prompt から ack 件名を抜き出して
# orchestration inbox の応答へ返す。本番では後任エージェントが prompt の指示どおりの
# 件名で受け取りを報告するため、その経路の模倣になる。

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
switcher="$repo_root/scripts/coordinator-switch.sh"

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

# grep -q の否定。check は "!" をコマンドとして実行できないため。
not_grep() {
  ! grep -q "$@"
}

# --- 偽の環境 -------------------------------------------------------------

bin="$root/bin"
mkdir -p "$bin"

# 偽 orca。呼び出しを $SWITCH_TEST_FAKE_LOG に 1 行ずつ記録する。
# JSON の形は実物の出力に合わせる (result.worktrees[].displayName、
# result.launch.outcome.handle、result.terminals[].handle、
# result.automations[]、result.messages[])。
cat >"$bin/orca" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail

{
  printf 'orca'
  for arg in "$@"; do
    printf ' %s' "${arg//$'\n'/\\n}"
  done
  printf '\n'
} >>"$SWITCH_TEST_FAKE_LOG"

cmd=${1:-}
if [ $# -gt 0 ]; then shift; fi
sub=${1:-}

case $cmd in
  worktree)
    case $sub in
      list)
        cat "$SWITCH_TEST_WORKTREES_JSON"
        ;;
      create)
        # 本番では後任エージェントが prompt の指示どおりの件名で受け取りを報告する。
        # その模倣として、prompt から ack 件名を抜き出して保存する。
        prompt=
        args=("$@")
        for ((i = 0; i < ${#args[@]}; i++)); do
          if [ "${args[$i]}" = "--prompt" ]; then
            prompt=${args[$((i + 1))]:-}
            break
          fi
        done
        ack_subject=$(printf '%s\n' "$prompt" | grep -oE 'handoff-ack-[0-9]+' | head -1 || true)
        if [ -n "$ack_subject" ]; then
          printf '%s\n' "$ack_subject" >"$SWITCH_TEST_ACK_SUBJECT"
        fi
        printf '{"id":"op-worktree-create","ok":true,"result":{"worktree":{"displayName":"%s"},"launch":{"outcome":{"kind":"terminal","handle":"%s"}}}}\n' \
          "${SWITCH_TEST_NEW_WORKTREE_DISPLAY}" "${SWITCH_TEST_NEW_TERMINAL}"
        ;;
      *)
        printf 'orca worktree %s: 偽 orca は知らない\n' "$sub" >&2
        exit 1
        ;;
    esac
    ;;
  orchestration)
    case $sub in
      inbox)
        # 呼び出し回数を数え、$SWITCH_TEST_INBOX_ACK_AFTER_CALLS 回目から
        # 今回の ack を応答へ混ぜる。過去の交代の ack は常に混ぜる。
        calls=$(cat "$SWITCH_TEST_INBOX_CALLS" 2>/dev/null || printf '0')
        printf '%s\n' "$((calls + 1))" >"$SWITCH_TEST_INBOX_CALLS"
        messages=$(cat "$SWITCH_TEST_MESSAGES_FILE")
        ack_subject=$(cat "$SWITCH_TEST_ACK_SUBJECT" 2>/dev/null || true)
        ack_after=$(cat "$SWITCH_TEST_INBOX_ACK_AFTER_CALLS" 2>/dev/null || printf '0')
        if [ -n "$ack_subject" ] && [ "$((calls + 1))" -ge "$ack_after" ]; then
          ack_message=$(printf '{"id":"msg_ack","type":"status","from":"%s","to":"run:%s","subject":"%s","body":"引き継ぎを受け取りました。","handled":false}' \
            "${SWITCH_TEST_NEW_TERMINAL}" "${SWITCH_TEST_RUN}" "$ack_subject")
          messages="$messages,$ack_message"
        fi
        printf '{"id":"op-inbox","ok":true,"result":{"messages":[%s]}}\n' "$messages"
        ;;
      *)
        printf 'orca orchestration %s: 偽 orca は知らない\n' "$sub" >&2
        exit 1
        ;;
    esac
    ;;
  terminal)
    case $sub in
      close)
        : >"$SWITCH_TEST_CLOSED"
        printf '{"id":"op-terminal-close","ok":true,"result":{}}\n'
        ;;
      list)
        if [ -e "$SWITCH_TEST_CLOSED" ]; then
          cat "$SWITCH_TEST_TERMINALS_CLOSED_JSON"
        else
          cat "$SWITCH_TEST_TERMINALS_JSON"
        fi
        ;;
      *)
        printf 'orca terminal %s: 偽 orca は知らない\n' "$sub" >&2
        exit 1
        ;;
    esac
    ;;
  automations)
    case $sub in
      list)
        cat "$SWITCH_TEST_AUTOMATIONS_JSON"
        ;;
      edit)
        printf '{"id":"op-automations-edit","ok":true,"result":{}}\n'
        ;;
      *)
        printf 'orca automations %s: 偽 orca は知らない\n' "$sub" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    printf 'orca %s: 偽 orca は知らない\n' "$cmd" >&2
    exit 1
    ;;
esac
EOF

# 偽 gh。呼び出しを同じログに記録する。
cat >"$bin/gh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
{
  printf 'gh'
  for arg in "$@"; do
    printf ' %s' "${arg//$'\n'/\\n}"
  done
  printf '\n'
} >>"$SWITCH_TEST_FAKE_LOG"
printf 'https://github.com/j5ik2o/dotfiles/issues/187#issuecomment-fake\n'
EOF

# 偽 date。止めた時刻の表示は固定値、エポック秒は実時間を返す。
# date +%s で --ack-timeout の締め切りを測る実装では、エポック秒を
# 固定値にすると時間が進まず、テストが待ち続けてしまうため。
# 実時間の取得は PATH 上の偽物自身を呼ぶと再帰するので絶対パスに向ける。
cat >"$bin/date" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
case "${1:-}" in
  +%s) printf '%s\n' "$(/bin/date +%s)" ;;
  *) printf '2026-11-14 12:34:56 JST\n' ;;
esac
EOF

chmod +x "$bin/orca" "$bin/gh" "$bin/date" || {
  printf 'chmod に失敗しました: %s\n' "$bin" >&2
  exit 1
}

# --- 共通の値と fixture ---------------------------------------------------

worktree_name=pm-glm53
model='ollama/glm-5.3:cloud'
run=run_f68036e10a4f
coordinator_terminal=term_df2b7535-9163-4382-aacf-57a6a729552d
new_terminal=term_successor-7777
watch=orca-dotfiles-watch
automation_id=au-dotfiles-watch-1
old_ack='handoff-ack-1000000000'

repo=
brief=
handoff=
log=
status=

# ケースの土台を作る。指示書・引き継ぎ文書・進行中の作業の記録と、
# 「何も問題がない場合」の応答 fixture を置く。
prepare_case() {
  local case_root=$1
  mkdir -p "$case_root"
  repo="$case_root/repo"
  brief="$case_root/coordinator-brief.md"
  handoff="$case_root/handoff-coordinator-2026-11-14.md"
  mkdir -p "$repo/.takt/goals/11111111-2222-3333-4444-555555555555"
  printf '{"objective":"dotfiles の見回り"}\n' \
    >"$repo/.takt/goals/11111111-2222-3333-4444-555555555555/goal.json"
  printf '# coordinator の指示書\n' >"$brief"
  printf '# 引き継ぎ文書\n' >"$handoff"

  log="$case_root/fake.log"
  : >"$log"
  export SWITCH_TEST_FAKE_LOG="$log"

  printf '{"id":"wt-list","ok":true,"result":{"worktrees":[{"displayName":"main"}]}}\n' \
    >"$case_root/worktrees.json"
  export SWITCH_TEST_WORKTREES_JSON="$case_root/worktrees.json"

  # 過去の交代の受け取り報告。今回の待ちを壊してはいけない。
  printf '{"id":"msg_prev","type":"worker_done","from":"structworker_prev","to":"run:%s","subject":"%s","body":"前回の交代の受け取り","handled":true}\n' \
    "$run" "$old_ack" >"$case_root/messages.json"
  export SWITCH_TEST_MESSAGES_FILE="$case_root/messages.json"

  printf '{"id":"tl-list","ok":true,"result":{"terminals":[{"handle":"%s","title":"現任"},{"handle":"%s","title":"後任"}]}}\n' \
    "$coordinator_terminal" "$new_terminal" >"$case_root/terminals.json"
  export SWITCH_TEST_TERMINALS_JSON="$case_root/terminals.json"

  printf '{"id":"tl-list","ok":true,"result":{"terminals":[{"handle":"%s","title":"後任"}]}}\n' \
    "$new_terminal" >"$case_root/terminals-closed.json"
  export SWITCH_TEST_TERMINALS_CLOSED_JSON="$case_root/terminals-closed.json"

  # ESA 見回りの実物と同じく、prompt に coordinator-terminal を埋め込む形式。
  printf '{"id":"au-list","ok":true,"result":{"automations":[{"id":"%s","name":"%s","prompt":"シェルで次の1コマンドだけを1回実行して終える。: python3 tools/pm/dotfiles_patrol.py --run %s --automation %s --coordinator-terminal %s --apply"}]}}\n' \
    "$automation_id" "$watch" "$run" "$automation_id" "$coordinator_terminal" \
    >"$case_root/automations.json"
  export SWITCH_TEST_AUTOMATIONS_JSON="$case_root/automations.json"

  export SWITCH_TEST_NEW_WORKTREE_DISPLAY="$worktree_name"
  export SWITCH_TEST_NEW_TERMINAL="$new_terminal"
  export SWITCH_TEST_RUN="$run"

  export SWITCH_TEST_ACK_SUBJECT="$case_root/ack-subject"
  : >"$SWITCH_TEST_ACK_SUBJECT"
  export SWITCH_TEST_INBOX_CALLS="$case_root/inbox-calls"
  rm -f "$SWITCH_TEST_INBOX_CALLS"
  export SWITCH_TEST_CLOSED="$case_root/closed"
  rm -f "$SWITCH_TEST_CLOSED"
  # 未設定なら 0 扱いで、最初の確認から今回の ack を返す。
  export SWITCH_TEST_INBOX_ACK_AFTER_CALLS="$case_root/ack-after"
  rm -f "$SWITCH_TEST_INBOX_ACK_AFTER_CALLS"
}

status=

# 偽の環境で交代スクリプトを走らせ、終了コードを status に入れる。
run_switch() {
  local out=$1
  shift
  status=0
  PATH="$bin:$PATH" "$switcher" \
    --repo "$repo" \
    --worktree-name "$worktree_name" \
    --model "$model" \
    --run "$run" \
    --coordinator-terminal "$coordinator_terminal" \
    --brief "$brief" \
    --handoff "$handoff" \
    --watch "$watch" \
    "$@" >"$out" 2>&1 || status=$?
}

# ログから主要な呼び出しの並びを取り出す。連続する同一呼び出しは 1 つに潰す。
step_sequence() {
  awk '
    /^orca worktree list/ { print "worktree-list"; next }
    /^orca worktree create/ { print "worktree-create"; next }
    /^orca orchestration inbox/ { print "inbox"; next }
    /^orca terminal close/ { print "terminal-close"; next }
    /^orca terminal list/ { print "terminal-list"; next }
    /^orca automations list/ { print "automations-list"; next }
    /^orca automations edit/ { print "automations-edit"; next }
    /^gh / { print "gh"; next }
  ' "$1" | awk 'prev != $0 { print; prev = $0 }'
}

expected_happy_steps='worktree-list
worktree-create
inbox
automations-list
terminal-close
terminal-list
automations-edit
gh'

# --- 必須の --brief がなければ使用法エラー -------------------------------

case_dir="$root/no-brief"
prepare_case "$case_dir"
status=0
PATH="$bin:$PATH" "$switcher" --repo "$repo" --handoff "$handoff" \
  >"$root/no-brief.log" 2>&1 || status=$?

check "--brief なしは exit 2" test "$status" -eq 2
check "--brief なしでは orca を呼ばない" test ! -s "$log"

# --- 待機時間の引数が不正なら副作用の前に使用法エラー ---------------------

for opt in --poll-interval --ack-timeout; do
  for value in invalid 0 -1 08; do
    case_dir="$root/wait-arg-${opt#--}-${value#-}"
    prepare_case "$case_dir"
    run_switch "$case_dir.log" "$opt" "$value"
    check "$opt $value は exit 2" test "$status" -eq 2
    check "$opt $value では orca を呼ばない" test ! -s "$log"
    check "$opt $value のエラーはオプションと値を述べる" \
      grep -Eq -- "${opt}.*${value}|${value}.*${opt}" "$case_dir.log"
  done
done

# --- 指示書がなければ手順1で止まる ---------------------------------------

case_dir="$root/no-brief-file"
prepare_case "$case_dir"
rm -f "$brief"
run_switch "$root/no-brief-file.log"

check "指示書なしは exit 1" test "$status" -eq 1
check "指示書なしでは orca を呼ばない" test ! -s "$log"

# --- 引き継ぎ文書がなければ手順1で止まる ---------------------------------

case_dir="$root/no-handoff"
prepare_case "$case_dir"
rm -f "$handoff"
run_switch "$root/no-handoff.log"

check "引き継ぎ文書なしは exit 1" test "$status" -eq 1
check "引き継ぎ文書なしでは orca を呼ばない" test ! -s "$log"

# --- 進行中の作業の記録がなければ手順1で止まる ---------------------------

case_dir="$root/no-goals"
prepare_case "$case_dir"
rm -rf "$repo/.takt"
run_switch "$root/no-goals.log"

check "進行中の作業の記録なしは exit 1" test "$status" -eq 1
check "進行記録なしでは orca を呼ばない" test ! -s "$log"

# --- 同名の作業ツリーが既にあれば手順2の前で止まる -----------------------

case_dir="$root/name-exists"
prepare_case "$case_dir"
printf '{"id":"wt-list","ok":true,"result":{"worktrees":[{"displayName":"main"},{"displayName":"%s"}]}}\n' \
  "$worktree_name" >"$SWITCH_TEST_WORKTREES_JSON"
run_switch "$root/name-exists.log"

check "同名の作業ツリー既存は exit 1" test "$status" -eq 1
check "既存チェックに worktree list を使う" grep -q '^orca worktree list' "$log"
check "同名既存では worktree create を呼ばない" not_grep '^orca worktree create' "$log"

# --- worktree list の応答が壊れていれば作成の前に止まる -------------------

case_dir="$root/broken-worktree-list"
prepare_case "$case_dir"
printf '{"ok":true,\n' >"$SWITCH_TEST_WORKTREES_JSON"
run_switch "$root/broken-worktree-list.log" --poll-interval 1 --ack-timeout 2

check "worktree list が不正 JSON なら exit 1" test "$status" -eq 1
check "worktree list が不正 JSON なら worktree create を呼ばない" \
  not_grep '^orca worktree create' "$log"

case_dir="$root/no-result-worktree-list"
prepare_case "$case_dir"
printf '{"ok":true}\n' >"$SWITCH_TEST_WORKTREES_JSON"
run_switch "$root/no-result-worktree-list.log" --poll-interval 1 --ack-timeout 2

check "worktree list が result なしなら exit 1" test "$status" -eq 1
check "worktree list が result なしなら worktree create を呼ばない" \
  not_grep '^orca worktree create' "$log"

# --- result に worktrees が無くても「対象なし」として進む -----------------

case_dir="$root/no-worktrees-key"
prepare_case "$case_dir"
printf '{"id":"wt-list","ok":true,"result":{}}\n' >"$SWITCH_TEST_WORKTREES_JSON"
run_switch "$root/no-worktrees-key.log" --poll-interval 1 --ack-timeout 2

check "worktrees が欠損しても exit 0 で進む" test "$status" -eq 0
check "worktrees が欠損しても worktree create を呼ぶ" \
  grep -q '^orca worktree create' "$log"

# --- 正常時は手順1〜6の順序で進む -----------------------------------------

case_dir="$root/happy"
prepare_case "$case_dir"
run_switch "$root/happy.log" --poll-interval 1 --ack-timeout 2

check "正常時は exit 0" test "$status" -eq 0
check "手順1〜6の順序どおり" test "$(step_sequence "$log")" = "$expected_happy_steps"

check "既存チェックは対象リポジトリに対して行う" \
  grep -q "^orca worktree list --repo path:$repo --json" "$log"

create_line=$(grep '^orca worktree create' "$log" || true)
check "後任ツリー作成に worktree create を使う" test -n "$create_line"
if [ -n "$create_line" ]; then
  check "worktree create は対象リポジトリを指定する" grep -q -- "--repo path:$repo" <<<"$create_line"
  check "worktree create は後任ツリー名を指定する" grep -q -- "--name $worktree_name" <<<"$create_line"
  check "worktree create は opencode を起動する" grep -q -- '--agent opencode' <<<"$create_line"
  check "worktree create はモデルを指定する" grep -q -- "--model $model" <<<"$create_line"
  check "worktree create は JSON を要求する" grep -q -- '--json' <<<"$create_line"
fi
check "指示書のパスが後任へ伝わる" grep -q -- "--prompt .* $brief" "$log"
check "引き継ぎ文書のパスが後任へ伝わる" grep -q "$handoff" "$log"
check "Run の引き継ぎ指示が後任へ伝わる" grep -q "run-use --id $run" "$log"
check "受け取り報告の ack 件名が後任へ伝わる" grep -qE 'handoff-ack-[0-9]+' "$log"

check "受け取り確認に inbox を使う" \
  grep -q "^orca orchestration inbox --terminal run:$run --json" "$log"
check "ポーリングを繰り返す" test "$(grep -c '^orca orchestration inbox' "$log")" -ge 1

check "現任の停止は terminal close --tab" \
  grep -q "^orca terminal close --terminal $coordinator_terminal --tab" "$log"
check "停止後に terminal list で消えたことを確認する" grep -q '^orca terminal list --json' "$log"

check "見回りの特定に automations list を使う" grep -q '^orca automations list --json' "$log"
edit_line=$(grep '^orca automations edit' "$log" || true)
check "見回りを automations edit で向け替える" test -n "$edit_line"
check "edit は automation ID を指定する" grep -q -- "--id $automation_id" <<<"$edit_line"
check "向け替え後の見回りは後任ターミナルを見る" \
  grep -q -- "--coordinator-terminal $new_terminal" <<<"$edit_line"
check "向け替え後の見回りに現任ターミナルは残らない" \
  not_grep -- "$coordinator_terminal" <<<"$edit_line"

gh_line=$(grep '^gh issue comment' "$log" || true)
check "交代の記録を issue へコメントする" test -n "$gh_line"
check "コメント先は issue 187" grep -q 'issue comment 187 ' <<<"$gh_line"
check "コメント先のリポジトリは j5ik2o/dotfiles" grep -q -- '-R j5ik2o/dotfiles' <<<"$gh_line"
check "コメントに止めた時刻が入る" grep -q '2026-11-14 12:34:56' <<<"$gh_line"
check "コメントに現任ターミナルが入る" grep -q -- "$coordinator_terminal" <<<"$gh_line"
check "コメントに後任ターミナルが入る" grep -q -- "$new_terminal" <<<"$gh_line"
check "コメントにモデルが入る" grep -q -- "$model" <<<"$gh_line"
check "コメントに Run が入る" grep -q -- "$run" <<<"$gh_line"

# --- 受け取りの確認が取れなければ現任を止めない ---------------------------

case_dir="$root/ack-timeout"
prepare_case "$case_dir"
# inbox が何回呼ばれても今回の ack を返さない。
printf '999\n' >"$SWITCH_TEST_INBOX_ACK_AFTER_CALLS"
run_switch "$root/ack-timeout.log" --poll-interval 1 --ack-timeout 2

check "受け取り未確認は exit 1" test "$status" -eq 1
check "ポーリングを短い間隔で繰り返す" \
  test "$(grep -c '^orca orchestration inbox' "$log")" -ge 2
check "受け取り未確認では現任を止めない" not_grep '^orca terminal close' "$log"
check "受け取り未確認では見回りを替えない" not_grep '^orca automations edit' "$log"
check "受け取り未確認では issue コメントしない" not_grep '^gh ' "$log"

# --- 過去の交代の ack にはマッチしない -----------------------------------

case_dir="$root/old-ack"
prepare_case "$case_dir"
# 1 回目の確認には過去の交代の ack しか無く、2 回目で今回の ack が届く。
printf '2\n' >"$SWITCH_TEST_INBOX_ACK_AFTER_CALLS"
run_switch "$root/old-ack.log" --poll-interval 1 --ack-timeout 3

check "過去の ack に誤マッチせず、今回の ack で完了する" test "$status" -eq 0
check "過去の ack だけで待ちを終えない" \
  test "$(grep -c '^orca orchestration inbox' "$log")" -ge 2
check "受け取り確認後に現任を止める" grep -q '^orca terminal close' "$log"

# --- inbox の応答が壊れていれば現任を止めずに止まる -----------------------

case_dir="$root/broken-inbox"
prepare_case "$case_dir"
printf 'これは JSON ではありません\n' >"$SWITCH_TEST_MESSAGES_FILE"
run_switch "$root/broken-inbox.log" --poll-interval 1 --ack-timeout 2

check "inbox が不正 JSON なら exit 1" test "$status" -eq 1
check "inbox が不正 JSON なら確認 1 回で止まる" \
  test "$(grep -c '^orca orchestration inbox' "$log")" -eq 1
check "inbox が不正 JSON なら現任を止めない" not_grep '^orca terminal close' "$log"

# --- 現任が一覧から消えなければ手順5に進まない ---------------------------

case_dir="$root/terminal-remains"
prepare_case "$case_dir"
# close を呼んでも一覧から現任が消えない。
printf '{"id":"tl-list","ok":true,"result":{"terminals":[{"handle":"%s","title":"現任"},{"handle":"%s","title":"後任"}]}}\n' \
  "$coordinator_terminal" "$new_terminal" >"$SWITCH_TEST_TERMINALS_CLOSED_JSON"
run_switch "$root/terminal-remains.log" --poll-interval 1 --ack-timeout 2

check "現任が一覧に残れば exit 1" test "$status" -eq 1
check "現任の close は呼ぶ" grep -q '^orca terminal close' "$log"
check "現任が残れば見回りを替えない" not_grep '^orca automations edit' "$log"
check "現任が残れば issue コメントしない" not_grep '^gh ' "$log"

# --- terminal list の応答が壊れていれば交代を完結しない -------------------

case_dir="$root/broken-terminal-list"
prepare_case "$case_dir"
printf '{"ok":true,\n' >"$SWITCH_TEST_TERMINALS_CLOSED_JSON"
run_switch "$root/broken-terminal-list.log" --poll-interval 1 --ack-timeout 2

check "terminal list が不正 JSON なら exit 1" test "$status" -eq 1
check "terminal list が不正 JSON でも現任の close は呼ぶ" \
  grep -q '^orca terminal close' "$log"
check "terminal list が不正 JSON なら見回りを替えない" \
  not_grep '^orca automations edit' "$log"
check "terminal list が不正 JSON なら issue コメントしない" not_grep '^gh ' "$log"

case_dir="$root/no-result-terminal-list"
prepare_case "$case_dir"
printf '{"ok":true}\n' >"$SWITCH_TEST_TERMINALS_CLOSED_JSON"
run_switch "$root/no-result-terminal-list.log" --poll-interval 1 --ack-timeout 2

check "terminal list が result なしなら exit 1" test "$status" -eq 1
check "terminal list が result なしなら見回りを替えない" \
  not_grep '^orca automations edit' "$log"
check "terminal list が result なしなら issue コメントしない" not_grep '^gh ' "$log"

# --- 空のターミナル一覧は「消えた」として扱い中止しない -------------------

case_dir="$root/empty-terminals"
prepare_case "$case_dir"
printf '{"id":"tl-list","ok":true,"result":{"terminals":[]}}\n' \
  >"$SWITCH_TEST_TERMINALS_CLOSED_JSON"
run_switch "$root/empty-terminals.log" --poll-interval 1 --ack-timeout 2

check "空のターミナル一覧なら exit 0" test "$status" -eq 0
check "空のターミナル一覧でも交代の記録は残す" grep -q '^gh issue comment' "$log"

# --- 見回りが見つからなければ現任を止めない -------------------------------

case_dir="$root/no-watch"
prepare_case "$case_dir"
printf '{"id":"au-list","ok":true,"result":{"automations":[]}}\n' \
  >"$SWITCH_TEST_AUTOMATIONS_JSON"
run_switch "$root/no-watch.log" --poll-interval 1 --ack-timeout 2

check "見回り不在は exit 1" test "$status" -eq 1
check "見回り不在では現任を止めない" not_grep '^orca terminal close' "$log"
check "見回り不在では issue コメントしない" not_grep '^gh ' "$log"

# --- 見回りが現 Run と現任ターミナルのどちらも指さなければ現任を止めない ---

case_dir="$root/watch-mismatch"
prepare_case "$case_dir"
printf '{"id":"au-list","ok":true,"result":{"automations":[{"id":"%s","name":"%s","prompt":"シェルで次の1コマンドだけを1回実行して終える。: npm run --silent pm:tick -- --run run_000000000000"}]}}\n' \
  "$automation_id" "$watch" >"$SWITCH_TEST_AUTOMATIONS_JSON"
run_switch "$root/watch-mismatch.log" --poll-interval 1 --ack-timeout 2

check "見回りが別の Run 宛てなら exit 1" test "$status" -eq 1
check "見回りの確認に automations list を使う" \
  grep -q '^orca automations list --json' "$log"
check "見回りが別の Run 宛てなら現任を止めない" not_grep '^orca terminal close' "$log"
check "見回りが別の Run 宛てなら見回りを替えない" not_grep '^orca automations edit' "$log"
check "見回りが別の Run 宛てなら issue コメントしない" not_grep '^gh ' "$log"

# --- Run 宛て型の見回りは向き先の変更が要らない ---------------------------

case_dir="$root/run-watch"
prepare_case "$case_dir"
printf '{"id":"au-list","ok":true,"result":{"automations":[{"id":"%s","name":"%s","prompt":"シェルで次の1コマンドだけを1回実行して終える。: npm run --silent pm:tick -- --run %s"}]}}\n' \
  "$automation_id" "$watch" "$run" >"$SWITCH_TEST_AUTOMATIONS_JSON"
run_switch "$root/run-watch.log" --poll-interval 1 --ack-timeout 2

check "Run 宛て型の見回りは exit 0 で続行する" test "$status" -eq 0
check "Run 宛て型は edit しない" not_grep '^orca automations edit' "$log"
check "Run 宛て型でも交代の記録は残す" grep -q '^gh issue comment' "$log"

# --- dry-run は何も実行しない ----------------------------------------------

case_dir="$root/dry-run"
prepare_case "$case_dir"
run_switch "$root/dry-run.log" --dry-run --poll-interval 1 --ack-timeout 2

check "dry-run は exit 0" test "$status" -eq 0
check "dry-run は orca も gh も呼ばない" test ! -s "$log"
check "dry-run は予定を出す" grep -q 'dry-run' "$root/dry-run.log"
check "dry-run は worktree create の予定を出す" grep -q 'worktree create' "$root/dry-run.log"
check "dry-run は terminal close の予定を出す" grep -q 'terminal close' "$root/dry-run.log"
check "dry-run は見回りの向け替えの予定を出す" grep -q 'automations edit' "$root/dry-run.log"
check "dry-run は issue コメントの予定を出す" grep -q 'issue comment' "$root/dry-run.log"

# --- 結果 -----------------------------------------------------------------

if [ "$failures" -ne 0 ]; then
  printf '%d 件失敗\n' "$failures" >&2
  exit 1
fi
printf 'すべて成功\n'
