#!/usr/bin/env bash

export CLAUDE_IDENTITY="corporate"
export CLAUDE_CONFIG_DIR="${HOME}/.claude"
unset CLAUDE_CODE_OAUTH_TOKEN

exec mise exec claude -- claude --dangerously-skip-permissions "$@"
