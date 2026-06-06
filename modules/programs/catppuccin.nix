{ config, lib, ... }:

{
  # ============================================================
  # Catppuccin theme (global)
  # ============================================================
  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
    accent = "mauve";
  };

  # WezTerm needs apply=true to set the active color scheme.
  catppuccin.wezterm.apply = true;

  # Neovim theme/plugin loading is managed in modules/programs/neovim.nix.
  catppuccin.nvim.enable = false;

  # Starship is configured via preset in programs/starship.nix.
  catppuccin.starship.enable = false;
}
