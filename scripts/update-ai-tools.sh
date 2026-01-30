#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/update-ai-tools.sh [options]

Options:
  --codex-version <x.y.z>     Pin codex to this version (default: latest GitHub release)
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

require_cmd jq
require_cmd nix
require_cmd npm
require_cmd python3
require_cmd curl

update_ai_tools_toml() {
  AI_TOOLS_FILE="${AI_TOOLS_FILE}" \
  CODEX_VERSION="${CODEX_VERSION:-}" \
  CODEX_HASH_AARCH64_DARWIN="${CODEX_HASH_AARCH64_DARWIN:-}" \
  CODEX_HASH_X86_64_DARWIN="${CODEX_HASH_X86_64_DARWIN:-}" \
  CODEX_HASH_AARCH64_LINUX="${CODEX_HASH_AARCH64_LINUX:-}" \
  CODEX_HASH_X86_64_LINUX="${CODEX_HASH_X86_64_LINUX:-}" \
  CLAUDE_VERSION="${CLAUDE_VERSION:-}" \
  CLAUDE_HASH_AARCH64_DARWIN="${CLAUDE_HASH_AARCH64_DARWIN:-}" \
  CLAUDE_HASH_X86_64_DARWIN="${CLAUDE_HASH_X86_64_DARWIN:-}" \
  CLAUDE_HASH_AARCH64_LINUX="${CLAUDE_HASH_AARCH64_LINUX:-}" \
  CLAUDE_HASH_X86_64_LINUX="${CLAUDE_HASH_X86_64_LINUX:-}" \
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
data["claude-code"].setdefault("hashes", {})

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
claude_hash_map = {
    "aarch64-darwin": os.environ.get("CLAUDE_HASH_AARCH64_DARWIN", ""),
    "x86_64-darwin": os.environ.get("CLAUDE_HASH_X86_64_DARWIN", ""),
    "aarch64-linux": os.environ.get("CLAUDE_HASH_AARCH64_LINUX", ""),
    "x86_64-linux": os.environ.get("CLAUDE_HASH_X86_64_LINUX", ""),
}
for key, value in claude_hash_map.items():
    if value:
        data["claude-code"]["hashes"][key] = value

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
claude_hashes = claude.get("hashes", {})
for key in ["aarch64-darwin", "x86_64-darwin", "aarch64-linux", "x86_64-linux"]:
    if not claude_hashes.get(key):
        missing.append(f"claude-code.hashes.{key}")

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
lines.append("")
lines.append('["claude-code".hashes]')
for key in ["aarch64-darwin", "x86_64-darwin", "aarch64-linux", "x86_64-linux"]:
    lines.append(f'"{key}" = "{claude_hashes[key]}"')
lines.append("")

path.write_text("\n".join(lines))
PY
}

resolve_codex_release() {
  local desired_version="${1:-}"
  local api_url="https://api.github.com/repos/openai/codex/releases?per_page=100"
  local auth_args=()

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth_args=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  local releases_json
  releases_json="$(curl -fsSL "${auth_args[@]}" "${api_url}")" \
    || die "failed to fetch codex releases from GitHub"

  local script
  script="$(cat <<'PY'
import json
import os
import re
import sys

desired = os.environ.get("DESIRED_VERSION", "").strip()

try:
    releases = json.load(sys.stdin)
except Exception as exc:
    sys.exit(f"failed to parse GitHub releases JSON: {exc}")


def version_from_tag(tag: str | None) -> str | None:
    if not tag:
        return None
    match = re.search(r"(\d+\.\d+\.\d+)", tag)
    return match.group(1) if match else None


def has_codex_assets(rel: dict) -> bool:
    for asset in rel.get("assets") or []:
        name = asset.get("name", "")
        if name.startswith("codex-") and name.endswith(".tar.gz"):
            return True
    return False


candidates = []
for rel in releases:
    if rel.get("draft") or rel.get("prerelease"):
        continue
    if not has_codex_assets(rel):
        continue
    tag = rel.get("tag_name", "")
    version = version_from_tag(tag)
    if not version:
        continue
    candidates.append((tuple(int(x) for x in version.split(".")), tag, version))

if desired:
    for _, tag, version in candidates:
        if desired == version or desired == tag:
            print(f"{tag}\t{version}")
            sys.exit(0)
    sys.exit(f"codex release not found for {desired}")

if not candidates:
    sys.exit("no codex releases with assets found")

best = max(candidates, key=lambda x: x[0])
print(f"{best[1]}\t{best[2]}")
PY
)"

  printf '%s' "${releases_json}" | DESIRED_VERSION="${desired_version}" python3 -c "${script}"
}

if [[ "$SKIP_CODEX" -eq 0 ]]; then
  if [[ -z "$CODEX_VERSION" ]]; then
    read -r CODEX_TAG CODEX_VERSION < <(resolve_codex_release "")
  else
    read -r CODEX_TAG CODEX_VERSION < <(resolve_codex_release "${CODEX_VERSION}")
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
    url="https://github.com/openai/codex/releases/download/${CODEX_TAG}/codex-${target}.tar.gz"
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

  # Keep this base URL in sync with packages/claude-code.nix.
  CLAUDE_BASE_URL="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

  declare -A CLAUDE_TARGETS=(
    ["aarch64-darwin"]="darwin-arm64"
    ["x86_64-darwin"]="darwin-x64"
    ["aarch64-linux"]="linux-arm64"
    ["x86_64-linux"]="linux-x64"
  )
  declare -A CLAUDE_HASHES=()

  for system in "${!CLAUDE_TARGETS[@]}"; do
    target="${CLAUDE_TARGETS[$system]}"
    url="${CLAUDE_BASE_URL}/${CLAUDE_VERSION}/${target}/claude"
    CLAUDE_HASHES["$system"]="$(nix store prefetch-file --json "${url}" | json_hash)"
  done

  CLAUDE_HASH_AARCH64_DARWIN="${CLAUDE_HASHES[aarch64-darwin]}"
  CLAUDE_HASH_X86_64_DARWIN="${CLAUDE_HASHES[x86_64-darwin]}"
  CLAUDE_HASH_AARCH64_LINUX="${CLAUDE_HASHES[aarch64-linux]}"
  CLAUDE_HASH_X86_64_LINUX="${CLAUDE_HASHES[x86_64-linux]}"
  update_ai_tools_toml
fi

echo "==> done"
