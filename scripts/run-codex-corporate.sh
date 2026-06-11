#!/usr/bin/env bash

export CODEX_HOME="${HOME}/.codex"
exec "$(mise which codex)" --dangerously-bypass-approvals-and-sandbox "$@"
