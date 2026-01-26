{
  config,
  lib,
  pkgs,
  ...
}:

{
  # ============================================================
  # Clawdbot 設定 (macOS のみ)
  # ============================================================
  programs.clawdbot = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    # Avoid toolchain bundle conflicts (node/git/etc) with home.packages.
    package = pkgs.clawdbot-gateway;
    appPackage = pkgs.clawdbot-app;
    installApp = true;
    instances.default = {
      enable = true;
      launchd.label = "com.steipete.clawdbot.gateway";
    };
  };
}
