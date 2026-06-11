#!/usr/bin/env bash

export CODEX_HOME="${HOME}/.codex"
exec mise exec codex -- codex --dangerously-bypass-approvals-and-sandbox "$@"
