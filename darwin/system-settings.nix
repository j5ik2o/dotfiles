{
  config,
  pkgs,
  lib,
  ...
}:

{
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
      wvous-bl-corner = 1; # Disabled
      wvous-br-corner = 1; # Disabled
      wvous-tl-corner = 1; # Disabled
      wvous-tr-corner = 1; # Disabled
    };

    # Finder 設定
    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      CreateDesktop = false;
      FXDefaultSearchScope = "SCcf"; # 現在のフォルダを検索
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv"; # リスト表示
      QuitMenuItem = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
    };

    # トラックパッド設定
    trackpad = {
      Clicking = true; # タップでクリック
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };

    # キーボード設定
    NSGlobalDomain = {
      # キーリピート設定 (macOSデフォルト: KeyRepeat=2, InitialKeyRepeat=15)
      # 削除してOSデフォルトに任せる

      # その他
      AppleInterfaceStyle = "Dark"; # ダークモード
      AppleKeyboardUIMode = 3; # フルキーボードアクセス
      ApplePressAndHoldEnabled = false; # キーリピートを有効化
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
  # シェル設定
  # ============================================================
  programs.zsh.enable = true;
  programs.fish.enable = true;
  environment.shells = [
    pkgs.zsh
  ];
}
