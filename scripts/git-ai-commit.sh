#!/usr/bin/env bash
# git-ai-commit.sh - Claude Code を使ってコミットメッセージを生成

set -euo pipefail

# ステージングされた変更があるか確認
if git diff --staged --quiet; then
  echo "Error: No staged changes to commit" >&2
  exit 1
fi

# diff を取得
DIFF=$(git diff --staged)

# Claude Code で コミットメッセージを生成
PROMPT="以下のgit diffからコミットメッセージを生成してください。
フォーマット: Conventional Commits形式 (type: description)
- type: feat, fix, docs, style, refactor, test, chore など
- 1行目は50文字以内の要約
- 必要に応じて空行後に詳細を追加
- 英語で記述

コミットメッセージのみを出力してください（説明や前置きは不要）。

diff:
$DIFF"

# 非対話モードで実行
COMMIT_MSG=$(claude -p "$PROMPT" 2>/dev/null)

if [ -z "$COMMIT_MSG" ]; then
  echo "Error: Failed to generate commit message" >&2
  exit 1
fi

# コミット実行
git commit -m "$COMMIT_MSG"

echo "Committed with message:"
echo "$COMMIT_MSG"
