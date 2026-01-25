{
  config,
  pkgs,
  lib,
  username,
  ...
}:

let
  # ユーザー名からhomebrew設定ファイル名を決定
  # ドットをアンダースコアに変換（Nixファイルパス互換性のため）
  safeUsername = builtins.replaceStrings [ "." ] [ "_" ] username;
  homebrewConfigFile = ./homebrew/${safeUsername}.nix;
  homebrewCleanup = if username == "ex_j.kato" || username == "ex_j_kato" then "none" else "zap";
in
{
  imports = [
    homebrewConfigFile
  ];

  # ============================================================
  # Homebrew 統合 (Cask アプリケーション用)
  # casks はユーザーごとに darwin/homebrew/<username>.nix で定義
  # ============================================================
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = homebrewCleanup;
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
