{ config, pkgs, lib, ... }:

{
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

    # gh (GitHub CLI) 補完
    [plugins.gh-completion]
    inline = 'eval "$(gh completion -s zsh)"'

    # AWS CLI 補完
    [plugins.aws-completion]
    inline = """
    if command -v aws_completer &> /dev/null; then
      autoload -Uz bashcompinit && bashcompinit
      complete -C aws_completer aws
    fi
    """

    # Google Cloud SDK 補完
    [plugins.gcloud-completion]
    inline = """
    if [[ -n "$CLOUDSDK_ROOT_DIR" ]]; then
      source "$CLOUDSDK_ROOT_DIR/completion.zsh.inc" 2>/dev/null
    elif [[ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]]; then
      source "$HOME/google-cloud-sdk/completion.zsh.inc"
    fi
    """

    # Docker 補完
    [plugins.docker-completion]
    inline = """
    if command -v docker &> /dev/null; then
      eval "$(docker completion zsh 2>/dev/null)"
    fi
    """

    # ============================================================
    # Prompt & Tools (最後に読み込み)
    # ============================================================

    # direnv (環境自動切り替え)
    [plugins.direnv]
    inline = 'eval "$(direnv hook zsh)"'

    # zoxide (スマート cd)
    [plugins.zoxide]
    inline = 'eval "$(zoxide init zsh)"'

    # Starship プロンプト (最後に初期化)
    [plugins.starship]
    inline = 'eval "$(starship init zsh)"'
  '';

  # ============================================================
  # Zsh 設定
  # ============================================================
  programs.zsh = {
    enable = true;
    # sheldon を使う場合、home-manager の組み込み機能は無効化
    autosuggestion.enable = false;
    enableCompletion = true;
    syntaxHighlighting.enable = false;

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
      # Sheldon 初期化 (最優先で読み込み)
      # ============================================================
      if command -v sheldon &> /dev/null; then
        eval "$(sheldon source)"
      fi

      # キーバインド (Vi style)
      bindkey -v

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
          --color=dark
          --color=fg:-1,bg:-1,hl:#c678dd,fg+:#ffffff,bg+:#4b5263,hl+:#d858fe
          --color=info:#98c379,prompt:#61afef,pointer:#be5046,marker:#e5c07b,spinner:#61afef,header:#61afef
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
      v = "nvim";
      vim = "nvim";

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

    interactiveShellInit = ''
      # 挨拶無効化
      set -g fish_greeting

      # カラー設定
      set -g fish_color_command green
      set -g fish_color_param cyan
      set -g fish_color_error red --bold

      # fzf 設定
      set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
      set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
      set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'

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
      v = "nvim";
      vim = "nvim";
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
    colors = {
      "bg+" = "#3B4252";
      "fg+" = "#ECEFF4";
      "hl" = "#A3BE8C";
      "hl+" = "#A3BE8C";
      "info" = "#EBCB8B";
      "prompt" = "#81A1C1";
      "pointer" = "#BF616A";
      "marker" = "#B48EAD";
    };
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
      theme = "Dracula";
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
