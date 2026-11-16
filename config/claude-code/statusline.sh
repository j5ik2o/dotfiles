#!/usr/bin/env bash

INPUT=$(cat)
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "unknown"')
PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
IDENTITY="${CLAUDE_IDENTITY:-unknown}"

echo "[${IDENTITY}] [${MODEL}] context: ${PCT}%"
