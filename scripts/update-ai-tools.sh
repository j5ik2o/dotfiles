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

json_hash() {
  jq -r .hash
}

json_store_path() {
  jq -r .storePath
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AI_TOOLS_FILE="${ROOT}/packages/ai-tools.toml"

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

update_ai_tools_toml() {
  AI_TOOLS_FILE="${AI_TOOLS_FILE}" \
  CODEX_VERSION="${CODEX_VERSION:-}" \
  CODEX_HASH_AARCH64_DARWIN="${CODEX_HASH_AARCH64_DARWIN:-}" \
  CODEX_HASH_X86_64_DARWIN="${CODEX_HASH_X86_64_DARWIN:-}" \
  CODEX_HASH_AARCH64_LINUX="${CODEX_HASH_AARCH64_LINUX:-}" \
  CODEX_HASH_X86_64_LINUX="${CODEX_HASH_X86_64_LINUX:-}" \
  CLAUDE_VERSION="${CLAUDE_VERSION:-}" \
  CLAUDE_HASH="${CLAUDE_HASH:-}" \
  CLAUDE_NPM_HASH="${CLAUDE_NPM_HASH:-}" \
  python3 - <<'PY'
import os
from pathlib import Path

try:
    import tomllib  # py3.11+
except Exception:
    tomllib = None

path = Path(os.environ["AI_TOOLS_FILE"])

data = {}
if path.exists():
    if tomllib is None:
        raise SystemExit("tomllib is required to read existing ai-tools.toml")
    data = tomllib.loads(path.read_text())

data.setdefault("codex", {})
data["codex"].setdefault("hashes", {})
data.setdefault("claude-code", {})

# codex updates
if os.environ.get("CODEX_VERSION"):
    data["codex"]["version"] = os.environ["CODEX_VERSION"]
hash_map = {
    "aarch64-darwin": os.environ.get("CODEX_HASH_AARCH64_DARWIN", ""),
    "x86_64-darwin": os.environ.get("CODEX_HASH_X86_64_DARWIN", ""),
    "aarch64-linux": os.environ.get("CODEX_HASH_AARCH64_LINUX", ""),
    "x86_64-linux": os.environ.get("CODEX_HASH_X86_64_LINUX", ""),
}
for key, value in hash_map.items():
    if value:
        data["codex"]["hashes"][key] = value

# claude updates
if os.environ.get("CLAUDE_VERSION"):
    data["claude-code"]["version"] = os.environ["CLAUDE_VERSION"]
if os.environ.get("CLAUDE_HASH"):
    data["claude-code"]["hash"] = os.environ["CLAUDE_HASH"]
if os.environ.get("CLAUDE_NPM_HASH"):
    data["claude-code"]["npmDepsHash"] = os.environ["CLAUDE_NPM_HASH"]

missing = []
codex = data.get("codex", {})
codex_hashes = codex.get("hashes", {})
if not codex.get("version"):
    missing.append("codex.version")
for key in ["aarch64-darwin", "x86_64-darwin", "aarch64-linux", "x86_64-linux"]:
    if not codex_hashes.get(key):
        missing.append(f"codex.hashes.{key}")

claude = data.get("claude-code", {})
if not claude.get("version"):
    missing.append("claude-code.version")
if not claude.get("hash"):
    missing.append("claude-code.hash")
if not claude.get("npmDepsHash"):
    missing.append("claude-code.npmDepsHash")

if missing:
    raise SystemExit("missing required keys in ai-tools.toml: " + ", ".join(missing))

lines = []
lines.append("[codex]")
lines.append(f'version = "{codex["version"]}"')
lines.append("")
lines.append("[codex.hashes]")
for key in ["aarch64-darwin", "x86_64-darwin", "aarch64-linux", "x86_64-linux"]:
    lines.append(f'"{key}" = "{codex_hashes[key]}"')
lines.append("")
lines.append('["claude-code"]')
lines.append(f'version = "{claude["version"]}"')
lines.append(f'hash = "{claude["hash"]}"')
lines.append(f'npmDepsHash = "{claude["npmDepsHash"]}"')
lines.append("")

path.write_text("\n".join(lines))
PY
}

if [[ "$SKIP_CODEX" -eq 0 ]]; then
  if [[ -z "$CODEX_VERSION" ]]; then
    CODEX_TAG=$(
      git ls-remote --tags --refs https://github.com/openai/codex 'rust-v*' \
        | awk '{print $2}' \
        | sed 's@refs/tags/@@' \
        | python3 -c "$(
          cat <<'PY'
import re
import sys

tags = [line.strip() for line in sys.stdin if line.strip()]
best = None
best_tag = None
for tag in tags:
    m = re.match(r"^rust-v\.?(\d+)\.(\d+)\.(\d+)$", tag)
    if not m:
        continue
    version = tuple(int(x) for x in m.groups())
    has_dot = tag.startswith("rust-v.")
    if (
        best is None
        or version > best
        or (version == best and best_tag and best_tag.startswith("rust-v.") and not has_dot)
    ):
        best = version
        best_tag = tag
if not best_tag:
    sys.exit("no rust-v tags found")
print(best_tag)
PY
        )"
    )
    CODEX_VERSION="${CODEX_TAG#rust-v}"
  else
    CODEX_TAG="rust-v${CODEX_VERSION}"
  fi

  echo "==> codex: ${CODEX_VERSION}"

  declare -A CODEX_TARGETS=(
    ["aarch64-darwin"]="aarch64-apple-darwin"
    ["x86_64-darwin"]="x86_64-apple-darwin"
    ["aarch64-linux"]="aarch64-unknown-linux-musl"
    ["x86_64-linux"]="x86_64-unknown-linux-musl"
  )
  declare -A CODEX_HASHES=()

  for system in "${!CODEX_TARGETS[@]}"; do
    target="${CODEX_TARGETS[$system]}"
    url="https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-${target}.tar.gz"
    CODEX_HASHES["$system"]="$(nix store prefetch-file --json "${url}" | json_hash)"
  done

  CODEX_HASH_AARCH64_DARWIN="${CODEX_HASHES[aarch64-darwin]}"
  CODEX_HASH_X86_64_DARWIN="${CODEX_HASHES[x86_64-darwin]}"
  CODEX_HASH_AARCH64_LINUX="${CODEX_HASHES[aarch64-linux]}"
  CODEX_HASH_X86_64_LINUX="${CODEX_HASHES[x86_64-linux]}"
  update_ai_tools_toml
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

  CLAUDE_NPM_HASH="$(nix run nixpkgs#prefetch-npm-deps -- "${ROOT}/packages/claude-code-package-lock.json")"
  if [[ -z "${CLAUDE_NPM_HASH}" ]]; then
    die "failed to compute claude-code npmDepsHash"
  fi

  CLAUDE_HASH="${CLAUDE_SRC_HASH}"
  CLAUDE_NPM_HASH="${CLAUDE_NPM_HASH}"
  update_ai_tools_toml
fi

echo "==> done"
