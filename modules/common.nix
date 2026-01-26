{
  config,
  pkgs,
  lib,
  username,
  self,
  ...
}:

{
  # ============================================================
  # Home Manager 共通設定
  # macOS / Linux で共有される設定
  # ============================================================

  # 基本設定
  # home.username, home.homeDirectory, home.stateVersion は flake.nix で設定

  # Home Manager 自身の管理を有効化
  programs.home-manager.enable = true;

  # ============================================================
  # 共通パッケージ
  # ============================================================
  home.packages = with pkgs; [
    # 開発ツール
    git
    gh
    ghq
    gwq # Git worktree マネージャ
    tig
    # lazygit は programs.lazygit で管理

    # シェルツール
    zsh
    fish
    starship
    zoxide
    fzf
    bat
    eza
    ripgrep
    fd
    jq
    yq
    direnv

    # エディタ
    # neovim は programs.neovim で管理
    # helix は programs.helix で管理

    # ネットワーク
    curl
    wget
    httpie

    # クラウド CLI
    awscli2
    google-cloud-sdk

    # IaC (Infrastructure as Code)
    opentofu # Terraform のオープンソースフォーク
    tflint # Terraform リンター
    terraform-docs # ドキュメント生成

    # コンテナ
    lazydocker
    dive # Docker イメージ解析
    ctop # コンテナ監視

    # アーカイブ
    unzip
    zip

    # その他ユーティリティ
    tree
    htop
    bottom
    dust
    procs
    tokei
    hyperfine
    devbox # Nix ベース開発環境
    chezmoi # シークレット管理付き dotfiles
    nvd # Nix パッケージ差分表示

    # AI ツール
    claude-code
    codex # OpenAI Codex CLI
    opencode
    gemini-cli # Google Gemini CLI

    # ============================================================
    # 言語ランタイム (mise から移行)
    # ============================================================

    # Java (Temurin / Eclipse Adoptium)
    # グローバルは 21 LTS のみ。他バージョンはプロジェクトの flake.nix で指定
    temurin-bin-21

    # Scala
    scala_3
    sbt
    gradle
    maven

    # Go
    go

    # Node.js
    nodejs_20
    pnpm
    bun
    yarn

    # Python
    python313
    uv # Python パッケージマネージャ

    # Ruby
    ruby_3_3

    # Rust (rustup で toolchain 管理)
    rustup

    # Zig
    zig

    # Lean 4 (定理証明 / 関数型言語)
    elan # Lean バージョンマネージャ (rustup 相当)

    # Haskell
    ghc
    cabal-install
    stack

    # Protocol Buffers
    protobuf
  ];

  # ============================================================
  # モジュールのインポート
  # ============================================================
  imports = [
    ./programs/git.nix
    ./programs/shell.nix
    ./programs/starship.nix
    ./programs/catppuccin.nix
    ./programs/neovim.nix
    ./programs/helix.nix
    ./programs/direnv.nix
    ./programs/opencode.nix
    ./programs/clawdbot.nix
  ];

  # ============================================================
  # 共通の環境変数
  # ============================================================
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "bat";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";

    # Java (デフォルトは 21 LTS)
    JAVA_HOME = "${pkgs.temurin-bin-21}/lib/openjdk";
  };

  # ============================================================
  # XDG ディレクトリ設定
  # ============================================================
  xdg.enable = true;

  # ============================================================
  # PATH 追加
  # ============================================================
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # ============================================================
  # カスタムスクリプト
  # ============================================================
  home.file.".local/bin/git-ai-commit" = {
    source = "${self}/scripts/git-ai-commit.sh";
    executable = true;
  };

  # ============================================================
  # lazygit 設定
  # ============================================================
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        language = "ja";
      };
      customCommands = [
        {
          key = "C";
          context = "files";
          command = "git-ai-commit";
          description = "AI commit (Claude Code)";
          loadingText = "Generating commit message...";
          output = "terminal";
        }
      ];
    };
  };
}
