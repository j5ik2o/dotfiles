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
      upgrade = true;
    };

    # Homebrew taps
    taps = [
    ];

    # CLI ツール (Nix にないもの)
    brews = [
    ];

    # Mac App Store アプリ
    masApps = {
    };
  };
}
