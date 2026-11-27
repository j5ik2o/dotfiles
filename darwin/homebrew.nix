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
      # ffmpeg は「CLI は Nix」のルールの例外。動画の音声処理（ElevenLabs の
      # 長さ計測・音量の正規化・書き出し）で手元の ffmpeg を直接叩くため、
      # オペレータの指示で brew に置いている。Nix 側には重複して入れない。
      "ffmpeg"
      "macmon"
      "rtk"
    ];

    # Mac App Store アプリ
    masApps = {
    };
  };
}
