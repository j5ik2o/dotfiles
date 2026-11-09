{
  config,
  pkgs,
  lib,
  username,
  inputs,
  ...
}:

let
  # 上流 flake のパッケージ。署名済みの OpenBot.app をそのまま含む。
  # Nix ストアのアプリは自己更新しないため、更新は make update (flake input) で行う。
  openbot = inputs.openbot.packages.${pkgs.stdenv.hostPlatform.system}.openbot;
in

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
    m-cli # macOS コマンドラインツール
    mas # Mac App Store CLI
    macpm # Apple Silicon パフォーマンスモニタ (旧 asitop)

    # Android 端末の画面ミラーリング / 操作
    scrcpy
    android-tools # adb (scrcpy の接続に必要)

    # AI エージェント用デスクトップアプリ
    openbot
  ];

  # home.packages に含まれる .app を ~/Applications/Home Manager Apps へコピーする。
  # linkApps は Nix ストアへの symlink を作るだけで Spotlight から見えないため使わない。
  # 初回は App Management 権限の許可を求められ、実体コピー分のディスクを使う。
  targets.darwin.linkApps.enable = false;
  targets.darwin.copyApps.enable = true;

  # ============================================================
  # macOS 固有の GUI アプリ (Nix 管理)
  # ============================================================

  # DS Bot デスクトップアプリ。Homebrew cask が無いため GitHub Releases の
  # 配布物をハッシュ固定で取得し、~/Applications にリンクする。
  # DS Bot の DSH プラグイン側は dsh-tui (packages/dsh-tui.nix) の web プロファイルで動く。
  home.file."Applications/DS Bot.app".source = "${pkgs.ds-bot-app}/Applications/DS Bot.app";

  # ============================================================
  # macOS 固有の環境変数
  # ============================================================
  home.sessionVariables = {
    # Homebrew (Apple Silicon)
    HOMEBREW_PREFIX = "/opt/homebrew";
    HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
    HOMEBREW_REPOSITORY = "/opt/homebrew";
  };

  # Homebrew PATH を追加 (Apple Silicon)
  home.sessionPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

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
