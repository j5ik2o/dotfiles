{
  config,
  lib,
  pkgs,
  self,
  ...
}:

{
  # ============================================================
  # Clawdbot 設定 (macOS / Linux 共通)
  # ============================================================
  config = lib.mkIf config.dotfiles.features.clawdbot {
    programs.clawdbot = lib.mkMerge [
      {
        enable = true;
        # Avoid toolchain bundle conflicts (node/git/etc) with home.packages.
        package = pkgs.clawdbot-gateway;
        instances.default = {
          enable = true;
          launchd.label = "com.steipete.clawdbot.gateway";
          systemd.unitName = "clawdbot-gateway";
          # Enable memory plugin provided via ~/.config/clawdbot/extensions.
          configOverrides = {
            plugins = {
              slots = {
                memory = "memory-core";
              };
            };
          };
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
        # macOS-only tools in nix-steipete-tools
        excludeTools = [
          "peekaboo"
          "summarize"
        ];
        # macOS-only first-party plugins
        firstParty = {
          peekaboo.enable = false;
          summarize.enable = false;
        };
      })
    ];

    home.file = {
      ".clawdbot/extensions/memory-core/index.mjs".source =
        "${self}/config/clawdbot/extensions/memory-core/index.mjs";
      ".clawdbot/extensions/memory-core/clawdbot.plugin.json".source =
        "${self}/config/clawdbot/extensions/memory-core/clawdbot.plugin.json";
    };
  };
}
