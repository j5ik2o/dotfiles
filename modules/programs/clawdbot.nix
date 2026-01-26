{
  config,
  lib,
  pkgs,
  ...
}:

{
  # ============================================================
  # Clawdbot 設定 (macOS / Linux 共通)
  # ============================================================
  programs.clawdbot = lib.mkMerge [
    {
      enable = true;
      # Avoid toolchain bundle conflicts (node/git/etc) with home.packages.
      package = pkgs.clawdbot-gateway;
      instances.default = {
        enable = true;
        launchd.label = "com.steipete.clawdbot.gateway";
        systemd.unitName = "clawdbot-gateway";
      };
    }
    (lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      appPackage = pkgs.clawdbot-app;
      installApp = true;
      systemd.enable = false;
    })
    (lib.optionalAttrs (!pkgs.stdenv.hostPlatform.isDarwin) {
      appPackage = null;
      installApp = false;
      launchd.enable = false;
    })
  ];
}
