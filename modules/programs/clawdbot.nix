{
  config,
  lib,
  pkgs,
  ...
}:

{
  # ============================================================
  # Clawdbot 設定
  # ============================================================
  programs.clawdbot = {
    enable = true;
    # Avoid toolchain bundle conflicts (node/git/etc) with home.packages.
    package = pkgs.clawdbot-gateway;
    instances.default = {
      enable = true;
      launchd.label = "com.steipete.clawdbot.gateway";
      systemd.unitName = "clawdbot-gateway";
    };
  } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    appPackage = pkgs.clawdbot-app;
    installApp = true;
  };
}
