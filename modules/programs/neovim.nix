{
  config,
  pkgs,
  lib,
  nvimConfigPath,
  ...
}:

let
  nvimConfigDir = builtins.dirOf (toString nvimConfigPath);
  nvimPath = "${nvimConfigDir}/nvim";
  nvimPlugins = [
    {
      name = "LazyVim";
      pkg = pkgs.vimPlugins.LazyVim;
    }
    {
      name = "blink.cmp";
      pkg = pkgs.vimPlugins.blink-cmp;
    }
    {
      name = "blink-copilot";
      pkg = pkgs.vimPlugins.blink-copilot;
    }
    {
      name = "bufferline.nvim";
      pkg = pkgs.vimPlugins.bufferline-nvim;
    }
    {
      name = "catppuccin";
      pkg = pkgs.vimPlugins.catppuccin-nvim;
    }
    {
      name = "copilot.lua";
      pkg = pkgs.vimPlugins.copilot-lua;
    }
    {
      name = "codecompanion.nvim";
      pkg = pkgs.vimPlugins.codecompanion-nvim;
    }
    {
      name = "conform.nvim";
      pkg = pkgs.vimPlugins.conform-nvim;
    }
    {
      name = "flash.nvim";
      pkg = pkgs.vimPlugins.flash-nvim;
    }
    {
      name = "friendly-snippets";
      pkg = pkgs.vimPlugins.friendly-snippets;
    }
    {
      name = "fzf-lua";
      pkg = pkgs.vimPlugins.fzf-lua;
    }
    {
      name = "gitsigns.nvim";
      pkg = pkgs.vimPlugins.gitsigns-nvim;
    }
    {
      name = "grug-far.nvim";
      pkg = pkgs.vimPlugins.grug-far-nvim;
    }
    {
      name = "lazy.nvim";
      pkg = pkgs.vimPlugins.lazy-nvim;
    }
    {
      name = "lazydev.nvim";
      pkg = pkgs.vimPlugins.lazydev-nvim;
    }
    {
      name = "lualine.nvim";
      pkg = pkgs.vimPlugins.lualine-nvim;
    }
    {
      name = "mason-lspconfig.nvim";
      pkg = pkgs.vimPlugins.mason-lspconfig-nvim;
    }
    {
      name = "mason.nvim";
      pkg = pkgs.vimPlugins.mason-nvim;
    }
    {
      name = "mini.ai";
      pkg = pkgs.vimPlugins.mini-ai;
    }
    {
      name = "mini.icons";
      pkg = pkgs.vimPlugins.mini-icons;
    }
    {
      name = "mini.pairs";
      pkg = pkgs.vimPlugins.mini-pairs;
    }
    {
      name = "neo-tree.nvim";
      pkg = pkgs.vimPlugins.neo-tree-nvim;
    }
    {
      name = "noice.nvim";
      pkg = pkgs.vimPlugins.noice-nvim;
    }
    {
      name = "nui.nvim";
      pkg = pkgs.vimPlugins.nui-nvim;
    }
    {
      name = "nvim-lint";
      pkg = pkgs.vimPlugins.nvim-lint;
    }
    {
      name = "nvim-lspconfig";
      pkg = pkgs.vimPlugins.nvim-lspconfig;
    }
    {
      name = "nvim-jdtls";
      pkg = pkgs.vimPlugins.nvim-jdtls;
    }
    {
      name = "nvim-metals";
      pkg = pkgs.vimPlugins.nvim-metals;
    }
    {
      name = "nvim-treesitter";
      pkg = pkgs.vimPlugins.nvim-treesitter.withPlugins (plugins: [
        plugins.java
        plugins.python
      ]);
    }
    {
      name = "nvim-treesitter-textobjects";
      pkg = pkgs.vimPlugins.nvim-treesitter-textobjects;
    }
    {
      name = "nvim-ts-autotag";
      pkg = pkgs.vimPlugins.nvim-ts-autotag;
    }
    {
      name = "persistence.nvim";
      pkg = pkgs.vimPlugins.persistence-nvim;
    }
    {
      name = "plenary.nvim";
      pkg = pkgs.vimPlugins.plenary-nvim;
    }
    {
      name = "telescope.nvim";
      pkg = pkgs.vimPlugins.telescope-nvim;
    }
    {
      name = "snacks.nvim";
      pkg = pkgs.vimPlugins.snacks-nvim;
    }
    {
      name = "todo-comments.nvim";
      pkg = pkgs.vimPlugins.todo-comments-nvim;
    }
    {
      name = "toggleterm.nvim";
      pkg = pkgs.vimPlugins.toggleterm-nvim;
    }
    {
      name = "tokyonight.nvim";
      pkg = pkgs.vimPlugins.tokyonight-nvim;
    }
    {
      name = "trouble.nvim";
      pkg = pkgs.vimPlugins.trouble-nvim;
    }
    {
      name = "ts-comments.nvim";
      pkg = pkgs.vimPlugins.ts-comments-nvim;
    }
    {
      name = "which-key.nvim";
      pkg = pkgs.vimPlugins.which-key-nvim;
    }
  ];
  nvimPluginDir = pkgs.linkFarm "nvim-plugins" (
    map (plugin: {
      name = plugin.name;
      path = plugin.pkg;
    }) nvimPlugins
  );
in
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
    plugins = map (plugin: plugin.pkg) nvimPlugins;

    # 外部ツール（LSP、フォーマッター等）- Nix で管理
    extraPackages =
      with pkgs;
      [
        # LSP サーバー
        nil # Nix
        lua-language-server # Lua
        nodePackages.typescript-language-server # TypeScript/JavaScript
        nodePackages.vscode-langservers-extracted # HTML/CSS/JSON
        rust-analyzer # Rust
        gopls # Go
        pyright # Python
        haskell-language-server # Haskell
        jdt-language-server # Java
        metals # Scala
      ]
      ++ lib.optionals (!pkgs.stdenv.isDarwin) [
        marksman # Markdown (Darwin は swift ビルドクラッシュ回避のため除外)
      ]
      ++ [
        taplo # TOML
        elan # Lean toolchain manager (Lean 4)
        opam # OCaml package manager (for mason)
        ocamlPackages.ocaml-lsp # OCaml LSP
        cmake # rust-analyzer build scripts (aws-lc-sys)
        gcc-arm-embedded # arm-none-eabi-gcc for no_std targets

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

        # Build tools (Java/Scala)
        gradle
        maven

        # 画像表示 (image.nvim 用)
        imagemagick
      ];

    # Lua パッケージ (image.nvim 用)
    extraLuaPackages = ps: [ ps.magick ];
  };

  home.sessionVariables = {
    NVIM_PLUGIN_DIR = "${config.xdg.dataHome}/nvim-plugins";
  };

  # Lua 設定ファイルをシンボリンク
  xdg.configFile = {
    "nvim" = {
      source = nvimPath;
      recursive = true;
      force = true;
    };
  };

  # Stable path for Nix-managed plugins to avoid hash path churn.
  xdg.dataFile."nvim-plugins".source = nvimPluginDir;

}
