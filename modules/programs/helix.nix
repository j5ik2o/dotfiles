{ config, pkgs, lib, ... }:

{
  # ============================================================
  # Helix editor (alternative)
  # ============================================================
  programs.helix = {
    enable = true;
    defaultEditor = false;
    settings = {
      theme = "catppuccin_mocha";
      editor = {
        line-number = "relative";
        cursorline = true;
        auto-completion = true;
        auto-format = true;
        idle-timeout = 50;
        completion-trigger-len = 1;
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        file-picker = {
          hidden = false;
        };
        lsp = {
          display-messages = true;
        };
        statusline = {
          left = [ "mode" "spinner" "version-control" ];
          center = [ "file-name" ];
          right = [ "diagnostics" "position" "file-encoding" ];
        };
      };
      keys.normal = {
        space = {
          f = "file_picker";
          b = "buffer_picker";
          s = "symbol_picker";
        };
      };
    };
    languages.language = [
      {
        name = "nix";
        auto-format = true;
        formatter.command = "nixfmt";
      }
      {
        name = "rust";
        auto-format = true;
      }
    ];
  };
}
