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
      cleanup = lib.mkDefault "zap";
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
