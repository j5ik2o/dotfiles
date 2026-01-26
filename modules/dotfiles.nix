{ lib, ... }:

{
  options.dotfiles = {
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Dotfiles host name identifier.";
    };

    features = {
      clawdbot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Clawdbot on this host.";
      };
    };
  };
}
