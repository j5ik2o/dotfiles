#!/usr/bin/env bash
# git-ai-commit.sh - Claude Opus 4.5 を使ってコミットメッセージを生成

set -eu

# ステージングされた変更があるか確認
if git diff --staged --quiet; then
  echo "❌ Error: No staged changes to commit" >&2
  exit 1
fi

# diff を取得（サイズ制限付き）
DIFF=$(git diff --staged)
DIFF_SIZE=${#DIFF}

# diff が大きすぎる場合は統計情報のみ使用
if [ $DIFF_SIZE -gt 6000 ]; then
  DIFF_STAT=$(git diff --staged --stat)
  DIFF_SAMPLE=$(git diff --staged --unified=2 | head -n 40)
  DIFF_CONTENT="File changes:
$DIFF_STAT

Sample diff (first 40 lines):
$DIFF_SAMPLE"
else
  DIFF_CONTENT="$DIFF"
fi

# メッセージ生成
echo "🤖 Generating commit message with Claude Opus 4.5..." >&2

# プロンプトを構築
PROMPT="You are a git commit message generator. Output ONLY the commit message in Conventional Commits format. Do NOT ask questions. Do NOT add explanations. Do NOT use markdown code blocks. Do NOT add any preamble or postamble.

Format:
type: brief description (max 50 chars)

Optional detailed explanation (max 72 chars per line)

Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build

Changes:
$DIFF_CONTENT

Output the commit message NOW:"

# Claude Code で生成（Opus 4.5 を使用）
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

claude -p --model opus --dangerously-skip-permissions "$PROMPT" > "$TEMP_FILE" 2>/dev/null
COMMIT_MSG=$(cat "$TEMP_FILE")

# 空チェック
if [ -z "$COMMIT_MSG" ]; then
  echo "❌ Error: Failed to generate commit message" >&2
  exit 1
fi

# マークダウンコードブロックを除去
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMIT_MSG=$(cat "$TEMP_FILE" | python3 "$SCRIPT_DIR/clean-commit-msg.py")

# プレビュー表示
echo "" >&2
echo "📝 Generated message:" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "$COMMIT_MSG" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "" >&2

# コミット実行
git commit -m "$COMMIT_MSG"

echo "✅ Committed successfully!" >&2
