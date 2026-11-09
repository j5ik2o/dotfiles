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
      "macmon"
      "rtk"
    ];

    # Mac App Store アプリ
    masApps = {
      # Meta の Muse。Homebrew の cask "muse" は署名付き URL が必要なため
      # 2026-10-01 に無効化されているので、App Store 版を入れる。
      # インストールには Mac App Store へのサインインが必要。
      "Muse from Meta" = 6760173601;
    };
  };
}
