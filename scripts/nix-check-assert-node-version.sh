#!/usr/bin/env bash
# PATH の Node が config/mise/mise.toml の版と一致することをログと終了コードで示す。
#
# mise.toml の node の値を正本にし、node --version の major と完全一致することを
# 要求する。node は PATH から解決する。

set -euo pipefail

expected=$(sed -nE 's/^[[:space:]]*node[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' config/mise/mise.toml)
if [ -z "$expected" ]; then
  echo "config/mise/mise.toml に node の版がない" >&2
  exit 1
fi

echo "node --version: $(node --version)"
echo "config/mise/mise.toml node: $expected"

node --version | sed -E 's/^v([0-9]+).*/\1/' | grep -qx "$expected"
