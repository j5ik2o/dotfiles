#!/usr/bin/env bash

set -euo pipefail

gate_status=${GATE_STATUS-}
commit_subject_result=${COMMIT_SUBJECT_RESULT-}
flake_check_result=${FLAKE_CHECK_RESULT-}

printf 'gate: %s, commit-subject: %s, flake-check: %s\n' \
  "${gate_status:-missing}" "${commit_subject_result:-missing}" "${flake_check_result:-missing}"

[[ $gate_status == success && $commit_subject_result == success && $flake_check_result == success ]]
