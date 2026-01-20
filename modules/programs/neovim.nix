{ config, pkgs, lib, nvimConfigPath, ... }:

{
  # ============================================================
  # Neovim 設定 (LazyVim 方式)
  # ============================================================
  # LazyVim にプラグイン管理を委譲し、Nix は外部ツールのみ提供
  # これにより設定がシンプルになり、LazyVim の流儀に従った安定動作を実現
  # ============================================================

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # 外部ツール（LSP、フォーマッター等）- Nix で管理
    extraPackages = with pkgs; [
      # LSP サーバー
      nil                     # Nix
      lua-language-server     # Lua
      nodePackages.typescript-language-server  # TypeScript/JavaScript
      nodePackages.vscode-langservers-extracted  # HTML/CSS/JSON
      rust-analyzer           # Rust
      gopls                   # Go
      pyright                 # Python
      haskell-language-server # Haskell
      marksman                # Markdown
      taplo                   # TOML
      elan                    # Lean toolchain manager (Lean 4)

      # フォーマッター
      nixfmt
      stylua
      nodePackages.prettier
      rustfmt
      gofumpt
      black
      isort
      fourmolu
      shfmt

      # リンター
      shellcheck
      hadolint
      statix
      hlint

      # ツール
      ripgrep
      fd
      tree-sitter
      lazygit
      git

      # 画像表示 (image.nvim 用)
      imagemagick
    ];

    # Lua パッケージ (image.nvim 用)
    extraLuaPackages = ps: [ ps.magick ];
  };

  # Lua 設定ファイルをシンボリンク
  xdg.configFile = {
    "nvim" = {
      source = nvimConfigPath;
      recursive = true;
      force = true;
    };
  };

  # ============================================================
  # Helix エディタ (代替)
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
