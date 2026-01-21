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

if command -v dockerd >/dev/null 2>&1; then
  echo "dockerd already installed"
  exit 0
fi

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

if command -v systemctl >/dev/null 2>&1; then
  ${SUDO} systemctl enable --now docker
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
