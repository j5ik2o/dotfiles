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
    git-secrets # シークレット漏洩防止
    gh
    ghq
    gwq # Git worktree マネージャ
    tig
    jujutsu # Git 互換 VCS (jj コマンド)
    # lazygit は programs.lazygit で管理

    # シェルツール
    zsh
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
    mise # 開発環境マネージャ
    zellij # ターミナルマルチプレクサ
    tmux # ターミナルマルチプレクサ（代替）

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
    tdf # ターミナル PDF ビューア
    chafa # ターミナル画像ビューア
    poppler-utils # PDF ツール (pdftoppm 等)
    marp-cli # Marp スライド変換 CLI
    graphviz # PlantUML の dot レンダラー

    # AI ツール
    # claude-code, codex は mise で管理
    claude-code-acp
    cliproxyapi
    coderabbit # AI コードレビュー CLI
    codex-acp
    opencode
    gemini-cli # Google Gemini CLI

    # ============================================================
    # 言語ランタイム (mise で管理)
    # ============================================================
    # Java, Node.js 等のランタイムは mise use -g で管理

    # Scala ビルドツール
    sbt
    gradle
    maven

    # Go
    go

    # Node.js パッケージマネージャ
    pnpm
    bun
    yarn

    # Python パッケージマネージャ
    uv

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

    # ビルド依存 (mise でのランタイムビルド用)
    pkg-config
    libyaml # Ruby psych extension
    libyaml.dev # Ruby psych headers / pkg-config
    openssl.out # Ruby openssl extension (libs)
    openssl.dev # Ruby openssl headers / pkg-config
    zlib # Ruby zlib extension (libs)
    zlib.dev # Ruby zlib headers / pkg-config
    libffi # Ruby fiddle extension (libs)
    libffi.dev # Ruby fiddle headers / pkg-config
  ];

  # ============================================================
  # モジュールのインポート
  # ============================================================
  imports = [
    ./programs/git.nix
    ./programs/jujutsu.nix
    ./programs/zsh.nix
    ./programs/starship.nix
    ./programs/catppuccin.nix
    ./programs/neovim.nix
    ./programs/helix.nix
    ./programs/direnv.nix
    ./programs/cliproxyapi.nix
    ./programs/opencode.nix
    ./programs/clawdbot.nix
    ./programs/zellij.nix
    ./programs/tmux.nix
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
    # 言語ランタイム (JAVA_HOME 等) は mise で管理

    # mise での Ruby ビルド用 (libyaml, openssl, zlib, libffi)
    PKG_CONFIG_PATH = "${pkgs.libyaml.dev}/lib/pkgconfig:${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.zlib.dev}/lib/pkgconfig:${pkgs.libffi.dev}/lib/pkgconfig";
    RUBY_CONFIGURE_OPTS = lib.concatStringsSep " " [
      "--with-libyaml-include=${pkgs.libyaml.dev}/include"
      "--with-libyaml-lib=${pkgs.libyaml}/lib"
      "--with-openssl-include=${pkgs.openssl.dev}/include"
      "--with-openssl-lib=${pkgs.openssl.out}/lib"
      "--with-zlib-include=${pkgs.zlib.dev}/include"
      "--with-zlib-lib=${pkgs.zlib}/lib"
      "--with-libffi-include=${pkgs.libffi.dev}/include"
      "--with-libffi-lib=${pkgs.libffi}/lib"
    ];
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
  home.file.".local/bin/clean-commit-msg.py" = {
    source = "${self}/scripts/clean-commit-msg.py";
    executable = true;
  };
  # claude は mise で管理（PATH に自動追加される）
  home.file.".local/bin/claude-code-acp" = {
    source = "${pkgs.claude-code-acp}/bin/claude-code-acp";
  };
  # Claude Code ステータスライン（identity 表示用）
  home.file.".claude/statusline.sh" = {
    source = "${self}/config/claude-code/statusline.sh";
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
