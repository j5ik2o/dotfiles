#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
gate_script="$repo_root/scripts/check-required-pr-ci.sh"
GATE_STATUS=success COMMIT_SUBJECT_RESULT=success FLAKE_CHECK_RESULT=success \
  bash "$gate_script" >/dev/null

for field in GATE_STATUS COMMIT_SUBJECT_RESULT FLAKE_CHECK_RESULT; do
  for result in failure cancelled skipped '' unknown; do
    if env GATE_STATUS=success COMMIT_SUBJECT_RESULT=success FLAKE_CHECK_RESULT=success \
      "$field=$result" bash "$gate_script" >/dev/null; then
      printf 'not ok - accepted %s=%q\n' "$field" "$result" >&2
      exit 1
    fi
  done
done

if (unset GATE_STATUS COMMIT_SUBJECT_RESULT FLAKE_CHECK_RESULT; bash "$gate_script" >/dev/null); then
  printf 'not ok - accepted missing results\n' >&2
  exit 1
fi

printf 'ok - required PR CI rejects all outcomes except success/success/success\n'
