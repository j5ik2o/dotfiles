{ config, pkgs, lib, username, ... }:

{
  # ============================================================
  # Linux 固有の Home Manager 設定
  # ============================================================

  # home.homeDirectory は flake.nix で設定

  # ============================================================
  # Linux 固有パッケージ
  # ============================================================
  home.packages = with pkgs; [
    # システムモニタリング
    iotop
    iftop
    nethogs
    sysstat

    # ファイルシステム
    ncdu
    duf

    # ネットワーク
    iproute2
    nettools
    traceroute

    # クリップボード (X11/Wayland)
    xclip
    wl-clipboard

    # 通知
    libnotify

    # その他 Linux ツール
    pciutils
    usbutils
    lsof
    strace

    # クラウドストレージ
    dropbox
    dropbox-cli

    # コンテナ
    docker-client
    docker-compose
    docker-buildx
    lazydocker
  ];

  # ============================================================
  # Linux 固有の環境変数
  # ============================================================
  home.sessionVariables = {
    # XDG 設定
    XDG_RUNTIME_DIR = "/run/user/$(id -u)";

    # SSH Agent (systemd user)
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/ssh-agent.socket";
  };

  # ============================================================
  # Linux 固有のシェルエイリアス
  # ============================================================
  home.shellAliases = {
    # クリップボード (X11)
    pbcopy = "xclip -selection clipboard";
    pbpaste = "xclip -selection clipboard -o";

    # クリップボード (Wayland)
    wlcopy = "wl-copy";
    wlpaste = "wl-paste";

    # systemd
    sc = "sudo systemctl";
    scu = "systemctl --user";
    jc = "journalctl";
    jcu = "journalctl --user";

    # パッケージマネージャ (ディストリビューション依存)
    # NixOS の場合は不要

    # ネットワーク
    ports = "ss -tulanp";
    myip = "curl -s https://ipinfo.io/ip";

    # メモリ/CPU
    meminfo = "free -h";
    cpuinfo = "lscpu";
  };

  # ============================================================
  # Linux 固有のサービス設定
  # ============================================================

  # SSH Agent (systemd user service)
  services.ssh-agent.enable = true;

  # GPG Agent
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentryPackage = pkgs.pinentry-curses;
  };

  # Dropbox (自動起動)
  services.dropbox.enable = true;

  # Syncthing (オプション)
  # services.syncthing.enable = true;

  # ============================================================
  # Linux デスクトップ統合 (オプション)
  # ============================================================

  # XDG MIME タイプ
  xdg.mimeApps.enable = true;

  # デスクトップエントリ
  xdg.desktopEntries = {
    # 必要に応じてカスタムデスクトップエントリを追加
  };
}
