{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}:

{
  imports = [
    ./packages.nix # CLI tools from nixpkgs
    ./homebrew.nix # GUI apps via Homebrew
    ./system-settings.nix # macOS system settings
  ];
  # ============================================================
  # nix-darwin システムレベル設定
  # macOS のシステム設定を Nix で宣言的に管理
  # ============================================================

  # unfree パッケージの許可 (claude-code など)
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];

  # カスタムパッケージの overlay
  nixpkgs.overlays = [
    inputs.nix-clawdbot.overlays.default
    (final: prev: {
      gwq = final.callPackage ../packages/gwq.nix { };
      codex = final.callPackage ../packages/codex.nix { };
      claude-code = final.callPackage ../packages/claude-code.nix { };
      copilot-chat-nvim = final.callPackage ../packages/copilot-chat.nix { };
    })
  ];

  # Nix 設定
  nix = {
    settings = {
      # Flakes を有効化
      experimental-features = [
        "nix-command"
        "flakes"
        "auto-allocate-uids"
      ];

      # 信頼するユーザー
      trusted-users = [
        "root"
        username
      ];

      # バイナリキャッシュ
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

    };

    # ストア最適化
    optimise.automatic = true;

    # ガベージコレクション
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
  };

  # ============================================================
  # ユーザー設定
  # ============================================================
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
    shell = pkgs.zsh;
  };

  # プライマリユーザー (nix-darwin 要件)
  system.primaryUser = username;

  # ============================================================
  # システムバージョン
  # ============================================================
  system.stateVersion = 5;
}
