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

  # Meta の Muse は Homebrew cask が期限付き署名 URL を指すため使えない。
  home.activation.updateMuse = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # activation の各エントリは1つのスクリプトに展開される。ここでの exit と
    # 失敗の終了コードが後続のエントリを止めないよう、サブシェルに閉じ込める。
    (
    _muse_app="$HOME/Applications/Muse.app"

    _muse_installed=""
    if [ -d "$_muse_app" ]; then
      _muse_installed=$(/usr/bin/defaults read "$_muse_app/Contents/Info" CFBundleShortVersionString 2>/dev/null || true)
    fi

    if ! _muse_tmp=$(mktemp -d); then
      echo "WARNING: Muse tmpdir creation failed" >&2
      exit 0
    fi
    _muse_mounted=0
    _muse_cleanup() {
      if [ "$_muse_mounted" -eq 1 ]; then
        /usr/bin/hdiutil detach "$_muse_tmp/mnt" >/dev/null 2>&1 || true
      fi
      rm -rf "$_muse_tmp"
      rm -rf "$HOME/Applications/.Muse-staging"
    }
    trap _muse_cleanup EXIT

    # 素の curl は DMG リンクを含まない HTML を返し、UA だけでも 400 になる。
    _muse_page="$_muse_tmp/page.html"
    if ! ${pkgs.curl}/bin/curl -fsSL --connect-timeout 10 --max-time 60 \
      -A 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36' \
      -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' \
      -H 'Accept-Language: en-US,en;q=0.9' \
      -H 'sec-ch-ua: "Chromium";v="141", "Not?A_Brand";v="24"' \
      -H 'sec-ch-ua-mobile: ?0' \
      -H 'sec-ch-ua-platform: "macOS"' \
      -H 'Sec-Fetch-Dest: document' \
      -H 'Sec-Fetch-Mode: navigate' \
      -H 'Sec-Fetch-Site: none' \
      -H 'Sec-Fetch-User: ?1' \
      -H 'Upgrade-Insecure-Requests: 1' \
      -o "$_muse_page" \
      'https://ai.meta.com/muse/download/'; then
      echo "WARNING: Muse download page fetch failed" >&2
      exit 0
    fi

    _muse_url=$(/usr/bin/sed 's#\\/#/#g' "$_muse_page" | /usr/bin/grep -oE 'https://[^"]+\.dmg\?[^"]+' | head -1 || true)
    if [ -z "$_muse_url" ]; then
      echo "WARNING: Muse DMG link not found" >&2
      exit 0
    fi

    _muse_path=$(printf '%s\n' "$_muse_url" | /usr/bin/sed 's/?.*$//')
    _muse_available=$(/usr/bin/basename "$_muse_path" | /usr/bin/sed 's/^Muse-//; s/\.dmg$//')
    if [ -z "$_muse_available" ]; then
      echo "WARNING: Muse version parse failed" >&2
      exit 0
    fi

    # 配布ページが古い DMG を指したときにダウングレードしない。
    if [ -n "$_muse_installed" ] && \
      [ "$(printf '%s\n%s\n' "$_muse_installed" "$_muse_available" | ${pkgs.coreutils}/bin/sort -V | tail -n 1)" = "$_muse_installed" ]; then
      echo "Muse $_muse_installed is up to date"
      exit 0
    fi

    # 署名付きクエリを落とすと CDN が 403 を返すため、URL はそのまま使う。
    _muse_dmg="$_muse_tmp/Muse.dmg"
    if ! ${pkgs.curl}/bin/curl -fsSL --connect-timeout 10 --max-time 600 -o "$_muse_dmg" "$_muse_url"; then
      echo "WARNING: Muse DMG download failed" >&2
      exit 0
    fi

    mkdir -p "$_muse_tmp/mnt"
    if ! /usr/bin/hdiutil attach -nobrowse -readonly -mountpoint "$_muse_tmp/mnt" "$_muse_dmg" >/dev/null; then
      echo "WARNING: Muse DMG mount failed" >&2
      exit 0
    fi
    _muse_mounted=1

    mkdir -p "$HOME/Applications"
    # codesign はディレクトリ名が Muse.app でないと署名を検出しないため、
    # 隠しディレクトリの中に Muse.app という名前で展開する。
    _muse_stage_dir="$HOME/Applications/.Muse-staging"
    _muse_staging="$_muse_stage_dir/Muse.app"
    rm -rf "$_muse_stage_dir"
    mkdir -p "$_muse_stage_dir"
    if ! /usr/bin/ditto "$_muse_tmp/mnt/Muse.app" "$_muse_staging"; then
      echo "WARNING: Muse copy failed" >&2
      exit 0
    fi

    if ! /usr/bin/codesign --verify --deep --strict "$_muse_staging" >/dev/null 2>&1; then
      echo "WARNING: Muse signature verification failed" >&2
      exit 0
    fi
    if [ "$(/usr/bin/codesign -dv --verbose=2 "$_muse_staging" 2>&1 | /usr/bin/sed -n 's/^TeamIdentifier=//p')" != "V9WTTPBFK9" ]; then
      echo "WARNING: Muse team identifier mismatch" >&2
      exit 0
    fi

    _muse_old="$HOME/Applications/.Muse.app.old"
    rm -rf "$_muse_old"
    if [ -d "$_muse_app" ] && ! /bin/mv "$_muse_app" "$_muse_old"; then
      echo "WARNING: Muse backup failed" >&2
      exit 0
    fi
    if ! /bin/mv "$_muse_staging" "$_muse_app"; then
      if [ -d "$_muse_old" ]; then
        /bin/mv "$_muse_old" "$_muse_app" || true
      fi
      echo "WARNING: Muse install failed" >&2
      exit 0
    fi
    rm -rf "$_muse_old"

    echo "Muse $_muse_available installed"
    ) || true
  '';

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
