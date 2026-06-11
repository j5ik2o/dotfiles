#!/usr/bin/env bash

export CLAUDE_IDENTITY="corporate"
export CLAUDE_CONFIG_DIR="${HOME}/.claude"
unset CLAUDE_CODE_OAUTH_TOKEN

# --happy オプションを検出して Happy Coder モードで起動
use_happy=false
args=()
for arg in "$@"; do
  if [[ "$arg" == "--happy" ]]; then
    use_happy=true
  else
    args+=("$arg")
  fi
done

if $use_happy; then
  exec "$(mise which happy)" --permission-mode bypassPermissions "${args[@]}"
else
  exec "$(mise which claude)" --dangerously-skip-permissions "${args[@]}"
fi
