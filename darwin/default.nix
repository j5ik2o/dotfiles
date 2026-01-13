{ config, pkgs, lib, inputs, username, ... }:

{
  # ============================================================
  # nix-darwin システムレベル設定
  # macOS のシステム設定を Nix で宣言的に管理
  # ============================================================

  # unfree パッケージの許可 (claude-code など)
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "claude-code"
  ];

  # Nix 設定
  nix = {
    settings = {
      # Flakes を有効化
      experimental-features = [ "nix-command" "flakes" "auto-allocate-uids" ];

      # 信頼するユーザー
      trusted-users = [ "root" username ];

      # バイナリキャッシュ
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

    };

    # ストア最適化
    optimise.automatic = true;

    # ガベージコレクション
    gc = {
      automatic = true;
      interval = { Weekday = 0; Hour = 2; Minute = 0; };
      options = "--delete-older-than 30d";
    };
  };

  # ============================================================
  # システムパッケージ
  # ============================================================
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
  ];

  # ============================================================
  # Homebrew 統合 (Cask アプリケーション用)
  # ============================================================
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";  # "zap" は全ての未定義 cask を削除するので危険
      upgrade = true;
    };

    # Homebrew taps
    taps = [
    ];

    # CLI ツール (Nix にないもの)
    brews = [
      # 例: "awscli"
    ];

    # GUI アプリケーション
    casks = [
      # ブラウザ
      "google-chrome"
      "firefox"
      "arc"

      # 開発ツール
      "jetbrains-toolbox"
      "visual-studio-code"
      "zed"

      "cursor"
      "windsurf"
      "antigravity"

      "iterm2"
      "warp"
      "wezterm"
      "ghostty"

      "docker-desktop"
      "github"

      "parallels"

      # AI / ML
      "lm-studio"
      "chatgpt"
      "claude"

      # ユーティリティ
      "coteditor"
      "raycast"
      "alfred"
      "1password"
      "1password-cli"
      "karabiner-elements"
      "rectangle"
      "alt-tab"
      "stats"
      "monitorcontrol"
      "cleanshot"           # スクリーンショット
      "angry-ip-scanner"
      "tailscale-app"

      # コミュニケーション
      "slack"
      "discord"
      "zoom"

      # クラウドストレージ
      "dropbox"
      "google-drive"

      # その他
      "notion"
      "obsidian"
      "mactex"              # LaTeX
      "spotify"
    ];

    # Mac App Store アプリ
    masApps = {
      # "App Name" = App ID;
      # 例: "Xcode" = 497799835;
    };
  };

  # ============================================================
  # macOS システム設定
  # ============================================================
  system.defaults = {
    # Dock 設定
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.4;
      expose-animation-duration = 0.15;
      minimize-to-application = true;
      mru-spaces = false;
      orientation = "bottom";
      show-recents = false;
      tilesize = 48;
      wvous-bl-corner = 1;  # Disabled
      wvous-br-corner = 1;  # Disabled
      wvous-tl-corner = 1;  # Disabled
      wvous-tr-corner = 1;  # Disabled
    };

    # Finder 設定
    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      CreateDesktop = false;
      FXDefaultSearchScope = "SCcf";  # 現在のフォルダを検索
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv";  # リスト表示
      QuitMenuItem = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
    };

    # トラックパッド設定
    trackpad = {
      Clicking = true;  # タップでクリック
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };

    # キーボード設定
    NSGlobalDomain = {
      # キーリピート設定 (macOSデフォルト: KeyRepeat=2, InitialKeyRepeat=15)
      # 削除してOSデフォルトに任せる

      # その他
      AppleInterfaceStyle = "Dark";  # ダークモード
      AppleKeyboardUIMode = 3;  # フルキーボードアクセス
      ApplePressAndHoldEnabled = false;  # キーリピートを有効化
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "WhenScrolling";
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
    };

    # スクリーンキャプチャ設定
    screencapture = {
      location = "~/Pictures/Screenshots";
      type = "png";
      disable-shadow = true;
    };

    # その他
    CustomUserPreferences = {
      "com.apple.desktopservices" = {
        # .DS_Store をネットワークボリュームに作成しない
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
      };
    };
  };

  # ============================================================
  # キーボードリマッピング (hidutil)
  # ============================================================
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  # ============================================================
  # セキュリティ設定
  # ============================================================
  security.pam.services.sudo_local.touchIdAuth = true;

  # ============================================================
  # フォント設定
  # ============================================================
  fonts = {
    packages = with pkgs; [
      # Nerd Fonts
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.hack
      nerd-fonts.meslo-lg
      nerd-fonts.monaspace

      # 日本語フォント
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      source-han-sans
      source-han-serif
    ];
  };

  # ============================================================
  # シェル設定
  # ============================================================
  programs.zsh.enable = true;
  programs.fish.enable = true;
  environment.shells = [
    pkgs.zsh
  ];

  # ============================================================
  # ユーザー設定
  # ============================================================
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
    shell = pkgs.zsh;
  };

  # プライマリユーザー (nix-darwin 要件)
  system.primaryUser = username;

  # ============================================================
  # システムバージョン
  # ============================================================
  system.stateVersion = 5;
}
