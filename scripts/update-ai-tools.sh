#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/update-ai-tools.sh [options]

Options:
  --codex-version <x.y.z>     Pin codex to this version (default: latest tag)
  --claude-version <x.y.z>    Pin claude-code to this version (default: latest npm)
  --skip-codex                Skip codex update
  --skip-claude               Skip claude-code update
  -h, --help                  Show this help
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

replace_regex() {
  local file="$1"
  local pattern="$2"
  local repl="$3"
  REPLACE_FILE="$file" REPLACE_PATTERN="$pattern" REPLACE_REPL="$repl" python3 - <<'PY'
import os
import re
import sys
from pathlib import Path

path = Path(os.environ["REPLACE_FILE"])
pattern = os.environ["REPLACE_PATTERN"]
repl = os.environ["REPLACE_REPL"]

text = path.read_text()
new_text, count = re.subn(pattern, repl, text, count=1, flags=re.MULTILINE)
if count == 0:
    sys.stderr.write(f"pattern not found in {path}: {pattern}\n")
    sys.exit(1)
path.write_text(new_text)
PY
}

json_hash() {
  jq -r .hash
}

json_store_path() {
  jq -r .storePath
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CODEX_VERSION="${CODEX_VERSION:-}"
CLAUDE_VERSION="${CLAUDE_VERSION:-}"
SKIP_CODEX=0
SKIP_CLAUDE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --codex-version)
      CODEX_VERSION="${2:-}"
      shift 2
      ;;
    --claude-version)
      CLAUDE_VERSION="${2:-}"
      shift 2
      ;;
    --skip-codex)
      SKIP_CODEX=1
      shift
      ;;
    --skip-claude)
      SKIP_CLAUDE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

require_cmd git
require_cmd jq
require_cmd nix
require_cmd npm
require_cmd python3
require_cmd tar

if [[ "$SKIP_CODEX" -eq 0 ]]; then
  if [[ -z "$CODEX_VERSION" ]]; then
    CODEX_TAG=$(
      git ls-remote --tags --refs https://github.com/openai/codex 'rust-v*' \
        | awk '{print $2}' \
        | sed 's@refs/tags/@@' \
        | python3 - <<'PY'
import re
import sys

tags = [line.strip() for line in sys.stdin if line.strip()]
best = None
best_tag = None
for tag in tags:
    m = re.match(r"^rust-v(\d+)\.(\d+)\.(\d+)$", tag)
    if not m:
        continue
    version = tuple(int(x) for x in m.groups())
    if best is None or version > best:
        best = version
        best_tag = tag
if not best_tag:
    sys.exit("no rust-v tags found")
print(best_tag)
PY
    )
    CODEX_VERSION="${CODEX_TAG#rust-v}"
  else
    CODEX_TAG="rust-v${CODEX_VERSION}"
  fi

  echo "==> codex: ${CODEX_VERSION}"

  CODEX_SRC_HASH=$(
    nix store prefetch-file --json --unpack \
      "https://github.com/openai/codex/archive/refs/tags/${CODEX_TAG}.tar.gz" \
      | json_hash
  )

  CODEX_EXPR=$(
    cat <<EOF
let flake = builtins.getFlake "path:${ROOT}";
    pkgs = import flake.inputs.nixpkgs {
      system = builtins.currentSystem;
      config.allowUnfree = true;
    };
    src = pkgs.fetchFromGitHub {
      owner = "openai";
      repo = "codex";
      tag = "${CODEX_TAG}";
      hash = "${CODEX_SRC_HASH}";
    };
in pkgs.rustPlatform.buildRustPackage {
  pname = "codex";
  version = "${CODEX_VERSION}";
  inherit src;
  sourceRoot = "\${src.name}/codex-rs";
  cargoHash = "";
}
EOF
  )

  set +e
  CODEX_BUILD_OUTPUT="$(nix build --impure --expr "${CODEX_EXPR}" 2>&1)"
  CODEX_BUILD_STATUS=$?
  set -e

  CODEX_CARGO_HASH="$(
    echo "${CODEX_BUILD_OUTPUT}" \
      | sed -nE 's/.*got: *(sha256-[A-Za-z0-9+/=-]+).*/\1/p' \
      | tail -n 1
  )"

  if [[ -z "${CODEX_CARGO_HASH}" ]]; then
    echo "${CODEX_BUILD_OUTPUT}" >&2
    die "failed to compute codex cargoHash"
  fi

  replace_regex "${ROOT}/packages/codex.nix" 'version = "[^"]+";' "version = \"${CODEX_VERSION}\";"
  replace_regex "${ROOT}/packages/codex.nix" 'hash = "sha256-[^"]+";' "hash = \"${CODEX_SRC_HASH}\";"
  replace_regex "${ROOT}/packages/codex.nix" 'cargoHash = "sha256-[^"]+";' "cargoHash = \"${CODEX_CARGO_HASH}\";"
fi

if [[ "$SKIP_CLAUDE" -eq 0 ]]; then
  if [[ -z "$CLAUDE_VERSION" ]]; then
    CLAUDE_VERSION="$(npm view @anthropic-ai/claude-code version)"
  fi

  echo "==> claude-code: ${CLAUDE_VERSION}"

  CLAUDE_SRC_HASH=$(
    nix store prefetch-file --json --unpack \
      "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${CLAUDE_VERSION}.tgz" \
      | json_hash
  )

  CLAUDE_TGZ_PATH=$(
    nix store prefetch-file --json \
      "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${CLAUDE_VERSION}.tgz" \
      | json_store_path
  )

  TMPDIR="$(mktemp -d)"
  trap 'rm -rf "${TMPDIR}"' EXIT

  tar -xzf "${CLAUDE_TGZ_PATH}" -C "${TMPDIR}"
  pushd "${TMPDIR}/package" >/dev/null
  npm install --package-lock-only --ignore-scripts --silent
  popd >/dev/null
  cp "${TMPDIR}/package/package-lock.json" "${ROOT}/packages/claude-code-package-lock.json"

  replace_regex "${ROOT}/packages/claude-code.nix" 'version = "[^"]+";' "version = \"${CLAUDE_VERSION}\";"
  replace_regex "${ROOT}/packages/claude-code.nix" 'hash = "sha256-[^"]+";' "hash = \"${CLAUDE_SRC_HASH}\";"

  CLAUDE_EXPR=$(
    cat <<EOF
let flake = builtins.getFlake "path:${ROOT}";
    pkgs = import flake.inputs.nixpkgs {
      system = builtins.currentSystem;
      config.allowUnfree = true;
    };
    pkg = pkgs.callPackage ./packages/claude-code.nix { };
in pkg.overrideAttrs (_: { npmDepsHash = ""; })
EOF
  )

  set +e
  CLAUDE_BUILD_OUTPUT="$(nix build --impure --expr "${CLAUDE_EXPR}" 2>&1)"
  CLAUDE_BUILD_STATUS=$?
  set -e

  CLAUDE_NPM_HASH="$(
    echo "${CLAUDE_BUILD_OUTPUT}" \
      | sed -nE 's/.*got: *(sha256-[A-Za-z0-9+/=-]+).*/\1/p' \
      | tail -n 1
  )"

  if [[ -z "${CLAUDE_NPM_HASH}" ]]; then
    echo "${CLAUDE_BUILD_OUTPUT}" >&2
    die "failed to compute claude-code npmDepsHash"
  fi

  replace_regex "${ROOT}/packages/claude-code.nix" 'npmDepsHash = "sha256-[^"]+";' "npmDepsHash = \"${CLAUDE_NPM_HASH}\";"
fi

echo "==> done"
