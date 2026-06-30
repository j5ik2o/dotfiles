{ lib, ... }:

{
  # ============================================================
  # Homebrew 共通設定
  # casks はホストごとに darwin/hosts/<hostname>.nix で定義
  # ============================================================
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      # "zap" は Brewfile に無いパッケージを全削除するため危険
      # "none" = 何もしない, "uninstall" = formulae のみ削除, "zap" = 全削除
      cleanup = lib.mkDefault "none";
      # GUI cask の更新は .app の置き換えで macOS 権限状態が揺れやすいため、make apply では行わない。
      upgrade = false;
      extraFlags = [ "--verbose" ];
    };

    # Homebrew taps
    taps = [
      "manaflow-ai/cmux"
    ];

    # CLI ツール (Nix にないもの)
    brews = [
      "rtk"
    ];

    # Mac App Store アプリ
    masApps = {
    };
  };
}
