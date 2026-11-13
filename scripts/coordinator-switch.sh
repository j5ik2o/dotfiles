#!/usr/bin/env bash
# Orca 上で動く coordinator を次の担当へ交代させる手順一式を 1 本にまとめた。
#
#   coordinator-switch.sh --brief FILE [options]
#
# 手順は issue #187 の順序どおり:
#   1. 引き継ぎ文書と進行中の作業の記録 (<repo>/.takt/goals/) の存在確認
#   2. 後任の作業ツリーの作成と opencode の起動
#   3. 後任の受け取り報告の待機 (短い間隔のポーリング)
#   4. 現任ターミナルの停止と一覧からの消失確認
#   5. 見回り automation の現任から後任への向け替え
#   6. issue #187 への交代記録
#
# 外部コマンド (orca / gh / date / python3) は PATH から解決する。
# テストが偽コマンドを差し込めるようにするため。python3 の版は
# config/mise/mise.toml で固定する (jq は mise に無い)。
#
# exit 2 は使用法エラー (--brief なし)、exit 1 は手順の失敗。

set -euo pipefail

# 交代の記録を残す先。このスクリプト自体の issue とリポジトリに固定する。
issue=187
issue_repo=j5ik2o/dotfiles

# 既定値は order.md が実物で確認した dotfiles の現在の値。
repo_default=/Users/j5ik2o/Sources/j5ik2o.github.com/j5ik2o/dotfiles
worktree_name_default=pm-glm53
model_default='ollama/glm-5.3:cloud'
run_default=run_f68036e10a4f
coordinator_terminal_default=term_df2b7535-9163-4382-aacf-57a6a729552d
watch_default=orca-dotfiles-watch
poll_interval_default=30
ack_timeout_default=1800

die() {
  printf 'エラー: %s\n' "$*" >&2
  exit 1
}

usage() {
  printf 'usage: %s --brief FILE [--repo DIR] [--worktree-name NAME] [--model MODEL] [--run RUN] [--coordinator-terminal TERMINAL] [--handoff FILE] [--watch NAME] [--poll-interval SECONDS] [--ack-timeout SECONDS] [--dry-run]\n' \
    "${0##*/}" >&2
}

repo=$repo_default
worktree_name=$worktree_name_default
model=$model_default
run=$run_default
coordinator_terminal=$coordinator_terminal_default
brief=
handoff=
watch=$watch_default
poll_interval=$poll_interval_default
ack_timeout=$ack_timeout_default
dry_run=0

while (($# > 0)); do
  opt=$1
  case $opt in
    --dry-run)
      dry_run=1
      shift
      continue
      ;;
    --brief | --repo | --worktree-name | --model | --run | --coordinator-terminal | --handoff | --watch | --poll-interval | --ack-timeout) ;;
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
    --brief) brief=$2 ;;
    --repo) repo=$2 ;;
    --worktree-name) worktree_name=$2 ;;
    --model) model=$2 ;;
    --run) run=$2 ;;
    --coordinator-terminal) coordinator_terminal=$2 ;;
    --handoff) handoff=$2 ;;
    --watch) watch=$2 ;;
    --poll-interval) poll_interval=$2 ;;
    --ack-timeout) ack_timeout=$2 ;;
  esac
  shift 2
done

if [ -z "$brief" ]; then
  usage
  exit 2
fi

# 引き継ぎ文書の慣例置き場は ~/orca/handoff/<repo>/handoff-coordinator-<日付>.md。
if [ -z "$handoff" ]; then
  handoff="$HOME/orca/handoff/dotfiles/handoff-coordinator-$(date +%Y-%m-%d).md"
fi

# orca の応答 JSON を読む細い helper。JSON は stdin へ渡し、判定結果は
# 終了コードか stdout で返す。応答の形は orca_json 内に閉じさせる。
#   worktree-exists <name>   result.worktrees[].displayName に <name> があるか
#   launch-handle            result.launch.outcome.handle を stdout へ
#   inbox-has-subject <s>    result.messages[].subject に <s> があるか
#   terminal-exists <handle> result.terminals[].handle に <handle> があるか
#   automation-id <name>     名前一致の automation の id を stdout へ
#   automation-prompt <name> 名前一致の automation の prompt を stdout へ
orca_json() {
  python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit(3)
result = data.get("result") if isinstance(data, dict) else None
if not isinstance(result, dict):
    result = {}


def entries(key):
    value = result.get(key)
    if isinstance(value, list):
        return [e for e in value if isinstance(e, dict)]
    return []


mode = sys.argv[1]
arg = sys.argv[2] if len(sys.argv) > 2 else None

if mode == "worktree-exists":
    sys.exit(0 if any(e.get("displayName") == arg for e in entries("worktrees")) else 1)
if mode == "launch-handle":
    launch = result.get("launch")
    outcome = launch.get("outcome") if isinstance(launch, dict) else None
    handle = outcome.get("handle") if isinstance(outcome, dict) else None
    if not isinstance(handle, str) or not handle:
        sys.exit(1)
    print(handle)
    sys.exit(0)
if mode == "inbox-has-subject":
    sys.exit(0 if any(e.get("subject") == arg for e in entries("messages")) else 1)
if mode == "terminal-exists":
    sys.exit(0 if any(e.get("handle") == arg for e in entries("terminals")) else 1)
if mode in ("automation-id", "automation-prompt"):
    key = "id" if mode == "automation-id" else "prompt"
    for e in entries("automations"):
        if e.get("name") == arg:
            value = e.get(key)
            if isinstance(value, str):
                print(value)
                sys.exit(0)
    sys.exit(1)
sys.exit(3)
' "$@"
}

# --- 手順 1: 引き継ぎの確認 -------------------------------------------------

if [ ! -f "$brief" ]; then
  die "指示書が見つかりません: $brief"
fi
if [ ! -f "$handoff" ]; then
  die "現任の引き継ぎ文書が見つかりません: $handoff"
fi

goals_dir="$repo/.takt/goals"
goals_records=$(find "$goals_dir" -type f -print -quit 2>/dev/null || true)
if [ -z "$goals_records" ]; then
  die "進行中の作業の記録が見つかりません: $goals_dir"
fi

# 受け取り報告の件名。実行時のエポック秒で一意にし、過去の交代の報告と
# 区別する。テストの偽 date は +%s だけ実時間を返すため、この形で呼ぶ。
ack_subject="handoff-ack-$(date +%s)"

prompt="あなたは Run $run の後任の coordinator です。まず指示書 $brief と引き継ぎ文書 $handoff を読んでください。次に orca orchestration run-use --id $run を実行して Run を引き継ぎ、終わっている作業と待っている作業を自分の言葉でまとめてください。まとめたら、その内容を本文として orca orchestration send --to run:$run --subject $ack_subject を実行し、受け取りを報告してください。"

if ((dry_run)); then
  printf 'dry-run: 実際の交代は行いません。手順と実行予定のコマンドだけを表示します。\n'
  printf 'dry-run: 手順 1: 引き継ぎ文書と進行中の作業の記録を確認しました。\n'
  printf 'dry-run: 手順 2: orca worktree create --repo path:%s --name %s --agent opencode --model %s --prompt <後任への指示> --json\n' \
    "$repo" "$worktree_name" "$model"
  printf 'dry-run: 手順 3: orca orchestration inbox --terminal run:%s --json を %s 秒間隔で確認し、件名 %s の報告を最大 %s 秒待ちます。\n' \
    "$run" "$poll_interval" "$ack_subject" "$ack_timeout"
  printf 'dry-run: 手順 4: orca terminal close --terminal %s --tab --json の後、orca terminal list --json で一覧から消えたことを確認します。\n' \
    "$coordinator_terminal"
  printf 'dry-run: 手順 5: orca automations list --json で見回り %s を特定し、prompt 内の現任ターミナルを後任へ置換して orca automations edit --id <id> --prompt <置換後> --json で向け替えます。\n' \
    "$watch"
  printf 'dry-run: 手順 6: gh issue comment %s -R %s --body <止めた時刻・現任と後任のターミナル・モデル・Run>\n' \
    "$issue" "$issue_repo"
  exit 0
fi

# --- 手順 2: 後任の作業ツリーの作成と起動 -----------------------------------

# 同名の作業ツリーが既にあれば、作成の前に止まる。作ってから失敗すると
# 作りかけの後任が残るため。
out=$(orca worktree list --repo "path:$repo" --json) \
  || die "作業ツリーの一覧を取得できませんでした"
if printf '%s' "$out" | orca_json worktree-exists "$worktree_name"; then
  die "同名の作業ツリー $worktree_name が既に存在します。--worktree-name で別の名前を指定してください"
fi

out=$(orca worktree create --repo "path:$repo" --name "$worktree_name" \
  --agent opencode --model "$model" --prompt "$prompt" --json) \
  || die "後任の作業ツリー $worktree_name の作成に失敗しました"
new_terminal=$(printf '%s' "$out" | orca_json launch-handle) \
  || die "後任ターミナルの handle を応答から取得できませんでした"
printf '手順 2: 後任 %s を起動しました (ターミナル %s)\n' "$worktree_name" "$new_terminal"

# --- 手順 3: 後任の受け取りの確認 -------------------------------------------

# 短い間隔で Run の mailbox を確認し、上限時間を過ぎたら現任を止めずに
# 異常終了する。締め切りは date +%s の実時間で測る。
started=$(date +%s)
deadline=$((started + ack_timeout))
while :; do
  out=$(orca orchestration inbox --terminal "run:$run" --json) \
    || die "Run の mailbox を読めませんでした"
  if printf '%s' "$out" | orca_json inbox-has-subject "$ack_subject"; then
    break
  fi
  now=$(date +%s)
  if ((now >= deadline)); then
    die "後任の受け取りの確認が取れませんでした。現任を止めずに終了します"
  fi
  sleep "$poll_interval"
done
printf '手順 3: 後任の受け取りを確認しました (件名 %s)\n' "$ack_subject"

# --- 手順 4: 現任の停止と消滅の確認 -----------------------------------------

# --tab を付けるとタブごと閉じて durable persistence を待つ。閉じた応答を
# 受け取っただけでは止まった扱いにせず、一覧から消えたことを確認する。
orca terminal close --terminal "$coordinator_terminal" --tab --json >/dev/null \
  || die "現任ターミナルの停止に失敗しました"
out=$(orca terminal list --json) || die "ターミナルの一覧を取得できませんでした"
if printf '%s' "$out" | orca_json terminal-exists "$coordinator_terminal"; then
  die "現任ターミナル $coordinator_terminal が一覧に残っています"
fi
printf '手順 4: 現任ターミナル %s を停止し、一覧から消えたことを確認しました\n' \
  "$coordinator_terminal"

# --- 手順 5: 見回りの向け替え -----------------------------------------------

out=$(orca automations list --json) || die "見回りの一覧を取得できませんでした"
automation_id=$(printf '%s' "$out" | orca_json automation-id "$watch") \
  || die "見回り $watch が見つかりませんでした。--watch で正しい名前を指定してください"
watch_prompt=$(printf '%s' "$out" | orca_json automation-prompt "$watch") \
  || die "見回り $watch の prompt を読めませんでした"
if [[ $watch_prompt == *"$coordinator_terminal"* ]]; then
  new_watch_prompt=${watch_prompt//"$coordinator_terminal"/"$new_terminal"}
  orca automations edit --id "$automation_id" --prompt "$new_watch_prompt" --json >/dev/null \
    || die "見回り $watch の向け替えに失敗しました"
  printf '手順 5: 見回り %s を後任ターミナル %s へ向け替えました\n' \
    "$watch" "$new_terminal"
else
  # Run 宛て型の見回りは向き先が Run で固定のため、付け替えは要らない。
  printf '手順 5: 見回り %s は Run 宛てのため、向け替えは不要でした\n' "$watch"
fi

# --- 手順 6: 交代の記録 ----------------------------------------------------

stopped_at=$(date '+%Y-%m-%d %H:%M:%S %Z')
body="coordinator を交代しました。
- 止めた時刻: $stopped_at
- 現任ターミナル: $coordinator_terminal
- 後任ターミナル: $new_terminal
- モデル: $model
- Run: $run"

gh issue comment "$issue" -R "$issue_repo" --body "$body" >/dev/null \
  || die "交代の記録を issue #$issue へコメントできませんでした"
printf '手順 6: 交代の記録を issue #%s へコメントしました\n' "$issue"
