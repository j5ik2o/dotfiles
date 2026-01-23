# ============================================================
# Dotfiles Makefile
# ============================================================

# ユーザー名 (現在のログインユーザーを自動検出)
USER := $(shell whoami)

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

# Nix experimental features (flakes + nix-command)
NIX_EXPERIMENTAL_FEATURES ?= nix-command flakes
NIX_CONFIG ?= experimental-features = $(NIX_EXPERIMENTAL_FEATURES)
export NIX_CONFIG

.PHONY: help check check-update build build-hm build-darwin apply apply-hm apply-darwin \
        rollback rollback-hm rollback-darwin clean nvim-clean update fmt sheldon-lock gc test nvim-test \
        secrets secrets-diff secrets-apply plan plan-darwin plan-hm

# デフォルトターゲット
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Build targets:"
	@echo "  build          Build all (darwin on macOS, hm on Linux)"
	@echo "  build-hm       Build Home Manager configuration"
	@echo "  build-darwin   Build nix-darwin configuration (macOS only)"
	@echo "  plan           Build and show diff (like terraform plan)"
	@echo ""
	@echo "Apply targets:"
	@echo "  apply          Apply all (darwin on macOS, hm on Linux)"
	@echo "  apply-hm       Apply Home Manager configuration"
	@echo "  apply-darwin   Apply nix-darwin configuration (macOS only)"
	@echo "  rollback       Rollback to previous generation"
	@echo ""
	@echo "Other targets:"
	@echo "  check          Run nix flake check"
	@echo "  check-update   Check package-level updates (no lockfile change)"
	@echo "  test           Alias for check"
	@echo "  nvim-test      Run Neovim config tests"
	@echo "  update         Update flake inputs"
	@echo "  fmt            Format nix files"
	@echo "  clean          Remove build artifacts"
	@echo "  nvim-clean     Remove Neovim cache (share/state/cache)"
	@echo "  gc             Run nix garbage collection"
	@echo "  sheldon-lock   Lock sheldon plugins"
	@echo ""
	@echo "Secrets (chezmoi + 1Password):"
	@echo "  secrets-init   Initialize chezmoi"
	@echo "  secrets-diff   Show diff before applying"
	@echo "  secrets-apply  Apply secrets from 1Password"
	@echo "  secrets        Alias for secrets-apply"
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

check-update:
	@tmpdir="$(CURDIR)/.tmp"; \
	mkdir -p $$tmpdir; \
	tmp=$$(mktemp -p $$tmpdir flake.lock.XXXXXX); \
	outdir=$$(mktemp -d -p $$tmpdir nix-check-update.XXXXXX); \
	nix flake update --output-lock-file $$tmp >/dev/null; \
	if diff -q flake.lock $$tmp >/dev/null; then \
		echo "No input updates."; \
		rm -f $$tmp; rm -rf $$outdir; \
		exit 0; \
	fi; \
	if [ "$(UNAME)" = "Darwin" ]; then \
		echo "Building nix-darwin with updated inputs: $(DARWIN_CONFIG)"; \
		nix build --reference-lock-file $$tmp .#darwinConfigurations.$(DARWIN_CONFIG).system --show-trace --out-link $$outdir/result >/dev/null; \
		if command -v nvd >/dev/null; then \
			nvd diff /run/current-system $$outdir/result; \
		else \
			nix store diff-closures /run/current-system $$outdir/result; \
		fi; \
	else \
		echo "Building Home Manager with updated inputs: $(HM_CONFIG)"; \
		nix build --reference-lock-file $$tmp .#homeConfigurations.$(HM_CONFIG).activationPackage --show-trace --out-link $$outdir/result >/dev/null; \
		profile="$$HOME/.local/state/nix/profiles/home-manager"; \
		if [ -e $$profile ]; then \
			if command -v nvd >/dev/null; then \
				nvd diff $$profile $$outdir/result; \
			else \
				nix store diff-closures $$profile $$outdir/result; \
			fi; \
		else \
			echo "Home Manager profile not found: $$profile"; \
			echo "Build result: $$outdir/result"; \
		fi; \
	fi; \
	rm -f $$tmp; rm -rf $$outdir

test: check

# ============================================================
# Neovim config tests
# ============================================================

nvim-test:
	@echo "Running Neovim config tests..."
	@tmp="$(CURDIR)/.tmp/nvim-test"; \
	mkdir -p "$$tmp/config" "$$tmp/data" "$$tmp/state" "$$tmp/cache"; \
	XDG_CONFIG_HOME="$$tmp/config" \
	XDG_DATA_HOME="$$tmp/data" \
	XDG_STATE_HOME="$$tmp/state" \
	XDG_CACHE_HOME="$$tmp/cache" \
	NVIM_TEST_ROOT="$(CURDIR)" \
	nvim --headless -u "$(CURDIR)/config/nvim/tests/minimal_init.lua" \
	-c "lua dofile(os.getenv('NVIM_TEST_ROOT') .. '/config/nvim/tests/run.lua')"

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
# Plan (dry-run with diff)
# ============================================================

plan-darwin:
ifeq ($(UNAME),Darwin)
	@echo "Planning nix-darwin configuration: $(DARWIN_CONFIG)"
	@nix build .#darwinConfigurations.$(DARWIN_CONFIG).system --show-trace
	@if command -v nvd &> /dev/null; then \
		nvd diff /run/current-system ./result; \
	else \
		echo "Install 'nvd' for detailed diff: nix profile install nixpkgs#nvd"; \
		echo "Build successful. Run 'make apply' to apply."; \
	fi
else
	@echo "nix-darwin is only available on macOS"
	@exit 1
endif

plan-hm:
	@echo "Planning Home Manager configuration: $(HM_CONFIG)"
	@nix build .#homeConfigurations.$(HM_CONFIG).activationPackage --show-trace
	@echo "Build successful. Run 'make apply' to apply."

plan:
ifeq ($(UNAME),Darwin)
	$(MAKE) plan-darwin
else
	$(MAKE) plan-hm
endif

# ============================================================
# Apply
# ============================================================

apply-hm:
	@echo "Applying Home Manager configuration: $(HM_CONFIG)"
	home-manager switch --flake .#$(HM_CONFIG)

apply-darwin:
ifeq ($(UNAME),Darwin)
	@echo "Applying nix-darwin configuration: $(DARWIN_CONFIG)"
	sudo darwin-rebuild switch --flake .#$(DARWIN_CONFIG)
else
	@echo "nix-darwin is only available on macOS"
	@exit 1
endif

apply:
ifeq ($(UNAME),Darwin)
	$(MAKE) apply-darwin
else
	$(MAKE) apply-hm
endif

# ============================================================
# Rollback
# ============================================================

rollback-hm:
	@echo "Rolling back Home Manager to previous generation..."
	home-manager switch --rollback

rollback-darwin:
ifeq ($(UNAME),Darwin)
	@echo "Rolling back nix-darwin to previous generation..."
	sudo darwin-rebuild switch --rollback
else
	@echo "nix-darwin is only available on macOS"
	@exit 1
endif

rollback:
ifeq ($(UNAME),Darwin)
	$(MAKE) rollback-darwin
else
	$(MAKE) rollback-hm
endif

init-darwin:
ifeq ($(UNAME),Darwin)
	@echo "Preparing for first nix-darwin installation..."
	@# バックアップが存在しない場合のみ退避（再実行時に上書きしない）
	@[ -f /etc/nix/nix.conf.before-nix-darwin ] || sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin 2>/dev/null || true
	@[ -f /etc/bashrc.before-nix-darwin ] || sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin 2>/dev/null || true
	@[ -f /etc/zshrc.before-nix-darwin ] || sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin 2>/dev/null || true
	@echo "Running initial nix-darwin switch..."
	sudo -E nix run nix-darwin#darwin-rebuild -- switch --flake .#$(DARWIN_CONFIG)
else
	@echo "nix-darwin is only available on macOS"
	@exit 1
endif

init-linux:
ifeq ($(UNAME),Linux)
	@echo "Preparing for first home-manager installation on Linux..."
	@echo "Running initial home-manager switch..."
	nix run home-manager/master -- switch --flake .#$(HM_CONFIG)
else
	@echo "init-linux is only available on Linux"
	@exit 1
endif

init:
ifeq ($(UNAME),Darwin)
	$(MAKE) init-darwin
else
	$(MAKE) init-linux
endif

# ============================================================
# Maintenance
# ============================================================

update:
	@echo "Updating flake inputs..."
	nix flake update

fmt:
	@echo "Formatting nix files..."
	find . -name "*.nix" -exec nixfmt {} \; 2>/dev/null

clean:
	@echo "Cleaning build artifacts..."
	rm -rf result
	rm -rf .direnv

nvim-clean:
	@echo "Cleaning all Neovim caches (nvim-*)..."
	rm -rf ~/.local/share/nvim*
	rm -rf ~/.local/state/nvim*
	rm -rf ~/.cache/nvim*

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
# Chezmoi (シークレット管理)
# ============================================================

secrets-init:
	@if [ ! -d ~/.local/share/chezmoi ]; then \
		echo "Initializing chezmoi with local source..."; \
		chezmoi init --source=$(CURDIR)/chezmoi; \
	fi

secrets-diff: secrets-init
	@echo "Showing differences..."
	chezmoi diff --source=$(CURDIR)/chezmoi

secrets-apply: secrets-init
	@echo "Applying secrets from 1Password..."
	chezmoi apply --source=$(CURDIR)/chezmoi

secrets: secrets-apply

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
