# ============================================================
# Dotfiles Makefile
# ============================================================

# ユーザー名 (現在のログインユーザーを自動検出)
USER := $(shell whoami)

# ユーザー名を正規化 (ドットをアンダースコアに置換、darwin設定名用)
SAFE_USER := $(subst .,_,$(USER))

# システム検出
UNAME := $(shell uname)
ARCH := $(shell uname -m)
# darwin-rebuild は LocalHostName を使用するため、同じ順序で取得
HOST_RAW ?= $(shell if [ "$(UNAME)" = "Darwin" ]; then \
  _hn=$$(scutil --get LocalHostName 2>/dev/null); \
  if [ -n "$$_hn" ]; then \
    echo "$$_hn"; \
  else \
    _hn=$$(scutil --get HostName 2>/dev/null); \
    if [ -n "$$_hn" ]; then echo "$$_hn"; else hostname -s; fi; \
  fi; \
else \
  hostname -s; \
fi)
HOST ?= $(subst .,_,$(subst -,_,$(HOST_RAW)))
# ホストファイルは正規化前の名前で検索（darwin-rebuild と一致させるため）
HOST_FILE := $(CURDIR)/hosts/$(HOST_RAW).nix
HOST_CONFIG_FOUND := $(wildcard $(HOST_FILE))

ifneq ($(HOST_CONFIG_FOUND),)
  HM_CONFIG := $(HOST_RAW)
  ifeq ($(UNAME),Darwin)
    # darwin-rebuild は正規化前の名前で設定を検索
    DARWIN_CONFIG := $(HOST_RAW)
  endif
else
  ifeq ($(UNAME),Darwin)
    ifeq ($(ARCH),arm64)
      HM_CONFIG := $(USER)@darwin-aarch64
      DARWIN_CONFIG := $(SAFE_USER)-darwin
    else
      HM_CONFIG := $(USER)@darwin-x86_64
      DARWIN_CONFIG := $(SAFE_USER)-darwin-x86
    endif
  else
    ifeq ($(ARCH),x86_64)
      HM_CONFIG := $(USER)@linux-x86_64
    else
      HM_CONFIG := $(USER)@linux-aarch64
    endif
  endif
endif

# Nix experimental features (flakes + nix-command)
NIX_EXPERIMENTAL_FEATURES ?= nix-command flakes
NIX_CONFIG ?= experimental-features = $(NIX_EXPERIMENTAL_FEATURES)
export NIX_CONFIG

# プロンプト切替 (p10k / pure / starship)
PROMPT_PROFILE ?=
ifneq ($(strip $(PROMPT_PROFILE)),)
  PROMPT_PROFILE_ENV = PROMPT_PROFILE=$(PROMPT_PROFILE)
  PROMPT_PROFILE_IMPURE = --impure
  DARWIN_REBUILD_ENV = env PROMPT_PROFILE=$(PROMPT_PROFILE)
else
  PROMPT_PROFILE_ENV =
  PROMPT_PROFILE_IMPURE =
  DARWIN_REBUILD_ENV =
endif

# CLIProxyAPI
CLIPROXYAPI_CONFIG ?= $(HOME)/.config/cliproxyapi/config.yaml
CLIPROXYAPI_LOG ?= $(HOME)/.local/state/cliproxyapi.log
CLIPROXYAPI_PID ?= $(HOME)/.local/state/cliproxyapi.pid
CLIPROXYAPI_HOST ?= 127.0.0.1
CLIPROXYAPI_PORT ?= 8317
CLIPROXYAPI_API_KEY ?=

.PHONY: help check check-update build build-hm build-darwin apply apply-hm apply-darwin \
        rollback rollback-hm rollback-darwin clean nvim-clean zsh-clean update fmt sheldon-lock gc test nvim-test \
        secrets secrets-diff secrets-apply plan plan-darwin plan-hm host-info check-host \
        cliproxyapi-start cliproxyapi-stop cliproxyapi-restart cliproxyapi-status cliproxyapi-test \
        cliproxyapi-login-gemini cliproxyapi-login-codex cliproxyapi-login-claude

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
	@echo "                 Requires host config file or FORCE=1"
	@echo "  apply-hm       Apply Home Manager configuration"
	@echo "  apply-darwin   Apply nix-darwin configuration (macOS only)"
	@echo "  rollback       Rollback to previous generation"
	@echo ""
	@echo "Other targets:"
	@echo "  check          Run nix flake check"
	@echo "  check-update   Check package-level updates (no lockfile change)"
	@echo "  host-info      Show detected host/config info only"
	@echo "  check-host     Fail if host config file is missing"
	@echo "  test           Alias for check"
	@echo "  nvim-test      Run Neovim config tests"
	@echo "  update         Update flake inputs"
	@echo "  fmt            Format nix files"
	@echo "  clean          Remove build artifacts"
	@echo "  nvim-clean     Remove Neovim cache (share/state/cache)"
	@echo "  zsh-clean      Remove zsh cache (sheldon, starship, etc)"
	@echo "  gc             Run nix garbage collection"
	@echo "  sheldon-lock   Lock sheldon plugins"
	@echo ""
	@echo "CLIProxyAPI:"
	@echo "  cliproxyapi-start         Start CLIProxyAPI in background"
	@echo "  cliproxyapi-stop          Stop CLIProxyAPI background process"
	@echo "  cliproxyapi-restart       Restart CLIProxyAPI background process"
	@echo "  cliproxyapi-status        Show process and endpoint status"
	@echo "  cliproxyapi-test          Test /v1/models with CLIPROXYAPI_API_KEY"
	@echo "  cliproxyapi-login-gemini  OAuth login for Gemini"
	@echo "  cliproxyapi-login-codex   OAuth login for Codex"
	@echo "  cliproxyapi-login-claude  OAuth login for Claude"
	@echo ""
	@echo "Secrets (chezmoi + 1Password):"
	@echo "  secrets-init   Initialize chezmoi"
	@echo "  secrets-diff   Show diff before applying"
	@echo "  secrets-apply  Apply secrets from 1Password"
	@echo "  secrets        Alias for secrets-apply"
	@echo ""
	@echo "Detected configuration:"
	@echo "  System: $(UNAME) ($(ARCH))"
	@echo "  Host: $(HOST)"
	@echo "  Host file: $(if $(HOST_CONFIG_FOUND),$(HOST_FILE),not found)"
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
		nix build --reference-lock-file $$tmp '.#darwinConfigurations."$(DARWIN_CONFIG)".system' --show-trace --out-link $$outdir/result >/dev/null; \
		if command -v nvd >/dev/null; then \
			nvd diff /run/current-system $$outdir/result; \
		else \
			nix store diff-closures /run/current-system $$outdir/result; \
		fi; \
	else \
		echo "Building Home Manager with updated inputs: $(HM_CONFIG)"; \
		nix build --reference-lock-file $$tmp '.#homeConfigurations."$(HM_CONFIG)".activationPackage' --show-trace --out-link $$outdir/result >/dev/null; \
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

host-info:
	@echo "UNAME: $(UNAME)"
	@echo "ARCH: $(ARCH)"
	@echo "HOST_RAW: $(HOST_RAW)"
	@echo "HOST: $(HOST)"
	@echo "HOST_FILE: $(HOST_FILE)"
	@if [ -n "$(HOST_CONFIG_FOUND)" ]; then \
		echo "HOST_CONFIG_FOUND: yes"; \
	else \
		echo "HOST_CONFIG_FOUND: no"; \
	fi
	@echo "HM_CONFIG: $(HM_CONFIG)"
	@echo "DARWIN_CONFIG: $(DARWIN_CONFIG)"

check-host:
	@echo "Checking host configuration: $(HOST)"
	@if [ -n "$(HOST_CONFIG_FOUND)" ]; then \
		echo "OK: $(HOST_FILE)"; \
	else \
		echo "NG: $(HOST_FILE)"; \
		exit 1; \
	fi

build-hm:
	@echo "Building Home Manager configuration: $(HM_CONFIG)"
	nix build '.#homeConfigurations."$(HM_CONFIG)".activationPackage' --show-trace

build-darwin:
ifeq ($(UNAME),Darwin)
	@echo "Building nix-darwin configuration: $(DARWIN_CONFIG)"
	nix build '.#darwinConfigurations."$(DARWIN_CONFIG)".system' --show-trace
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
	@nix build '.#darwinConfigurations."$(DARWIN_CONFIG)".system' --show-trace
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
	@nix build '.#homeConfigurations."$(HM_CONFIG)".activationPackage' --show-trace
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
ifndef FORCE
ifeq ($(HOST_CONFIG_FOUND),)
	@echo "ERROR: Host configuration file not found: $(HOST_FILE)"
	@echo "This prevents accidental destruction of existing environment."
	@echo ""
	@echo "To create host configuration:"
	@echo "  1. Create $(HOST_FILE)"
	@echo "  2. Configure it for this specific host"
	@echo "  3. Run 'make apply' again"
	@echo ""
	@echo "To force apply with fallback config (DANGEROUS):"
	@echo "  FORCE=1 make apply"
	@exit 1
endif
endif
	@echo "Applying Home Manager configuration: $(HM_CONFIG)"
	$(PROMPT_PROFILE_ENV) home-manager switch --flake '.#"$(HM_CONFIG)"' $(PROMPT_PROFILE_IMPURE)
	@if command -v sheldon >/dev/null 2>&1; then \
		echo "Locking sheldon plugins..."; \
		sheldon lock; \
	fi

apply-darwin:
ifeq ($(UNAME),Darwin)
ifndef FORCE
ifeq ($(HOST_CONFIG_FOUND),)
	@echo "ERROR: Host configuration file not found: $(HOST_FILE)"
	@echo "This prevents accidental destruction of existing environment."
	@echo ""
	@echo "To create host configuration:"
	@echo "  1. Create $(HOST_FILE)"
	@echo "  2. Configure it for this specific host"
	@echo "  3. Run 'make apply' again"
	@echo ""
	@echo "To force apply with fallback config (DANGEROUS):"
	@echo "  FORCE=1 make apply"
	@exit 1
endif
endif
	@echo "Applying nix-darwin configuration: $(DARWIN_CONFIG)"
	sudo $(DARWIN_REBUILD_ENV) darwin-rebuild switch --flake '.#$(DARWIN_CONFIG)' $(PROMPT_PROFILE_IMPURE)
	@if command -v sheldon >/dev/null 2>&1; then \
		echo "Locking sheldon plugins..."; \
		sheldon lock; \
	fi
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
	nix run home-manager/master -- switch --flake '.#"$(HM_CONFIG)"'
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
	@if command -v rg >/dev/null 2>&1; then \
		rg --files -g '*.nix' -0 | xargs -0 nix run nixpkgs#nixfmt --; \
	else \
		find . -name "*.nix" -print0 | xargs -0 nix run nixpkgs#nixfmt --; \
	fi

clean:
	@echo "Cleaning build artifacts..."
	rm -rf result
	rm -rf .direnv

nvim-clean:
	@echo "Cleaning Neovim caches (share/state/cache)..."
	rm -rf ~/.local/share/nvim
	rm -rf ~/.local/state/nvim
	rm -rf ~/.cache/nvim

zsh-clean:
	@echo "Cleaning zsh caches (sheldon, starship, zoxide, compinit)..."
	rm -rf ~/.cache/zsh
	rm -fr ~/.cache/p10k-instant-prompt-*.zsh

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
# CLIProxyAPI
# ============================================================

cliproxyapi-start:
	@echo "Starting CLIProxyAPI..."
	@mkdir -p "$$(dirname "$(CLIPROXYAPI_LOG)")" "$$(dirname "$(CLIPROXYAPI_PID)")"
	@if [ ! -f "$(CLIPROXYAPI_CONFIG)" ]; then \
		echo "Config not found: $(CLIPROXYAPI_CONFIG)"; \
		echo "Run 'make apply' first."; \
		exit 1; \
	fi
	@code=$$(curl -s -o /dev/null -w "%{http_code}" "http://$(CLIPROXYAPI_HOST):$(CLIPROXYAPI_PORT)/" || true); \
	if [ "$$code" != "000" ]; then \
		echo "CLIProxyAPI endpoint already reachable (status=$$code)."; \
		echo "Skip start."; \
		exit 0; \
	fi; \
	if [ -f "$(CLIPROXYAPI_PID)" ] && kill -0 "$$(cat "$(CLIPROXYAPI_PID)")" 2>/dev/null; then \
		echo "CLIProxyAPI already running (pid=$$(cat "$(CLIPROXYAPI_PID)"))"; \
		exit 0; \
	fi
	@nohup cliproxyapi -config "$(CLIPROXYAPI_CONFIG)" >"$(CLIPROXYAPI_LOG)" 2>&1 & echo $$! >"$(CLIPROXYAPI_PID)"
	@sleep 1
	@if kill -0 "$$(cat "$(CLIPROXYAPI_PID)")" 2>/dev/null; then \
		echo "CLIProxyAPI started (pid=$$(cat "$(CLIPROXYAPI_PID)"))"; \
		echo "Log: $(CLIPROXYAPI_LOG)"; \
	else \
		echo "Failed to start CLIProxyAPI. Recent log:"; \
		tail -n 50 "$(CLIPROXYAPI_LOG)" || true; \
		exit 1; \
	fi

cliproxyapi-stop:
	@echo "Stopping CLIProxyAPI..."
	@if [ -f "$(CLIPROXYAPI_PID)" ]; then \
		pid="$$(cat "$(CLIPROXYAPI_PID)")"; \
		if kill -0 "$$pid" 2>/dev/null; then \
			kill "$$pid"; \
			sleep 1; \
			if kill -0 "$$pid" 2>/dev/null; then \
				echo "Process still alive, sending SIGKILL..."; \
				kill -9 "$$pid" 2>/dev/null || true; \
			fi; \
			echo "CLIProxyAPI stopped."; \
		else \
			echo "CLIProxyAPI process already gone."; \
		fi; \
		rm -f "$(CLIPROXYAPI_PID)"; \
	else \
		code=$$(curl -s -o /dev/null -w "%{http_code}" "http://$(CLIPROXYAPI_HOST):$(CLIPROXYAPI_PORT)/" || true); \
		if [ "$$code" != "000" ]; then \
			echo "Endpoint is reachable (status=$$code), but no pid file found."; \
			echo "Stop it manually if this is an externally started process."; \
		else \
			echo "CLIProxyAPI is not running."; \
		fi; \
	fi

cliproxyapi-restart: cliproxyapi-stop cliproxyapi-start

cliproxyapi-status:
	@echo "CLIProxyAPI config: $(CLIPROXYAPI_CONFIG)"
	@if [ -f "$(CLIPROXYAPI_PID)" ] && kill -0 "$$(cat "$(CLIPROXYAPI_PID)")" 2>/dev/null; then \
		echo "Process: running (pid=$$(cat "$(CLIPROXYAPI_PID)"))"; \
	else \
		echo "Process: stopped"; \
	fi
	@code=$$(curl -s -o /dev/null -w "%{http_code}" "http://$(CLIPROXYAPI_HOST):$(CLIPROXYAPI_PORT)/" || true); \
	echo "Endpoint: http://$(CLIPROXYAPI_HOST):$(CLIPROXYAPI_PORT)/ (status=$$code)"

cliproxyapi-test:
	@if [ -z "$(CLIPROXYAPI_API_KEY)" ]; then \
		echo "Set CLIPROXYAPI_API_KEY to test API auth."; \
		echo "Example: CLIPROXYAPI_API_KEY=xxxx make cliproxyapi-test"; \
		exit 1; \
	fi
	@code=$$(curl -s -o /dev/null -w "%{http_code}" \
		-H "Authorization: Bearer $(CLIPROXYAPI_API_KEY)" \
		"http://$(CLIPROXYAPI_HOST):$(CLIPROXYAPI_PORT)/v1/models" || true); \
	echo "GET /v1/models => $$code"

cliproxyapi-login-gemini:
	cliproxyapi -login -config "$(CLIPROXYAPI_CONFIG)"

cliproxyapi-login-codex:
	cliproxyapi -codex-login -config "$(CLIPROXYAPI_CONFIG)"

cliproxyapi-login-claude:
	cliproxyapi -claude-login -config "$(CLIPROXYAPI_CONFIG)"

# ============================================================
# Debug / Info
# ============================================================

info:
	@echo "System: $(UNAME) ($(ARCH))"
	@echo "Host: $(HOST)"
	@echo "Host file: $(if $(HOST_CONFIG_FOUND),$(HOST_FILE),not found)"
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
