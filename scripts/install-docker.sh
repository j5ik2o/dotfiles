#!/usr/bin/env bash
# install-docker.sh - Install Docker Engine (dockerd) on Debian/Ubuntu via apt

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "sudo is required to install Docker Engine" >&2
    exit 1
  fi
else
  SUDO=""
fi

if [[ ! -f /etc/os-release ]]; then
  echo "Unsupported OS: /etc/os-release not found" >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID}" != "ubuntu" && "${ID}" != "debian" && "${ID_LIKE:-}" != *"debian"* ]]; then
  echo "Unsupported distro: ${ID} (supported: Debian/Ubuntu)" >&2
  exit 1
fi

DOCKER_INSTALLED=0
if command -v dockerd >/dev/null 2>&1; then
  DOCKER_INSTALLED=1
fi

DOCKER_DATA_ROOT="${DOCKER_DATA_ROOT:-}"
DOCKER_DATA_ROOT_MIGRATE="${DOCKER_DATA_ROOT_MIGRATE:-0}"
DOCKER_CONFIG_UPDATED=0

if [[ "${DOCKER_INSTALLED}" -eq 0 ]]; then
  echo "Installing Docker Engine for ${ID} ${VERSION_ID:-}..."

  ${SUDO} apt-get update
  ${SUDO} apt-get install -y ca-certificates curl gnupg

  ${SUDO} install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL "https://download.docker.com/linux/${ID}/gpg" | ${SUDO} gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    ${SUDO} chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  ARCH="$(dpkg --print-architecture)"
  CODENAME="${VERSION_CODENAME:-}"
  if [[ -z "${CODENAME}" ]]; then
    if command -v lsb_release >/dev/null 2>&1; then
      CODENAME="$(lsb_release -cs)"
    else
      echo "Unable to determine distro codename" >&2
      exit 1
    fi
  fi

  ${SUDO} tee /etc/apt/sources.list.d/docker.list >/dev/null <<EOF
deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} ${CODENAME} stable
EOF

  ${SUDO} apt-get update
  ${SUDO} apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "dockerd already installed; ensuring configuration"
fi

if [[ -n "${DOCKER_DATA_ROOT}" ]]; then
  ${SUDO} install -m 0755 -d /etc/docker
  if [[ -f /etc/docker/daemon.json ]] && ${SUDO} grep -q '"data-root"' /etc/docker/daemon.json; then
    echo "Docker data-root already configured; leaving /etc/docker/daemon.json unchanged"
  else
    DEFAULT_DOCKER_DATA_ROOT="/var/lib/docker"
    if ${SUDO} sh -c 'test -d "$1" && [ "$(ls -A "$1" 2>/dev/null)" ]' _ "${DEFAULT_DOCKER_DATA_ROOT}"; then
      if [[ "${DOCKER_DATA_ROOT_MIGRATE}" == "1" ]]; then
        echo "Copying existing Docker data to ${DOCKER_DATA_ROOT}..."
        ${SUDO} install -m 0711 -d "${DOCKER_DATA_ROOT}"
        if command -v systemctl >/dev/null 2>&1; then
          ${SUDO} systemctl stop docker || true
        fi
        if command -v rsync >/dev/null 2>&1; then
          ${SUDO} rsync -aHAX --numeric-ids "${DEFAULT_DOCKER_DATA_ROOT}/" "${DOCKER_DATA_ROOT}/"
        else
          ${SUDO} cp -a "${DEFAULT_DOCKER_DATA_ROOT}/." "${DOCKER_DATA_ROOT}/"
        fi
      else
        echo "Existing Docker data found at ${DEFAULT_DOCKER_DATA_ROOT}; skipping migration"
        echo "Set DOCKER_DATA_ROOT_MIGRATE=1 to copy data automatically"
        ${SUDO} install -m 0711 -d "${DOCKER_DATA_ROOT}"
      fi
    else
      ${SUDO} install -m 0711 -d "${DOCKER_DATA_ROOT}"
    fi

    if [[ -f /etc/docker/daemon.json ]]; then
      if command -v jq >/dev/null 2>&1; then
        ${SUDO} jq ". + {\"data-root\": \"${DOCKER_DATA_ROOT}\"}" /etc/docker/daemon.json \
          | ${SUDO} tee /etc/docker/daemon.json.tmp >/dev/null
        ${SUDO} mv /etc/docker/daemon.json.tmp /etc/docker/daemon.json
        DOCKER_CONFIG_UPDATED=1
      elif command -v python3 >/dev/null 2>&1; then
        if ${SUDO} python3 - "${DOCKER_DATA_ROOT}" /etc/docker/daemon.json /etc/docker/daemon.json.tmp <<'PY'
import json
import sys

data_root = sys.argv[1]
src = sys.argv[2]
dst = sys.argv[3]

with open(src, "r", encoding="utf-8") as f:
    data = json.load(f)

data["data-root"] = data_root

with open(dst, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, sort_keys=True)
    f.write("\n")
PY
        then
          ${SUDO} mv /etc/docker/daemon.json.tmp /etc/docker/daemon.json
          DOCKER_CONFIG_UPDATED=1
        else
          echo "Failed to update /etc/docker/daemon.json; leaving unchanged" >&2
          ${SUDO} rm -f /etc/docker/daemon.json.tmp
        fi
      else
        echo "jq or python3 is required to update /etc/docker/daemon.json; leaving unchanged" >&2
      fi
    else
      ${SUDO} tee /etc/docker/daemon.json >/dev/null <<EOF
{
  "data-root": "${DOCKER_DATA_ROOT}"
}
EOF
      DOCKER_CONFIG_UPDATED=1
    fi
  fi
else
  echo "DOCKER_DATA_ROOT not set; skipping Docker data-root configuration"
fi

if command -v systemctl >/dev/null 2>&1; then
  ${SUDO} systemctl enable docker
  if ${SUDO} systemctl is-active --quiet docker; then
    if [[ "${DOCKER_CONFIG_UPDATED}" -eq 1 ]]; then
      ${SUDO} systemctl restart docker
    fi
  else
    ${SUDO} systemctl start docker
  fi
else
  echo "systemctl not found; start dockerd manually if needed"
fi

# Add the invoking user to the docker group for non-root usage
if ! getent group docker >/dev/null 2>&1; then
  ${SUDO} groupadd docker
fi

TARGET_USER="${SUDO_USER:-${USER}}"
if [[ -n "${TARGET_USER}" ]]; then
  ${SUDO} usermod -aG docker "${TARGET_USER}"
  echo "Added ${TARGET_USER} to docker group. Please log out/in to apply."
fi

echo "Docker Engine installation completed."
