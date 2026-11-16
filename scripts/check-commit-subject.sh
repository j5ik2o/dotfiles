#!/usr/bin/env bash
# コミットサブジェクトのゲート。
#
# 主題が「原因」ではなく「差分」を語っているコミットを落とす。
# 説明部分を単語に割り、その全部が「パス」「領域語」「中身のない語」で
# 埋まっていたら落とす。定義の全文は docs/commit-subject.md にある。

set -euo pipefail

types='build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test'

# 対象を指すだけで、何が悪かったのかを語らない語
area_words='bash config configs darwin dotfiles flake flakes ghostty git home-manager kitty lua mise neovim nix nixos nixpkgs nvim path paths shell shells starship tmux toml zellij zsh'
# 修飾だけで、単体では何も伝えない語
hollow_words='bug bugfix bugs default minor misc stuff thing things tweak tweaks wip'
# 説明の骨格にならない語
filler_words='a all an and around at file files for from in into its my of on our some that the this to'

usage() {
  echo "使い方: $0 --head | --subject <主題> | --message-file <パス>" >&2
  exit 2
}

mode=""
value=""
while (($# > 0)); do
  case $1 in
    --head)
      mode=git
      shift
      ;;
    --subject)
      mode=subject
      value=${2-}
      shift 2
      ;;
    --message-file)
      mode=message-file
      value=${2-}
      shift 2
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "エラー: 不明な引数: $1" >&2
      usage
      ;;
  esac
done

case $mode in
  git) subject=$(git log -1 --format=%s) ;;
  subject) subject=$value ;;
  message-file)
    [[ -f $value ]] || {
      echo "エラー: メッセージファイルがありません: $value" >&2
      exit 2
    }
    # フックが渡すのはコメント行を含む生のメッセージなので、主題だけを取り出す
    subject=$(sed -e '/^#/d' -e '/^$/d' "$value" | head -n 1)
    ;;
  *) usage ;;
esac

# squash マージで付く ` (#123)` は判定に無関係
subject=$(printf '%s' "$subject" | sed -E 's/ \(#[0-9]+\)$//')

fail() {
  local reason=$1
  echo "エラー: コミットサブジェクトが原因を語っていません ($reason)" >&2
  echo "  主題: ${subject:-(空)}" >&2
  echo "  主題は「何が悪くて何を変えたか」を書いてください。" >&2
  echo "  悪い例: fix: bug / fix: nix files / fix: mise.toml / fix: neovim" >&2
  echo "  良い例: fix(ci): resolve node from config/mise when pre-installing" >&2
  echo "  定義: docs/commit-subject.md" >&2
  exit 1
}

# git が生成するマージ / リバートの主題は書く余地がないので通す
case $subject in
  'Merge '* | 'Revert '*) exit 0 ;;
esac

if [[ ! $subject =~ ^($types)(\([^()]+\))?(!)?:[[:space:]]*(.*)$ ]]; then
  fail "Conventional Commits の形式ではない"
fi

description=$(printf '%s' "${BASH_REMATCH[4]}" | tr '[:upper:]' '[:lower:]')

if [[ -z $description ]]; then
  fail "説明が空"
fi

description=${description//[\"\',;:!?\(\)\[\]]/}

is_path_like() {
  local token=${1%/}
  [[ $token == */* ]] && return 0
  [[ $token == .* ]] && return 0
  local ext=${token##*.}
  [[ $ext != "$token" ]] || return 1
  case $ext in
    bash | cfg | conf | config | el | go | ini | js | json | lock | lua | md | nix | plist | py | rb | rs | service | sh | toml | ts | txt | vim | yaml | yml | zsh) return 0 ;;
  esac
  return 1
}

# 語を 3 つの型に振り分ける。どれにも入らない語が 1 つでもあれば、
# その説明は原因を語っているとみなす。
classified=0
paths=0
areas=0
hollows=0
for token in $description; do
  case " $filler_words " in
    *" $token "*) continue ;;
  esac
  classified=$((classified + 1))
  if is_path_like "$token"; then
    paths=$((paths + 1))
  elif [[ " $area_words " == *" $token "* ]]; then
    areas=$((areas + 1))
  elif [[ " $hollow_words " == *" $token "* ]]; then
    hollows=$((hollows + 1))
  fi
done

contentful=$((classified - paths - areas - hollows))
if ((contentful > 0)); then
  exit 0
fi

if ((paths > 0 && areas == 0 && hollows == 0)); then
  fail "説明がパスやファイル名だけ"
fi
if ((hollows > 0 && areas == 0 && paths == 0)); then
  fail "説明が中身のない語だけ"
fi
fail "説明が領域語だけで原因がない"
