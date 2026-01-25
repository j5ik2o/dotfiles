{
  config,
  pkgs,
  lib,
  ...
}:

let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  # ============================================================
  # Foot ターミナル設定 (Linux専用 - 軽量Waylandターミナル)
  # ============================================================
  programs.foot = lib.mkIf (!isDarwin) {
    enable = true;

    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=14";
        dpi-aware = "yes";
      };

      mouse = {
        hide-when-typing = "yes";
      };

      colors = {
        # Catppuccin Mocha
        foreground = "cdd6f4";
        background = "1e1e2e";

        # Normal colors
        regular0 = "45475a"; # black
        regular1 = "f38ba8"; # red
        regular2 = "a6e3a1"; # green
        regular3 = "f9e2af"; # yellow
        regular4 = "89b4fa"; # blue
        regular5 = "f5c2e7"; # magenta
        regular6 = "94e2d5"; # cyan
        regular7 = "bac2de"; # white

        # Bright colors
        bright0 = "585b70";
        bright1 = "f38ba8";
        bright2 = "a6e3a1";
        bright3 = "f9e2af";
        bright4 = "89b4fa";
        bright5 = "f5c2e7";
        bright6 = "94e2d5";
        bright7 = "a6adc8";
      };
    };
  };
}
