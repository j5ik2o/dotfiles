#!/usr/bin/env bash
set -euo pipefail

log() {
  printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"
}

die() {
  echo "error: $*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

need_sudo() {
  [[ "${EUID:-$(id -u)}" -ne 0 ]]
}

run_sudo() {
  if need_sudo; then
    sudo "$@"
  else
    "$@"
  fi
}

ensure_repo() {
  local root
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  if [[ ! -f "$root/flake.nix" ]]; then
    die "run this script from inside the dotfiles repo"
  fi
  echo "$root"
}

ensure_xcode_cli() {
  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools: OK"
    return
  fi
  log "Installing Xcode Command Line Tools..."
  xcode-select --install || true
  die "Xcode Command Line Tools installation started. Finish it, then rerun this script."
}

ensure_homebrew() {
  if command_exists brew; then
    log "Homebrew: OK"
  else
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_nix_darwin() {
  if command_exists nix; then
    log "Nix: OK"
    return
  fi
  log "Installing Nix (single-user)..."
  sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
  if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck source=/dev/null
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
}

ensure_nix_linux() {
  if command_exists nix; then
    log "Nix: OK"
    return
  fi
  log "Installing Nix (multi-user daemon)..."
  sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
  if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck source=/dev/null
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
}

ensure_linux_prereqs() {
  if command_exists apt-get; then
    log "Installing Linux prerequisites (curl git xz-utils)..."
    run_sudo apt-get update
    run_sudo apt-get install -y curl git xz-utils
  else
    log "apt-get not found; please install curl, git, xz-utils manually"
  fi
}

main() {
  local root
  root="$(ensure_repo)"

  case "$(uname -s)" in
    Darwin)
      ensure_xcode_cli
      ensure_homebrew
      ensure_nix_darwin
      ;;
    Linux)
      ensure_linux_prereqs
      ensure_nix_linux
      ;;
    *)
      die "unsupported OS"
      ;;
  esac

  log "Running initial setup (make init)..."
  (cd "$root" && make init)

  cat <<'MSG'

Next steps (manual):
- Change default shell if needed
  - macOS: chsh -s /run/current-system/sw/bin/zsh
  - Linux: sudo sh -c "echo $HOME/.nix-profile/bin/zsh >> /etc/shells" && chsh -s $HOME/.nix-profile/bin/zsh
- Restart shell or log out/in
- If using 1Password/chezmoi secrets: make secrets-init && make secrets-apply
MSG
}

main "$@"
