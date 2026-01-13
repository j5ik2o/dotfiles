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

  imports = [
    ./programs/ghostty.nix
    ./programs/wezterm.nix
    ./programs/foot.nix
  ];

  # home.homeDirectory は flake.nix で設定

  # ============================================================
  # フォント設定
  # ============================================================
  fonts.fontconfig.enable = true;

  # ============================================================
  # Linux 固有パッケージ
  # ============================================================
  home.packages = with pkgs; [
    # Nerd Fonts
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.meslo-lg

    # 日本語フォント
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif

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

    # OpenGL/EGL (ターミナル用)
    mesa
    libGL

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
  # デフォルトシェル (Nix 管理の zsh)
  # ============================================================
  home.activation = lib.mkIf config.programs.zsh.enable {
    setDefaultShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      desired_shell="${config.home.profileDirectory}/bin/zsh"
      if [ ! -x "$desired_shell" ]; then
        desired_shell="${lib.getExe config.programs.zsh.package}"
      fi

      if [ -x "$desired_shell" ]; then
        username="''${USER:-$(id -un)}"
        current_shell=""
        if command -v getent >/dev/null 2>&1; then
          current_shell="$(getent passwd "$username" 2>/dev/null | awk -F: '{print $7}' || true)"
        else
          current_shell="$(awk -F: -v u="$username" '$1==u {print $7}' /etc/passwd 2>/dev/null || true)"
        fi

        if [ "$current_shell" != "$desired_shell" ]; then
          failed=0
          if [ -f /etc/shells ] && ! grep -qx "$desired_shell" /etc/shells 2>/dev/null; then
            if [ -w /etc/shells ]; then
              echo "$desired_shell" >> /etc/shells
            elif command -v sudo >/dev/null 2>&1; then
              if ! sudo sh -c 'echo "$1" >> /etc/shells' sh "$desired_shell"; then
                failed=1
              fi
            else
              failed=1
            fi
          fi

          if command -v chsh >/dev/null 2>&1; then
            if ! chsh -s "$desired_shell"; then
              if command -v sudo >/dev/null 2>&1; then
                if ! sudo chsh -s "$desired_shell" "$username"; then
                  failed=1
                fi
              else
                failed=1
              fi
            fi
          else
            failed=1
          fi

          if [ "$failed" -ne 0 ]; then
            echo "home-manager: failed to set login shell to $desired_shell" >&2
            echo "home-manager: run the following once:" >&2
            echo "  sudo sh -c \"echo $desired_shell >> /etc/shells\"" >&2
            echo "  chsh -s $desired_shell" >&2
          fi
        fi
      else
        echo "home-manager: zsh not found at $desired_shell" >&2
      fi
    '';
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
