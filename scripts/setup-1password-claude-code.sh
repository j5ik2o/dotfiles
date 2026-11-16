#!/usr/bin/env bash
#
# Claude Code の OAuth トークンを 1Password に登録・更新する。
# 使い方:
#   ./scripts/setup-1password-claude-code.sh personal <token>
#   ./scripts/setup-1password-claude-code.sh corporate <token>
#   ./scripts/setup-1password-claude-code.sh            # 対話モード
#

set -euo pipefail

ITEM_TITLE="Claude Code"

declare -A VAULT_MAP=(
  [personal]="Private"
  [corporate]="IDEO PLUS"
)

usage() {
  echo "Usage: $0 [personal|corporate] [token]"
  echo ""
  echo "Arguments:"
  echo "  identity   personal or corporate (prompted if omitted)"
  echo "  token      OAuth token value (prompted securely if omitted)"
  exit 1
}

check_op_cli() {
  if ! command -v op >/dev/null 2>&1; then
    echo "Error: 1Password CLI (op) is not installed."
    echo "Install: https://developer.1password.com/docs/cli/get-started/"
    exit 1
  fi
  if ! op account list >/dev/null 2>&1; then
    echo "Error: Not signed in to 1Password CLI. Run 'op signin' first."
    exit 1
  fi
}

prompt_identity() {
  echo "Select identity:" >&2
  echo "  1) personal  (vault: Private)" >&2
  echo "  2) corporate (vault: IDEO PLUS)" >&2
  read -rp "Choice [1/2]: " choice
  case "$choice" in
    1) echo "personal" ;;
    2) echo "corporate" ;;
    *) echo "Error: Invalid choice" >&2; exit 1 ;;
  esac
}

show_token_help() {
  cat >&2 <<'HELP'

--- OAuth トークンの取得方法 ---

  $ claude setup-token

  表示されたトークンをコピーして貼り付けてください。

--------------------------------
HELP
}

prompt_token() {
  local identity="$1"
  show_token_help
  read -rsp "Enter OAuth token for ${identity}: " token
  echo "" >&2
  if [[ -z "$token" ]]; then
    echo "Error: Token cannot be empty" >&2
    exit 1
  fi
  echo "$token"
}

create_or_update() {
  local vault="$1"
  local token="$2"

  # アイテムが存在するか確認
  if op item get "$ITEM_TITLE" --vault "$vault" >/dev/null 2>&1; then
    op item edit "$ITEM_TITLE" --vault "$vault" "oauth_token=$token"
    echo "Updated '${ITEM_TITLE}' in vault '${vault}'."
  else
    op item create --category login \
      --title "$ITEM_TITLE" \
      --vault "$vault" \
      "oauth_token=$token"
    echo "Created '${ITEM_TITLE}' in vault '${vault}'."
  fi
}

# --- main ---

check_op_cli

IDENTITY="${1:-}"
TOKEN="${2:-}"

if [[ -z "$IDENTITY" ]]; then
  IDENTITY=$(prompt_identity)
fi

if [[ -z "${VAULT_MAP[$IDENTITY]+_}" ]]; then
  echo "Error: Unknown identity '${IDENTITY}'. Use 'personal' or 'corporate'."
  exit 1
fi

VAULT="${VAULT_MAP[$IDENTITY]}"

if [[ -z "$TOKEN" ]]; then
  TOKEN=$(prompt_token "$IDENTITY")
fi

create_or_update "$VAULT" "$TOKEN"
