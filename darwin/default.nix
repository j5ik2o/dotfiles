{
  pkgs,
  lib,
  config,
  inputs,
  username,
  expectedHostName ? null, # flake.nix から渡される期待ホスト名
  ...
}:

{
  imports = [
    ./packages.nix # CLI tools from nixpkgs
    ./homebrew.nix # Homebrew 共通設定
    ./system-settings.nix # macOS system settings
  ];

  # ============================================================
  # ホスト名ガード：間違ったホストで実行されることを防ぐ
  # system activation時にホスト名をチェック
  # ============================================================
  system.activationScripts.preActivation.text = lib.optionalString (expectedHostName != null) ''
    echo "🔍 ホスト名チェック中..."
    # darwin-rebuild は LocalHostName を使用するため、同じ順序で取得
    ACTUAL_HOST_RAW=$(scutil --get LocalHostName 2>/dev/null || scutil --get HostName 2>/dev/null || scutil --get ComputerName 2>/dev/null || hostname)
    EXPECTED_HOST_RAW="${expectedHostName}"

    if [ "$ACTUAL_HOST_RAW" != "$EXPECTED_HOST_RAW" ]; then
      echo ""
      echo "❌ ホスト名が一致しません！"
      echo ""
      echo "   期待されるホスト: $EXPECTED_HOST_RAW"
      echo "   実際のホスト名:   $ACTUAL_HOST_RAW"
      echo ""
      echo "このNix設定は '$EXPECTED_HOST_RAW' 用です。"
      echo "現在のホスト '$ACTUAL_HOST_RAW' では実行できません。"
      echo ""
      echo "正しい設定を使用するか、hosts/$ACTUAL_HOST_RAW.nix を作成してください。"
      echo ""
      exit 1
    fi
    echo "✅ ホスト名チェック完了: $ACTUAL_HOST_RAW"
  '';

  # ============================================================
  # nix-darwin システムレベル設定
  # macOS のシステム設定を Nix で宣言的に管理
  # ============================================================

  # unfree パッケージの許可 (claude-code など)
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "coderabbit"
    ];

  # カスタムパッケージの overlay
  # takt, codex, claude-code は mise.toml で管理
  nixpkgs.overlays = [
    inputs.nix-clawdbot.overlays.default
    (final: prev: {
      gwq = final.callPackage ../packages/gwq.nix { };
      cliproxyapi = final.callPackage ../packages/cliproxyapi.nix { };
      coderabbit = final.callPackage ../packages/coderabbit.nix { };
      copilot-chat-nvim = final.callPackage ../packages/copilot-chat.nix { };
      # macOS で test_scan_invalid_rule_id が "Illegal byte sequence (os error 92)" で失敗するためテストをスキップ
      ast-grep = prev.ast-grep.overrideAttrs (_: {
        doCheck = false;
      });
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
