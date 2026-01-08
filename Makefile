# ============================================================
# Dotfiles Makefile
# ============================================================

# ユーザー名 (flake.nix と一致させる)
USER := j5ik2o

# システム検出
UNAME := $(shell uname)
ARCH := $(shell uname -m)

ifeq ($(UNAME),Darwin)
  ifeq ($(ARCH),arm64)
    HM_CONFIG := $(USER)@darwin-aarch64
    DARWIN_CONFIG := $(USER)-darwin
  else
    HM_CONFIG := $(USER)@darwin-x86_64
    DARWIN_CONFIG := $(USER)-darwin-x86
  endif
else
  ifeq ($(ARCH),x86_64)
    HM_CONFIG := $(USER)@linux-x86_64
  else
    HM_CONFIG := $(USER)@linux-aarch64
  endif
endif

.PHONY: help check build build-hm build-darwin switch switch-hm switch-darwin \
        clean update fmt sheldon-lock gc test

# デフォルトターゲット
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Build targets:"
	@echo "  build          Build all (darwin on macOS, hm on Linux)"
	@echo "  build-hm       Build Home Manager configuration"
	@echo "  build-darwin   Build nix-darwin configuration (macOS only)"
	@echo ""
	@echo "Switch targets:"
	@echo "  switch         Apply all (darwin on macOS, hm on Linux)"
	@echo "  switch-hm      Apply Home Manager configuration"
	@echo "  switch-darwin  Apply nix-darwin configuration (macOS only)"
	@echo ""
	@echo "Other targets:"
	@echo "  check          Run nix flake check"
	@echo "  test           Alias for check"
	@echo "  update         Update flake inputs"
	@echo "  fmt            Format nix files"
	@echo "  clean          Remove build artifacts"
	@echo "  gc             Run nix garbage collection"
	@echo "  sheldon-lock   Lock sheldon plugins"
	@echo ""
	@echo "Detected configuration:"
	@echo "  System: $(UNAME) ($(ARCH))"
	@echo "  Home Manager: $(HM_CONFIG)"
ifeq ($(UNAME),Darwin)
	@echo "  nix-darwin: $(DARWIN_CONFIG)"
endif

# ============================================================
# Check
# ============================================================

check:
	nix flake check --no-build

test: check

# ============================================================
# Build (dry-run / test)
# ============================================================

build-hm:
	@echo "Building Home Manager configuration: $(HM_CONFIG)"
	nix build .#homeConfigurations.$(HM_CONFIG).activationPackage --show-trace

build-darwin:
ifeq ($(UNAME),Darwin)
	@echo "Building nix-darwin configuration: $(DARWIN_CONFIG)"
	nix build .#darwinConfigurations.$(DARWIN_CONFIG).system --show-trace
else
	@echo "nix-darwin is only available on macOS"
	@exit 1
endif

build:
ifeq ($(UNAME),Darwin)
	$(MAKE) build-darwin
else
	$(MAKE) build-hm
endif

# ============================================================
# Switch (apply)
# ============================================================

switch-hm:
	@echo "Applying Home Manager configuration: $(HM_CONFIG)"
	home-manager switch --flake .#$(HM_CONFIG)

switch-darwin:
ifeq ($(UNAME),Darwin)
	@echo "Applying nix-darwin configuration: $(DARWIN_CONFIG)"
	sudo darwin-rebuild switch --flake .#$(DARWIN_CONFIG)
else
	@echo "nix-darwin is only available on macOS"
	@exit 1
endif

switch:
ifeq ($(UNAME),Darwin)
	$(MAKE) switch-darwin
else
	$(MAKE) switch-hm
endif


init-darwin:
ifeq ($(UNAME),Darwin)
	@echo "Preparing for first nix-darwin installation..."
	@# バックアップが存在しない場合のみ退避（再実行時に上書きしない）
	@[ -f /etc/nix/nix.conf.before-nix-darwin ] || sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin 2>/dev/null || true
	@[ -f /etc/bashrc.before-nix-darwin ] || sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin 2>/dev/null || true
	@[ -f /etc/zshrc.before-nix-darwin ] || sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin 2>/dev/null || true
	@echo "Running initial nix-darwin switch..."
	sudo -E nix --extra-experimental-features 'nix-command flakes' run nix-darwin#darwin-rebuild -- switch --flake .#$(DARWIN_CONFIG)
else
	@echo "nix-darwin is only available on macOS"
	@exit 1
endif

# ============================================================
# Maintenance
# ============================================================

update:
	@echo "Updating flake inputs..."
	nix flake update

fmt:
	@echo "Formatting nix files..."
	find . -name "*.nix" -exec nixfmt {} \;

clean:
	@echo "Cleaning build artifacts..."
	rm -rf result
	rm -rf .direnv

gc:
	@echo "Running garbage collection..."
	nix-collect-garbage -d

gc-old:
	@echo "Removing old generations..."
	nix-collect-garbage --delete-older-than 30d

# ============================================================
# Sheldon
# ============================================================

sheldon-lock:
	@echo "Locking sheldon plugins..."
	sheldon lock

sheldon-source:
	@echo "Sourcing sheldon plugins..."
	sheldon source

# ============================================================
# Debug / Info
# ============================================================

info:
	@echo "System: $(UNAME) ($(ARCH))"
	@echo "Home Manager config: $(HM_CONFIG)"
ifeq ($(UNAME),Darwin)
	@echo "nix-darwin config: $(DARWIN_CONFIG)"
endif
	@echo ""
	@echo "Nix version:"
	@nix --version
	@echo ""
	@echo "Flake inputs:"
	@nix flake metadata --json | jq -r '.locks.nodes | to_entries[] | select(.value.locked) | "\(.key): \(.value.locked.rev // "N/A")"'

repl:
	nix repl .
