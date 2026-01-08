{ config, pkgs, lib, username, ... }:

{
  # ============================================================
  # macOS 固有の Home Manager 設定
  # ============================================================

  imports = [
    ./programs/wezterm.nix
    ./programs/ghostty.nix
  ];

  # home.homeDirectory は flake.nix で設定

  # ============================================================
  # macOS 固有パッケージ
  # ============================================================
  home.packages = with pkgs; [
    # macOS ユーティリティ
    coreutils
    gnused
    gawk
    gnugrep
    findutils

    # クリップボード連携
    # (pbcopy/pbpaste は macOS 標準)

    # macOS 固有ツール
    m-cli  # macOS コマンドラインツール
    mas    # Mac App Store CLI
  ];

  # ============================================================
  # macOS 固有の環境変数
  # ============================================================
  home.sessionVariables = {
    # Homebrew (Apple Silicon)
    HOMEBREW_PREFIX = "/opt/homebrew";
    # macOS 固有の PATH 追加
  };

  # ============================================================
  # macOS 固有のシェルエイリアス
  # ============================================================
  home.shellAliases = {
    # クリップボード
    pbp = "pbpaste";
    pbc = "pbcopy";

    # Finder
    showfiles = "defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder";
    hidefiles = "defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder";

    # DNS キャッシュクリア
    flushdns = "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder";

    # Quick Look
    ql = "qlmanage -p";

    # macOS アップデート
    update = "softwareupdate -ia --verbose";

    # ゴミ箱を空に
    emptytrash = "sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; sudo rm -rfv /private/var/log/asl/*.asl";
  };

  # ============================================================
  # macOS 固有のプログラム設定
  # ============================================================

  # macOS では launchd による自動起動
  # (services は nix-darwin で管理するため、ここでは設定しない)
}
