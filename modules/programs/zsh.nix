{
  config,
  pkgs,
  lib,
  ...
}:

let
  promptProfileEnv = builtins.getEnv "PROMPT_PROFILE";
  promptProfileRaw = lib.toLower (if promptProfileEnv == "" then "starship" else promptProfileEnv);
  promptProfile =
    if
      builtins.elem promptProfileRaw [
        "p10k"
        "pure"
        "starship"
      ]
    then
      promptProfileRaw
    else
      "p10k";
  misePkgConfigPath = lib.concatStringsSep ":" [
    "${pkgs.libyaml.dev}/lib/pkgconfig"
    "${pkgs.openssl.dev}/lib/pkgconfig"
    "${pkgs.zlib.dev}/lib/pkgconfig"
    "${pkgs.libffi.dev}/lib/pkgconfig"
  ];
  miseRubyConfigureOpts = lib.concatStringsSep " " [
    "--with-libyaml-include=${pkgs.libyaml.dev}/include"
    "--with-libyaml-lib=${pkgs.libyaml}/lib"
    "--with-openssl-include=${pkgs.openssl.dev}/include"
    "--with-openssl-lib=${pkgs.openssl.out}/lib"
    "--with-zlib-include=${pkgs.zlib.dev}/include"
    "--with-zlib-lib=${pkgs.zlib}/lib"
    "--with-libffi-include=${pkgs.libffi.dev}/include"
    "--with-libffi-lib=${pkgs.libffi}/lib"
  ];
  miseToolchain = {
    cc = "${pkgs.stdenv.cc}/bin/cc";
    cxx = "${pkgs.stdenv.cc}/bin/c++";
    ar = "${pkgs.stdenv.cc.bintools}/bin/ar";
    ranlib = "${pkgs.stdenv.cc.bintools}/bin/ranlib";
    nm = "${pkgs.stdenv.cc.bintools}/bin/nm";
    strip = "${pkgs.stdenv.cc.bintools}/bin/strip";
    pkgConfig = "${pkgs."pkg-config"}/bin/pkg-config";
  };
in
{
  # ============================================================
  # mise (言語ランタイム管理)
  # ============================================================
  xdg.configFile."mise/config.toml" = {
    # 既存ファイルがあっても Home Manager の定義を優先する
    force = true;
    text = ''
      [settings]
      github.github_attestations = false

      [tools]
      java = "temurin-21"
      node = "22"
      python = "3.13.11"
      ruby = "3.3"
      claude = "2.1.47"
      codex = "0.104.0"
      "npm:takt" = "0.19.0"
    '';
  };

  # make apply 後に自動で不足ランタイムを導入
  home.activation.miseAutoInstall = lib.hm.dag.entryAfter [ "installPackages" ] ''
    _mise_path="${config.home.profileDirectory}/bin:/usr/bin:/bin"
    _mise_pkg_config_path="${misePkgConfigPath}"
    _mise_ruby_configure_opts="${miseRubyConfigureOpts}"
    _mise_cc="${miseToolchain.cc}"
    _mise_cxx="${miseToolchain.cxx}"
    _mise_ar="${miseToolchain.ar}"
    _mise_ranlib="${miseToolchain.ranlib}"
    _mise_nm="${miseToolchain.nm}"
    _mise_strip="${miseToolchain.strip}"
    _mise_pkg_config="${miseToolchain.pkgConfig}"
    if [ -x "${pkgs.mise}/bin/mise" ]; then
      if env PATH="$_mise_path:$PATH" "${pkgs.mise}/bin/mise" ls --global --missing --no-header 2>/dev/null | grep -q '.'; then
        echo "home-manager: mise install (missing tools)" >&2
        if ! env PATH="$_mise_path:$PATH" \
          CC="$_mise_cc" CXX="$_mise_cxx" AR="$_mise_ar" RANLIB="$_mise_ranlib" NM="$_mise_nm" STRIP="$_mise_strip" \
          PKG_CONFIG="$_mise_pkg_config" PKG_CONFIG_PATH="$_mise_pkg_config_path" \
          RUBY_CONFIGURE_OPTS="$_mise_ruby_configure_opts" \
          "${pkgs.mise}/bin/mise" install --yes; then
          echo "home-manager: mise install failed. Run 'mise install' manually." >&2
        fi
      fi
    fi
    unset _mise_path _mise_pkg_config_path _mise_ruby_configure_opts
    unset _mise_cc _mise_cxx _mise_ar _mise_ranlib _mise_nm _mise_strip _mise_pkg_config
  '';

  # make apply 後に claude/codex は最新 + ひとつ前のみ残す
  home.activation.miseTrimOldToolVersions = lib.hm.dag.entryAfter [ "miseAutoInstall" ] ''
    _mise_path="${config.home.profileDirectory}/bin:/usr/bin:/bin"
    _mise_sort="${pkgs.coreutils}/bin/sort"
    _mise_awk="${pkgs.gawk}/bin/awk"
    if [ -x "${pkgs.mise}/bin/mise" ]; then
      for _mise_tool in claude codex; do
        _mise_versions="$(
          env PATH="$_mise_path:$PATH" "${pkgs.mise}/bin/mise" ls "$_mise_tool" --installed --no-header 2>/dev/null \
            | "$_mise_awk" '{ print $2 }' \
            | "$_mise_sort" -u -V
        )"
        _mise_remove="$(
          printf '%s\n' "$_mise_versions" \
            | "$_mise_awk" 'NF { versions[++count] = $0 } END { limit = count - 2; for (i = 1; i <= limit; i++) print versions[i] }'
        )"
        if [ -n "$_mise_remove" ]; then
          echo "home-manager: removing old mise versions for $_mise_tool" >&2
          while IFS= read -r _mise_version; do
            [ -n "$_mise_version" ] || continue
            if ! env PATH="$_mise_path:$PATH" "${pkgs.mise}/bin/mise" uninstall --yes "''${_mise_tool}@''${_mise_version}" >/dev/null 2>&1; then
              echo "home-manager: failed to remove $_mise_tool@$_mise_version" >&2
            fi
          done <<EOF
$_mise_remove
EOF
        fi
      done
    fi
    unset _mise_path _mise_sort _mise_awk _mise_tool _mise_versions _mise_remove _mise_version
  '';

  home.file.".local/bin/mise" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      export CC="${miseToolchain.cc}"
      export CXX="${miseToolchain.cxx}"
      export AR="${miseToolchain.ar}"
      export RANLIB="${miseToolchain.ranlib}"
      export NM="${miseToolchain.nm}"
      export STRIP="${miseToolchain.strip}"
      export PKG_CONFIG="${miseToolchain.pkgConfig}"

      _mise_pkg_config_path="${misePkgConfigPath}"
      if [ -n "''${PKG_CONFIG_PATH:-}" ]; then
        export PKG_CONFIG_PATH="$_mise_pkg_config_path:$PKG_CONFIG_PATH"
      else
        export PKG_CONFIG_PATH="$_mise_pkg_config_path"
      fi

      _mise_ruby_configure_opts="${miseRubyConfigureOpts}"
      if [ -n "''${RUBY_CONFIGURE_OPTS:-}" ]; then
        export RUBY_CONFIGURE_OPTS="$_mise_ruby_configure_opts $RUBY_CONFIGURE_OPTS"
      else
        export RUBY_CONFIGURE_OPTS="$_mise_ruby_configure_opts"
      fi

      exec "${pkgs.mise}/bin/mise" "$@"
    '';
  };

  # mise 管理ランタイムが参照する /nix/store を GC から保護する
  home.activation.misePinNixLibs = lib.hm.dag.entryAfter [ "miseTrimOldToolVersions" ] ''
    _uname="$(uname -s)"
    if [ "$_uname" != "Linux" ] && [ "$_uname" != "Darwin" ]; then
      # 未対応 OS は何もしない
      _uname=""
    fi
    _nix_store="${pkgs.nix}/bin/nix-store"
    if [ -z "$_uname" ] || [ ! -x "$_nix_store" ]; then
      # nix が無い環境は何もしない
      _uname=""
    fi
    _awk="${pkgs.gawk}/bin/awk"
    _otool="${if pkgs.stdenv.isDarwin then "${pkgs.darwin.cctools}/bin/otool" else "/usr/bin/otool"}"
    _ldd="${if pkgs.stdenv.isLinux then "${pkgs.glibc.bin}/bin/ldd" else "/usr/bin/ldd"}"
    if [ "$_uname" = "Darwin" ] && [ ! -x "$_otool" ]; then
      _otool="/usr/bin/otool"
    fi
    if [ "$_uname" = "Linux" ] && [ ! -x "$_ldd" ]; then
      _ldd="/usr/bin/ldd"
    fi
    _mise_root="''${XDG_DATA_HOME:-$HOME/.local/share}/mise"
    _installs="$_mise_root/installs"
    _gcroot_dir="$_mise_root/gcroots"
    if [ ! -d "$_installs" ]; then
      _uname=""
    fi
    if [ "$_uname" = "Darwin" ] && [ ! -x "$_otool" ]; then
      _uname=""
    fi
    if [ "$_uname" = "Linux" ] && [ ! -x "$_ldd" ]; then
      _uname=""
    fi
    if [ -n "$_uname" ]; then
      mkdir -p "$_gcroot_dir"
      _tmp="$(mktemp)"
      _tmp_bases="$(mktemp)"

      find "$_installs" -type f \( -path "*/bin/*" -o -name "*.so" -o -name "*.so.*" -o -name "*.dylib" -o -name "*.bundle" \) -print0 2>/dev/null \
        | while IFS= read -r -d "" f; do
            if [ "$_uname" = "Linux" ]; then
              "$_ldd" "$f" 2>/dev/null | "$_awk" '
                $1 ~ /^\/nix\/store/ { print $1 }
                $3 ~ /^\/nix\/store/ { print $3 }
              ' || true
            else
              "$_otool" -L "$f" 2>/dev/null | "$_awk" '
                $1 ~ /^\/nix\/store/ { print $1 }
              ' || true
            fi
          done \
        | sort -u > "$_tmp"

      if [ -s "$_tmp" ]; then
        "$_awk" -F/ '{print $NF}' "$_tmp" | sort -u > "$_tmp_bases"

        while IFS= read -r p; do
          [ -n "$p" ] || continue
          root="$_gcroot_dir/$(basename "$p")"
          if [ ! -e "$root" ]; then
            "$_nix_store" --realise --add-root "$root" --indirect "$p" >/dev/null 2>&1 || true
          fi
        done < "$_tmp"

        for root in "$_gcroot_dir"/*; do
          [ -e "$root" ] || continue
          base="$(basename "$root")"
          if ! grep -qx "$base" "$_tmp_bases"; then
            rm -f "$root"
          fi
        done
      fi

      rm -f "$_tmp" "$_tmp_bases"
    fi
  '';

  # ============================================================
  # Sheldon (Zsh プラグインマネージャー)
  # ============================================================
  home.packages = with pkgs; [
    sheldon
  ];

  # Sheldon 設定ファイル
  xdg.configFile."sheldon/plugins.toml".text = ''
    shell = "zsh"

    [plugins]

    # ============================================================
    # Plugin loading template
    # ============================================================
    [templates]
    immediate = "{{ hooks?.pre | nl }}{% for file in files %}source \"{{ file }}\"\n{% endfor %}{{ hooks?.post | nl }}"

    # ============================================================
    # Core plugins
    # ============================================================

    # Powerlevel10k (高速プロンプト)
    [plugins.powerlevel10k]
    github = "romkatv/powerlevel10k"
    use = ["powerlevel10k.zsh-theme"]
    profiles = ["p10k"]

    # Pure (シンプルで非同期なプロンプト)
    [plugins.pure]
    github = "sindresorhus/pure"
    use = ["async.zsh", "pure.zsh"]
    profiles = ["pure"]

    # ============================================================
    # Completions
    # ============================================================

    [plugins.zsh-completions]
    github = "zsh-users/zsh-completions"
    proto = "https"

    [plugins.nix-zsh-completions]
    github = "nix-community/nix-zsh-completions"
    proto = "https"

    # ============================================================
    # Enhancements
    # ============================================================

    [plugins.zsh-autosuggestions]
    github = "zsh-users/zsh-autosuggestions"
    proto = "https"
    apply = ["immediate"]

    [plugins.zsh-syntax-highlighting]
    github = "zsh-users/zsh-syntax-highlighting"
    proto = "https"
    apply = ["immediate"]

    [plugins.zsh-history-substring-search]
    github = "zsh-users/zsh-history-substring-search"
    proto = "https"
    apply = ["immediate"]

    # ============================================================
    # Productivity
    # ============================================================

    [plugins.zsh-autopair]
    github = "hlissner/zsh-autopair"
    proto = "https"
    apply = ["immediate"]

    [plugins.zsh-you-should-use]
    github = "MichaelAquilina/zsh-you-should-use"
    proto = "https"
    apply = ["immediate"]

    # fzf-tab (複数候補時の補完UI)
    [plugins.fzf-tab]
    github = "Aloxaf/fzf-tab"
    proto = "https"
    apply = ["immediate"]

    # fzf shell integration
    # Tab 補完の安定性を優先し、fzf 側の ^I 上書きは行わない。
    [plugins.fzf]
    inline = """
    :
    """

    # ============================================================
    # Git enhancements
    # ============================================================

    [plugins.forgit]
    github = "wfxr/forgit"
    proto = "https"
    apply = ["immediate"]

    # ============================================================
    # Directory navigation
    # ============================================================

    [plugins.enhancd]
    github = "b4b4r07/enhancd"
    proto = "https"
    apply = ["immediate"]

    # ============================================================
    # Oh My Zsh plugins (個別インポート)
    # ============================================================

    [plugins.ohmyzsh-lib]
    github = "ohmyzsh/ohmyzsh"
    proto = "https"
    dir = "lib"
    use = ["clipboard.zsh", "completion.zsh", "directories.zsh", "git.zsh", "key-bindings.zsh"]

    [plugins.ohmyzsh-plugins]
    github = "ohmyzsh/ohmyzsh"
    proto = "https"
    dir = "plugins"
    use = ["{extract,sudo,docker,docker-compose,kubectl}/*.plugin.zsh"]
    apply = ["immediate"]

    # ============================================================
    # CLI Tool Completions
    # ============================================================

    # gh (GitHub CLI) 補完 (キャッシュ + 先行読み込み)
    [plugins.gh-completion]
    inline = """
    _gh_completion_defer() {
      _gh_cache="$HOME/.cache/zsh/gh_completion.zsh"
      if [[ ! -f "$_gh_cache" ]] || [[ $(command -v gh) -nt "$_gh_cache" ]]; then
        mkdir -p "$HOME/.cache/zsh"
        gh completion -s zsh > "$_gh_cache" 2>/dev/null
      fi
      [[ -f "$_gh_cache" ]] && source "$_gh_cache"
    }
    _gh_completion_defer
    """

    # AWS CLI 補完 (先行読み込み)
    [plugins.aws-completion]
    inline = """
    _aws_completion_defer() {
      if command -v aws_completer &> /dev/null; then
        autoload -Uz bashcompinit && bashcompinit
        complete -C aws_completer aws
      fi
    }
    _aws_completion_defer
    """

    # Google Cloud SDK 補完 (先行読み込み)
    [plugins.gcloud-completion]
    inline = """
    _gcloud_completion_defer() {
      if [[ -n "$CLOUDSDK_ROOT_DIR" ]]; then
        source "$CLOUDSDK_ROOT_DIR/completion.zsh.inc" 2>/dev/null
      elif [[ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]]; then
        source "$HOME/google-cloud-sdk/completion.zsh.inc"
      fi
    }
    _gcloud_completion_defer
    """

    # Docker 補完 (キャッシュ + 先行読み込み)
    [plugins.docker-completion]
    inline = """
    _docker_completion_defer() {
      if command -v docker &> /dev/null; then
        _docker_cache="$HOME/.cache/zsh/docker_completion.zsh"
        if [[ ! -f "$_docker_cache" ]] || [[ $(command -v docker) -nt "$_docker_cache" ]]; then
          mkdir -p "$HOME/.cache/zsh"
          docker completion zsh > "$_docker_cache" 2>/dev/null
        fi
        [[ -f "$_docker_cache" ]] && source "$_docker_cache"
      fi
    }
    _docker_completion_defer
    """

    # jj (Jujutsu) 補完 (キャッシュ + 先行読み込み)
    [plugins.jj-completion]
    inline = """
    _jj_completion_defer() {
      if command -v jj &> /dev/null; then
        _jj_cache="$HOME/.cache/zsh/jj_completion.zsh"
        if [[ ! -f "$_jj_cache" ]] || [[ $(command -v jj) -nt "$_jj_cache" ]]; then
          mkdir -p "$HOME/.cache/zsh"
          jj util completion zsh > "$_jj_cache" 2>/dev/null
        fi
        [[ -f "$_jj_cache" ]] && source "$_jj_cache"
      fi
    }
    _jj_completion_defer
    """

    # mise 補完 (キャッシュ + 先行読み込み)
    [plugins.mise-completion]
    inline = """
    _mise_completion_defer() {
      if command -v mise &> /dev/null; then
        _mise_cache="$HOME/.cache/zsh/mise_completion.zsh"
        if [[ ! -f "$_mise_cache" ]] || [[ $(command -v mise) -nt "$_mise_cache" ]]; then
          mkdir -p "$HOME/.cache/zsh"
          mise completion zsh > "$_mise_cache" 2>/dev/null
        fi
        [[ -f "$_mise_cache" ]] && source "$_mise_cache"
      fi
    }
    _mise_completion_defer
    """

    # rustup 補完 (キャッシュ + 先行読み込み)
    [plugins.rustup-completion]
    inline = """
    _rustup_completion_defer() {
      if command -v rustup &> /dev/null; then
        _rustup_cache="$HOME/.cache/zsh/rustup_completion.zsh"
        if [[ ! -f "$_rustup_cache" ]] || [[ $(command -v rustup) -nt "$_rustup_cache" ]]; then
          mkdir -p "$HOME/.cache/zsh"
          rustup completions zsh > "$_rustup_cache" 2>/dev/null
        fi
        [[ -f "$_rustup_cache" ]] && source "$_rustup_cache"
      fi
    }
    _rustup_completion_defer
    """

    # chezmoi 補完 (キャッシュ + 先行読み込み)
    [plugins.chezmoi-completion]
    inline = """
    _chezmoi_completion_defer() {
      if command -v chezmoi &> /dev/null; then
        _chezmoi_cache="$HOME/.cache/zsh/chezmoi_completion.zsh"
        if [[ ! -f "$_chezmoi_cache" ]] || [[ $(command -v chezmoi) -nt "$_chezmoi_cache" ]]; then
          mkdir -p "$HOME/.cache/zsh"
          chezmoi completion zsh > "$_chezmoi_cache" 2>/dev/null
        fi
        [[ -f "$_chezmoi_cache" ]] && source "$_chezmoi_cache"
      fi
    }
    _chezmoi_completion_defer
    """

    # bun 補完 (キャッシュ + 先行読み込み)
    [plugins.bun-completion]
    inline = """
    _bun_completion_defer() {
      if command -v bun &> /dev/null; then
        _bun_cache="$HOME/.cache/zsh/bun_completion.zsh"
        if [[ ! -f "$_bun_cache" ]] || [[ $(command -v bun) -nt "$_bun_cache" ]]; then
          mkdir -p "$HOME/.cache/zsh"
          bun completions > "$_bun_cache" 2>/dev/null
        fi
        [[ -f "$_bun_cache" ]] && source "$_bun_cache"
      fi
    }
    _bun_completion_defer
    """

    # pnpm 補完 (キャッシュ + 先行読み込み)
    [plugins.pnpm-completion]
    inline = """
    _pnpm_completion_defer() {
      if command -v pnpm &> /dev/null; then
        _pnpm_cache="$HOME/.cache/zsh/pnpm_completion.zsh"
        if [[ ! -f "$_pnpm_cache" ]] || [[ $(command -v pnpm) -nt "$_pnpm_cache" ]]; then
          mkdir -p "$HOME/.cache/zsh"
          pnpm completion zsh > "$_pnpm_cache" 2>/dev/null
        fi
        [[ -f "$_pnpm_cache" ]] && source "$_pnpm_cache"
      fi
    }
    _pnpm_completion_defer
    """

    # uv 補完 (キャッシュ + 先行読み込み)
    [plugins.uv-completion]
    inline = """
    _uv_completion_defer() {
      if command -v uv &> /dev/null; then
        _uv_cache="$HOME/.cache/zsh/uv_completion.zsh"
        if [[ ! -f "$_uv_cache" ]] || [[ $(command -v uv) -nt "$_uv_cache" ]]; then
          mkdir -p "$HOME/.cache/zsh"
          uv generate-shell-completion zsh > "$_uv_cache" 2>/dev/null
        fi
        [[ -f "$_uv_cache" ]] && source "$_uv_cache"
      fi
    }
    _uv_completion_defer
    """

    # devbox 補完 (キャッシュ + 先行読み込み)
    [plugins.devbox-completion]
    inline = """
    _devbox_completion_defer() {
      if command -v devbox &> /dev/null; then
        _devbox_cache="$HOME/.cache/zsh/devbox_completion.zsh"
        if [[ ! -f "$_devbox_cache" ]] || [[ $(command -v devbox) -nt "$_devbox_cache" ]]; then
          mkdir -p "$HOME/.cache/zsh"
          devbox completion zsh > "$_devbox_cache" 2>/dev/null
        fi
        [[ -f "$_devbox_cache" ]] && source "$_devbox_cache"
      fi
    }
    _devbox_completion_defer
    """

    # procs 補完 (キャッシュ + 先行読み込み)
    [plugins.procs-completion]
    inline = """
    _procs_completion_defer() {
      if command -v procs &> /dev/null; then
        _procs_cache="$HOME/.cache/zsh/procs_completion.zsh"
        if [[ ! -f "$_procs_cache" ]] || [[ $(command -v procs) -nt "$_procs_cache" ]]; then
          mkdir -p "$HOME/.cache/zsh"
          procs --gen-completion-out zsh > "$_procs_cache" 2>/dev/null
        fi
        [[ -f "$_procs_cache" ]] && source "$_procs_cache"
      fi
    }
    _procs_completion_defer
    """

    # ripgrep 補完 (キャッシュ + 先行読み込み)
    [plugins.rg-completion]
    inline = """
    _rg_completion_defer() {
      if command -v rg &> /dev/null; then
        _rg_cache="$HOME/.cache/zsh/rg_completion.zsh"
        if [[ ! -f "$_rg_cache" ]] || [[ $(command -v rg) -nt "$_rg_cache" ]]; then
          mkdir -p "$HOME/.cache/zsh"
          rg --generate complete-zsh > "$_rg_cache" 2>/dev/null
        fi
        [[ -f "$_rg_cache" ]] && source "$_rg_cache"
      fi
    }
    _rg_completion_defer
    """

    # bat 補完 (キャッシュ + 先行読み込み)
    [plugins.bat-completion]
    inline = """
    # bat の zsh completion 出力は source ではなく autoload 前提。
    # Nix が提供する _bat を利用するため、ここでは何もしない。
    :
    """

    # starship 補完 (キャッシュ + 先行読み込み)
    [plugins.starship-completion]
    inline = """
    _starship_completion_defer() {
      if command -v starship &> /dev/null; then
        _starship_comp_cache="$HOME/.cache/zsh/starship_completion.zsh"
        if [[ ! -f "$_starship_comp_cache" ]] || [[ $(command -v starship) -nt "$_starship_comp_cache" ]]; then
          mkdir -p "$HOME/.cache/zsh"
          starship completions zsh > "$_starship_comp_cache" 2>/dev/null
        fi
        [[ -f "$_starship_comp_cache" ]] && source "$_starship_comp_cache"
      fi
    }
    _starship_completion_defer
    """

    # elan 補完
    # `elan completions zsh` の出力末尾に `_elan "$@"` が含まれ、
    # source 時に補完関数本体が実行されてしまうため無効化する。
    # Nix 提供の `_elan` を利用する。
    [plugins.elan-completion]
    inline = """
    :
    """

    # ============================================================
    # Prompt & Tools (最後に読み込み)
    # ============================================================

    # mise (言語ランタイム管理)
    [plugins.mise]
    inline = """
    _mise_init() {
      if command -v mise &> /dev/null; then
        # mise を有効化（_mise_hook を定義させる）
        eval "$(mise activate zsh)"
        # precmd での hook-env 実行を外し、起動速度を優先
        typeset -ag precmd_functions
        precmd_functions=( ''${precmd_functions:#_mise_hook_precmd} )
        # 初回のコマンド実行直前に一度だけ hook-env を実行
        _mise_preexec_once() {
          if (( $+functions[_mise_hook] )); then
            _mise_hook
          fi
          preexec_functions=( ''${preexec_functions:#_mise_preexec_once} )
          unset -f _mise_preexec_once
        }
        autoload -Uz add-zsh-hook
        add-zsh-hook preexec _mise_preexec_once
      fi
      unset -f _mise_init
    }
    _mise_init
    """

    # direnv (環境自動切り替え)
    [plugins.direnv]
    inline = """
    _direnv_init() {
      if command -v direnv &> /dev/null; then
        _direnv_hook() {
          trap -- "" SIGINT
          eval "$(command direnv export zsh)"
          trap - SIGINT
        }
        typeset -ag precmd_functions
        if (( ! ''${precmd_functions[(I)_direnv_hook]} )); then
          precmd_functions=(_direnv_hook $precmd_functions)
        fi
        typeset -ag chpwd_functions
        if (( ! ''${chpwd_functions[(I)_direnv_hook]} )); then
          chpwd_functions=(_direnv_hook $chpwd_functions)
        fi
      fi
      unset -f _direnv_init
    }
    _direnv_init
    """

    # zoxide (スマート cd) - キャッシュ版
    [plugins.zoxide]
    inline = """
    _zoxide_cache="$HOME/.cache/zsh/zoxide.zsh"
    if [[ ! -f "$_zoxide_cache" ]] || [[ $(command -v zoxide) -nt "$_zoxide_cache" ]]; then
      zoxide init zsh > "$_zoxide_cache"
    fi
    source "$_zoxide_cache"
    """

    # Starship プロンプト (最後に初期化) - キャッシュ版
    [plugins.starship]
    profiles = ["starship"]
    inline = """
    _starship_cache="$HOME/.cache/zsh/starship.zsh"
    _starship_toml="$HOME/.config/starship.toml"
    if [[ ! -f "$_starship_cache" ]] || [[ "$_starship_toml" -nt "$_starship_cache" ]] || [[ $(command -v starship) -nt "$_starship_cache" ]]; then
      starship init zsh > "$_starship_cache"
    fi
    source "$_starship_cache"
    """

  '';

  # ============================================================
  # Zsh 設定
  # ============================================================
  programs.zsh = {
    enable = true;
    # sheldon を使う場合、home-manager の組み込み機能は無効化
    autosuggestion.enable = false;
    enableCompletion = false; # カスタム最適化版を使用
    syntaxHighlighting.enable = false;

    # hm-session-vars が親プロセスからのフラグでスキップされる場合でも、
    # NVIM_PLUGIN_DIR を固定パスに戻す（macOS/Linux 共通）。
    envExtra = ''
      unset __HM_SESS_VARS_SOURCED
      export NVIM_PLUGIN_DIR="${config.xdg.dataHome}/nvim-plugins"

      # CLIProxyAPI: ローカルプロキシ用のダミーAPIキーとベースURL
      export CLI_PROXY_API_KEY="dummy-c3d4ee78f2909bc57fcc903fcb115e6fa23c8b6406b6492a8ce05bf78f48920e"
      export CLI_PROXY_API_BASE_URL="http://127.0.0.1:8317"

      if [[ -f "$HOME/.config/claude-code/env" ]]; then
        source "$HOME/.config/claude-code/env"
      fi

      # 起動時間計測: できるだけ早く開始時刻を記録
      if [[ "''${ZSH_PROFILE:-0}" == "1" ]]; then
        zmodload zsh/datetime 2>/dev/null || true
        export _ZSH_START_EPOCHREALTIME="$EPOCHREALTIME"
      fi

      # Ghostty: SSH接続時の元のTERMを保存
      # ~/.zshenv は /etc/zprofile → /etc/profile より前に実行されるため、
      # /etc/profile が TERM を上書きする前の値を保持できる
      if [[ -n "$SSH_CONNECTION" && -z "$_SSH_ORIGINAL_TERM" ]]; then
        export _SSH_ORIGINAL_TERM="$TERM"
      fi
    '';

    # XDG 準拠の設定ディレクトリ
    dotDir = "${config.xdg.configHome}/zsh";

    # 履歴設定
    history = {
      size = 100000;
      save = 100000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      extended = true;
      share = true;
    };

    # 追加の initContent (initExtra から移行)
    initContent = ''
      # ============================================================
      # 高速キャッシュ初期化
      # ============================================================
      _zsh_cache_dir="$HOME/.cache/zsh"
      [[ -d "$_zsh_cache_dir" ]] || mkdir -p "$_zsh_cache_dir"
      export ZSH_CACHE_DIR="$_zsh_cache_dir/oh-my-zsh"
      [[ -d "$ZSH_CACHE_DIR/completions" ]] || mkdir -p "$ZSH_CACHE_DIR/completions"

      # ============================================================
      # 起動時間計測 (zprof)
      # ============================================================
      _zsh_profile_enabled=0
      if [[ "''${ZSH_PROFILE:-0}" == "1" ]]; then
        _zsh_profile_enabled=1
        zmodload zsh/zprof 2>/dev/null || true
        zmodload zsh/datetime 2>/dev/null || true
      fi
      if (( _zsh_profile_enabled )) && [[ -z "''${_ZSH_START_EPOCHREALTIME:-}" ]]; then
        _ZSH_START_EPOCHREALTIME="$EPOCHREALTIME"
      fi

      # 起動計測: 初回プロンプトで入力受付可能になった時点を記録
      if (( _zsh_profile_enabled )) && [[ -t 0 ]]; then
        _zsh_profile_prompt_ready() {
          if [[ -n "''${_ZSH_START_EPOCHREALTIME:-}" ]]; then
            local _zsh_now _zsh_elapsed _zsh_profile_log
            _zsh_now="$EPOCHREALTIME"
            _zsh_elapsed=$(printf "%.3f" "$((_zsh_now - _ZSH_START_EPOCHREALTIME))")
            _zsh_profile_log="''${ZSH_PROFILE_LOG:-$_zsh_cache_dir/zsh-startup.log}"
            {
              print -r -- "prompt_ready=''${_zsh_elapsed}s"
            } >>| "$_zsh_profile_log" 2>&1
          fi
          if (( $+functions[add-zle-hook-widget] )); then
            add-zle-hook-widget -d zle-line-init _zsh_profile_prompt_ready 2>/dev/null || true
          fi
          unset -f _zsh_profile_prompt_ready
          unset _ZSH_START_EPOCHREALTIME
        }
        _zsh_profile_setup_prompt_ready() {
          zmodload zsh/zle 2>/dev/null || true
          autoload -Uz add-zle-hook-widget
          add-zle-hook-widget -Uz zle-line-init _zsh_profile_prompt_ready 2>/dev/null || true
          precmd_functions=(''${precmd_functions:#_zsh_profile_setup_prompt_ready})
          unset -f _zsh_profile_setup_prompt_ready
        }
        autoload -Uz add-zsh-hook
        add-zsh-hook precmd _zsh_profile_setup_prompt_ready
      fi

      # ── compinit 先行初期化 ──
      autoload -Uz compinit
      _comp_dump="$_zsh_cache_dir/.zcompdump"
      _comp_dump_fpath="$_zsh_cache_dir/.zcompdump.fpath"
      _zsh_compinit_done=0

      _zsh_compinit_run() {
        (( _zsh_compinit_done )) && return 0
        local _ok=0
        if [[ "''${ZSH_COMPINIT_SECURE:-0}" == "1" ]]; then
          compinit -d "$_comp_dump" && _ok=1
        else
          local _fpath_snap="''${(j:\n:)fpath}" _rebuild=1
          if [[ -f "$_comp_dump" ]] && [[ -f "$_comp_dump_fpath" ]] \
             && [[ "$_fpath_snap" == "$(<"$_comp_dump_fpath")" ]]; then
            _rebuild=0
          fi
          if (( _rebuild )); then
            compinit -d "$_comp_dump" && _ok=1
          else
            compinit -C -d "$_comp_dump" && _ok=1
          fi
          (( _ok )) && printf '%s' "$_fpath_snap" >| "$_comp_dump_fpath"
        fi
        if (( ! _ok )); then return 1; fi
        _zsh_compinit_done=1
      }

      # ============================================================
      # プロンプト選択 (ビルド時に決定)
      # ============================================================
      _zsh_prompt_profile="${promptProfile}"
      export ZSH_PROMPT_PROFILE="${promptProfile}"
      export SHELDON_PROFILE="${promptProfile}"
      if [[ "$_zsh_prompt_profile" == "p10k" ]]; then
        if [[ -f "$HOME/.config/zsh/p10k.zsh" ]]; then
          export POWERLEVEL9K_CONFIG_FILE="$HOME/.config/zsh/p10k.zsh"
        fi
        export POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
      fi

      # Sheldon キャッシュ (設定変更時のみ再生成)
      _sheldon_cache="$_zsh_cache_dir/sheldon.${promptProfile}.zsh"
      _sheldon_toml="$HOME/.config/sheldon/plugins.toml"
      _sheldon_toml_target="$(readlink "$_sheldon_toml" 2>/dev/null || echo "$_sheldon_toml")"
      _sheldon_toml_target_cache="$_zsh_cache_dir/sheldon.toml.target"
      _sheldon_rebuild=0
      if [[ ! -f "$_sheldon_cache" ]] || [[ "$_sheldon_toml" -nt "$_sheldon_cache" ]]; then
        _sheldon_rebuild=1
      elif [[ ! -f "$_sheldon_toml_target_cache" ]] || [[ "$_sheldon_toml_target" != "$(cat "$_sheldon_toml_target_cache" 2>/dev/null)" ]]; then
        _sheldon_rebuild=1
      fi
      if (( _sheldon_rebuild )); then
        SHELDON_PROFILE="${promptProfile}" sheldon source > "$_sheldon_cache"
        printf '%s' "$_sheldon_toml_target" > "$_sheldon_toml_target_cache"
      fi
      _zsh_compinit_run
      source "$_sheldon_cache"
      unset _sheldon_rebuild _sheldon_toml_target _sheldon_toml_target_cache

      if [[ "$_zsh_prompt_profile" == "pure" ]]; then
        # pure.zsh が読み込まれた時点でプロンプトを設定する
        :
      fi

      # ============================================================
      # JetBrains IDE ターミナル対策
      # ============================================================
      if [[ "$TERMINAL_EMULATOR" == JetBrains* ]]; then
        export TERMINFO_DIRS="/Applications/Ghostty.app/Contents/Resources/terminfo:''${TERMINFO_DIRS:-}"
        export TERM=xterm-ghostty
      fi

      # キーバインド (Vi style)
      bindkey -v

      _zsh_bind_tab_widget() {
        if [[ -o zle ]]; then
          if (( $+widgets[fzf-tab-complete] )); then
            zstyle ':completion:*' menu no
            bindkey -M main '^I' fzf-tab-complete
            bindkey -M emacs '^I' fzf-tab-complete
            bindkey -M viins '^I' fzf-tab-complete
            bindkey -M vicmd '^I' fzf-tab-complete
          else
            zstyle ':completion:*' menu select
            bindkey -M main '^I' expand-or-complete
            bindkey -M emacs '^I' expand-or-complete
            bindkey -M viins '^I' expand-or-complete
            bindkey -M vicmd '^I' expand-or-complete
          fi
        fi
      }
      _zsh_bind_tab_widget
      unset -f _zsh_bind_tab_widget

      # Ctrl+S/Cmd+S で端末が止まらないようにする
      if [[ -t 0 ]] && command -v stty &> /dev/null; then
        stty -ixon
      fi

      # Ghostty: SSH接続時のTERM復元/フォールバック
      # ~/.zshenv で保存した _SSH_ORIGINAL_TERM を使い、
      # /etc/profile 等に上書きされた TERM を復元する
      if [[ -n "$SSH_CONNECTION" ]]; then
        _ghostty_term="''${_SSH_ORIGINAL_TERM:-$TERM}"
        if [[ "$_ghostty_term" == "xterm-ghostty" ]]; then
          if [[ -f "$HOME/.terminfo/x/xterm-ghostty" || -f "$HOME/.terminfo/78/xterm-ghostty" ]] ||
             { command -v infocmp &> /dev/null && infocmp xterm-ghostty &> /dev/null; }; then
            export TERM="xterm-ghostty"
          else
            export TERM="xterm-256color"
          fi
        fi
        unset _SSH_ORIGINAL_TERM _ghostty_term
      fi

      # Vi モードでのカーソル形状変更
      function zle-keymap-select {
        if [[ $KEYMAP == vicmd ]]; then
          printf '\e[2 q'  # Block cursor for normal mode
        else
          printf '\e[6 q'  # Beam cursor for insert mode
        fi
      }
      zle -N zle-keymap-select

      # 起動時は insert mode
      printf '\e[6 q'

      # Ghostty tab title: user@host:cwd
      autoload -Uz add-zsh-hook
      _ghostty_tab_title() {
        [[ -z "$GHOSTTY_RESOURCES_DIR" ]] && return
        print -Pn "\e]2;%n@%m:%~\a"
      }
      add-zsh-hook precmd _ghostty_tab_title
      add-zsh-hook preexec _ghostty_tab_title

      # history-substring-search のキーバインド
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
      bindkey '^P' history-substring-search-up
      bindkey '^N' history-substring-search-down

      # 単語区切り文字
      WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

      # 補完設定 (大文字小文字を区別しない)
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}

      # fzf-tab 設定
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
      zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always $realpath'
      zstyle ':fzf-tab:*' switch-group ',' '.'

      # fzf 設定
      if command -v fzf &> /dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
        export FZF_DEFAULT_OPTS='
          --height 40%
          --layout=reverse
          --border
          --inline-info
          -i
        '
      fi

      # ghq + fzf
      function ghq-fzf() {
        local selected
        selected=$(ghq list -p | fzf --preview "bat --color=always --style=header,grid {}/README.md 2>/dev/null || ls -la {}")
        if [ -n "$selected" ]; then
          cd "$selected"
        fi
      }
      alias g='ghq-fzf'

      # zoxide, プロンプトは sheldon で初期化

      # ============================================================
      # プロファイリング結果出力
      # ============================================================
      if (( _zsh_profile_enabled )); then
        _zsh_profile_log="''${ZSH_PROFILE_LOG:-$_zsh_cache_dir/zsh-startup.log}"
        {
          print -r -- "---- zsh startup $(date '+%Y-%m-%d %H:%M:%S') pid=$$ ----"
          if [[ -n "''${_ZSH_START_EPOCHREALTIME:-}" ]]; then
            _zsh_end="$EPOCHREALTIME"
            _zsh_elapsed=$(printf "%.3f" "$((_zsh_end - _ZSH_START_EPOCHREALTIME))")
            print -r -- "elapsed=''${_zsh_elapsed}s"
          fi
          if whence -w zprof >/dev/null 2>&1; then
            zprof
          else
            print -r -- "zprof not available"
          fi
          print -r -- ""
        } >>| "$_zsh_profile_log" 2>&1
        unset _zsh_profile_log _zsh_end _zsh_elapsed
      fi
      unset _zsh_profile_enabled
    '';

    # シェルエイリアス
    shellAliases = {
      # ls → eza
      ls = "eza --icons";
      ll = "eza -l --icons --git";
      la = "eza -la --icons --git";
      lt = "eza --tree --icons --git-ignore";
      l = "eza -lah --icons --git";

      # cat → bat
      cat = "bat";

      # grep → ripgrep
      grep = "rg";

      # find → fd
      find = "fd";

      # zoxide のエイリアス (cdはzoxideが自動設定するため削除)

      # 確認付き操作
      rm = "rm -i";
      cp = "cp -i";
      mv = "mv -i";

      # ディレクトリ操作
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";
      mkd = "mkdir -pv";

      # プロセス
      psg = "ps aux | grep -v grep | grep";

      # ネットワーク
      myip = "curl -s https://ipinfo.io/ip";

      # エディタ
      nvim = "command nvim";
      v = "command nvim";
      vi = "command nvim";
      vim = "command nvim";
      view = "command nvim -R";

      # Git (追加)
      gs = "git status -sb";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git pull";
      gd = "git diff";
      gco = "git checkout";
      gb = "git branch";
      glg = "git log --oneline --graph --all -20";
      lg = "lazygit";

      # Docker
      d = "docker";
      dc = "docker compose";
      dps = "docker ps";
      dpsa = "docker ps -a";
      dimg = "docker images";
      drm = "docker rm";
      drmi = "docker rmi";
      dprune = "docker system prune -af";
      lzd = "lazydocker";

      # Kubernetes
      k = "kubectl";
      kgp = "kubectl get pods";
      kgs = "kubectl get svc";
      kgd = "kubectl get deployments";

      # Nix
      nrs = "sudo nixos-rebuild switch";
      nrb = "sudo nixos-rebuild boot";
      hms = "home-manager switch";
      drs = "darwin-rebuild switch --flake .";

      # その他
      reload = "exec $SHELL -l";
      path = "echo $PATH | tr ':' '\n'";
      now = "date '+%Y-%m-%d %H:%M:%S'";
      week = "date +%V";
    };

    # プラグインは sheldon で管理するため、ここでは定義しない
    # plugins = [];
  };

  # ============================================================
  # fzf 設定
  # ============================================================
  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
    enableFishIntegration = false;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
      "-i" # case-insensitive
    ];
  };

  # ============================================================
  # zoxide 設定
  # ============================================================
  programs.zoxide = {
    enable = true;
    # Zsh は sheldon で初期化するため無効化
    enableZshIntegration = false;
    enableFishIntegration = false;
  };

  # ============================================================
  # bat 設定
  # ============================================================
  programs.bat = {
    enable = true;
    config = {
      style = "numbers,changes,header";
      pager = "less -FR";
    };
  };

  # ============================================================
  # eza 設定
  # ============================================================
  programs.eza = {
    enable = true;
    icons = "auto";
    git = true;
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];
  };
}
