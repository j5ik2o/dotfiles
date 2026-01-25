{ config, lib, ... }:

{
  # ============================================================
  # Catppuccin theme (global)
  # ============================================================
  catppuccin = {
    enable = true;
    flavor = "mocha";
    accent = "mauve";
  };

  # WezTerm needs apply=true to set the active color scheme.
  catppuccin.wezterm.apply = true;

  # Starship is configured via preset in programs/starship.nix.
  catppuccin.starship.enable = false;
}
