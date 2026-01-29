{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ============================================================
  # mise (言語ランタイム管理)
  # ============================================================
  xdg.configFile."mise/config.toml".text = ''
    [tools]
    java = "temurin-21"
    node = "22"
    python = "3.13"
    ruby = "3.3"
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
    # Deferred loading (遅延読み込み用テンプレート)
    # ============================================================
    [templates]
    defer = "{{ hooks?.pre | nl }}{% for file in files %}zsh-defer source \"{{ file }}\"\n{% endfor %}{{ hooks?.post | nl }}"

    # ============================================================
    # Core plugins
    # ============================================================

    # zsh-defer (遅延読み込みの基盤)
    [plugins.zsh-defer]
    github = "romkatv/zsh-defer"
    proto = "https"

    # Powerlevel10k (高速プロンプト) - Starship を使う場合はコメントアウト
    # [plugins.powerlevel10k]
    # github = "romkatv/powerlevel10k"

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
    # Enhancements (defer で遅延読み込み)
    # ============================================================

    [plugins.zsh-autosuggestions]
    github = "zsh-users/zsh-autosuggestions"
    proto = "https"
    apply = ["defer"]

    [plugins.zsh-syntax-highlighting]
    github = "zsh-users/zsh-syntax-highlighting"
    proto = "https"
    apply = ["defer"]

    [plugins.zsh-history-substring-search]
    github = "zsh-users/zsh-history-substring-search"
    proto = "https"
    apply = ["defer"]

    # ============================================================
    # Productivity
    # ============================================================

    [plugins.zsh-autopair]
    github = "hlissner/zsh-autopair"
    proto = "https"
    apply = ["defer"]

    [plugins.zsh-you-should-use]
    github = "MichaelAquilina/zsh-you-should-use"
    proto = "https"
    apply = ["defer"]

    # fzf-tab (fzf で補完をリッチに)
    [plugins.fzf-tab]
    github = "Aloxaf/fzf-tab"
    proto = "https"

    # ============================================================
    # Git enhancements
    # ============================================================

    [plugins.forgit]
    github = "wfxr/forgit"
    proto = "https"
    apply = ["defer"]

    # ============================================================
    # Directory navigation
    # ============================================================

    [plugins.enhancd]
    github = "b4b4r07/enhancd"
    proto = "https"
    apply = ["defer"]

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
    apply = ["defer"]

    # ============================================================
    # CLI Tool Completions
    # ============================================================

    # gh (GitHub CLI) 補完 (キャッシュ + 遅延読み込み)
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
    if (( $+functions[zsh-defer] )); then
      zsh-defer _gh_completion_defer
    else
      _gh_completion_defer
    fi
    """

    # AWS CLI 補完 (遅延読み込み)
    [plugins.aws-completion]
    inline = """
    _aws_completion_defer() {
      if command -v aws_completer &> /dev/null; then
        autoload -Uz bashcompinit && bashcompinit
        complete -C aws_completer aws
      fi
    }
    if (( $+functions[zsh-defer] )); then
      zsh-defer _aws_completion_defer
    else
      _aws_completion_defer
    fi
    """

    # Google Cloud SDK 補完 (遅延読み込み)
    [plugins.gcloud-completion]
    inline = """
    _gcloud_completion_defer() {
      if [[ -n "$CLOUDSDK_ROOT_DIR" ]]; then
        source "$CLOUDSDK_ROOT_DIR/completion.zsh.inc" 2>/dev/null
      elif [[ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]]; then
        source "$HOME/google-cloud-sdk/completion.zsh.inc"
      fi
    }
    if (( $+functions[zsh-defer] )); then
      zsh-defer _gcloud_completion_defer
    else
      _gcloud_completion_defer
    fi
    """

    # Docker 補完 (キャッシュ + 遅延読み込み)
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
    if (( $+functions[zsh-defer] )); then
      zsh-defer _docker_completion_defer
    else
      _docker_completion_defer
    fi
    """

    # ============================================================
    # Prompt & Tools (最後に読み込み)
    # ============================================================

    # mise (言語ランタイム管理)
    [plugins.mise]
    inline = """
    if command -v mise &> /dev/null; then
      eval "$(mise activate zsh)"
    fi
    """

    # direnv (環境自動切り替え)
    [plugins.direnv]
    inline = """
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
    enableCompletion = false;  # カスタム最適化版を使用
    syntaxHighlighting.enable = false;

    # hm-session-vars が親プロセスからのフラグでスキップされる場合でも、
    # NVIM_PLUGIN_DIR を固定パスに戻す（macOS/Linux 共通）。
    envExtra = ''
      unset __HM_SESS_VARS_SOURCED
      export NVIM_PLUGIN_DIR="${config.xdg.dataHome}/nvim-plugins"

      if [[ -f "$HOME/.config/claude-code/env" ]]; then
        source "$HOME/.config/claude-code/env"
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

      # compinit 最適化 (1日1回だけ dump 再構築) - sheldon より先に実行
      autoload -Uz compinit
      _comp_dump="$_zsh_cache_dir/.zcompdump"
      if [[ -n "$_comp_dump"(#qN.mh+24) ]]; then
        compinit -d "$_comp_dump"
      else
        compinit -C -d "$_comp_dump"
      fi

      # Sheldon キャッシュ (設定変更時のみ再生成)
      _sheldon_cache="$_zsh_cache_dir/sheldon.zsh"
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
        sheldon source > "$_sheldon_cache"
        printf '%s' "$_sheldon_toml_target" > "$_sheldon_toml_target_cache"
      fi
      source "$_sheldon_cache"
      unset _sheldon_rebuild _sheldon_toml_target _sheldon_toml_target_cache

      # ============================================================
      # JetBrains IDE ターミナル対策
      # ============================================================
      if [[ "$TERMINAL_EMULATOR" == JetBrains* ]]; then
        export TERMINFO_DIRS="/Applications/Ghostty.app/Contents/Resources/terminfo:''${TERMINFO_DIRS:-}"
        export TERM=xterm-ghostty
      fi

      # キーバインド (Vi style)
      bindkey -v

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

      # 補完設定
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
      zstyle ':completion:*' menu select
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

      # zoxide, starship は sheldon で初期化
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
  # Fish 設定
  # ============================================================
  programs.fish = {
    enable = true;

    # shellInit は interactiveShellInit より前に実行される
    shellInit = ''
      # Ghostty: SSH接続時の元のTERMを保存
      if set -q SSH_CONNECTION; and not set -q _SSH_ORIGINAL_TERM
        set -gx _SSH_ORIGINAL_TERM $TERM
      end
    '';

    interactiveShellInit = ''
      # 挨拶無効化
      set -g fish_greeting

      # Ctrl+S/Cmd+S で端末が止まらないようにする
      if test -t 0
        command -q stty; and stty -ixon
      end

      # Ghostty: SSH接続時のTERM復元/フォールバック
      if set -q SSH_CONNECTION
        set -l _ghostty_term (if set -q _SSH_ORIGINAL_TERM; echo $_SSH_ORIGINAL_TERM; else; echo $TERM; end)
        if test "$_ghostty_term" = "xterm-ghostty"
          if test -f "$HOME/.terminfo/x/xterm-ghostty"; or test -f "$HOME/.terminfo/78/xterm-ghostty"
            set -gx TERM xterm-ghostty
          else if command -q infocmp; and infocmp xterm-ghostty >/dev/null 2>&1
            set -gx TERM xterm-ghostty
          else
            set -gx TERM xterm-256color
          end
        end
        set -e _SSH_ORIGINAL_TERM
      end

      # カラー設定
      set -g fish_color_command green
      set -g fish_color_param cyan
      set -g fish_color_error red --bold

      # fzf 設定
      set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
      set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
      set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'

      # mise 初期化 (言語ランタイム管理)
      mise activate fish | source

      # zoxide 初期化
      zoxide init fish | source

      # Starship 初期化
      starship init fish | source
    '';

    shellAliases = {
      # ls → eza
      ls = "eza --icons";
      ll = "eza -l --icons --git";
      la = "eza -la --icons --git";
      lt = "eza --tree --icons --git-ignore";

      # その他のエイリアスは zsh と共通
      cat = "bat";
      grep = "rg";
      nvim = "command nvim";
      v = "command nvim";
      vi = "command nvim";
      vim = "command nvim";
      lg = "lazygit";
    };

    # Fish プラグイン
    plugins = [
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        name = "done";
        src = pkgs.fishPlugins.done.src;
      }
    ];
  };

  # ============================================================
  # fzf 設定
  # ============================================================
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
    ];
  };

  # ============================================================
  # zoxide 設定
  # ============================================================
  programs.zoxide = {
    enable = true;
    # Zsh は sheldon で初期化するため無効化
    enableZshIntegration = false;
    enableFishIntegration = true;
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
