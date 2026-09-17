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

      dockerClient = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Install the Docker CLI (client/compose/buildx) from Nix on Linux.
          Disable on hosts that ship their own Docker CLI matched to a
          preinstalled daemon (e.g. DGX OS), where the Nix client would
          shadow it in PATH and diverge in version.
        '';
      };
    };
  };
}
