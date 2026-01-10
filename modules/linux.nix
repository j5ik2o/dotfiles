{ config, pkgs, lib, username, ... }:

let
  # WSL 検出
  isWSL = builtins.pathExists /proc/sys/fs/binfmt_misc/WSLInterop;
in
{
  # ============================================================
  # Linux 固有の Home Manager 設定
  # WSL の場合は一部設定を上書き
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

  ] ++ lib.optionals (!isWSL) [
    # クリップボード (X11/Wayland) - WSL では Windows 側を使用
    xclip
    wl-clipboard

    # 通知
    libnotify

    # その他 Linux ツール
    pciutils
    usbutils
    lsof
    strace

  ] ++ lib.optionals (!isWSL) [
    # コンテナ - WSL では Docker Desktop を使用
    docker-client
    docker-compose
    docker-buildx
    lazydocker
  ];
  # 注: dropbox/dropbox-cli は unfree パッケージのため削除

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
    # クリップボード
    pbcopy = if isWSL then "clip.exe" else "xclip -selection clipboard";
    pbpaste = if isWSL then "powershell.exe -command 'Get-Clipboard'" else "xclip -selection clipboard -o";

    # クリップボード (Wayland) - WSL では不要
    wlcopy = if isWSL then "clip.exe" else "wl-copy";
    wlpaste = if isWSL then "powershell.exe -command 'Get-Clipboard'" else "wl-paste";

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
    pinentry.package = pkgs.pinentry-curses;
  };

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
