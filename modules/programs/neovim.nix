{ config, pkgs, lib, nvimConfigPath, ... }:

let
  # 設定ファイルのパス（flake.nixから渡される）
  nvimLuaConfigPath = nvimConfigPath + "/lua/config";
  nvimLuaPluginsPath = nvimConfigPath + "/lua/plugins";

  # lazy-nix-helper をビルド
  lazy-nix-helper = pkgs.vimUtils.buildVimPlugin {
    name = "lazy-nix-helper.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "b-src";
      repo = "lazy-nix-helper.nvim";
      rev = "v0.5.0";
      sha256 = "sha256-Vn/3nBqITAJd+l7cPe7LSKBwc7k6Kc0rs7dXwqQVh10=";
    };
  };

  # image.nvim をビルド (ターミナルで画像表示)
  image-nvim = pkgs.vimUtils.buildVimPlugin {
    pname = "image.nvim";
    version = "2025-01-10";
    src = pkgs.fetchFromGitHub {
      owner = "3rd";
      repo = "image.nvim";
      rev = "446a8a5cc7a3eae3185ee0c697732c32a5547a0b";
      sha256 = "sha256-EaDeY8aP41xHTw5epqYjaBqPYs6Z2DABzSaVOnG6D6I=";
    };
    nvimSkipModule = [ "minimal-setup" ];
  };

  # プラグインリスト
  plugins = (with pkgs.vimPlugins; [
    # プラグインマネージャー
    lazy-nvim

    # カラースキーム
    catppuccin-nvim

    # ファイルエクスプローラー
    neo-tree-nvim
    nvim-web-devicons
    nui-nvim

    # ファジーファインダー
    telescope-nvim
    telescope-fzf-native-nvim
    plenary-nvim

    # シンタックスハイライト
    nvim-treesitter.withAllGrammars

    # LSP
    nvim-lspconfig

    # 補完
    nvim-cmp
    cmp-nvim-lsp
    cmp-buffer
    cmp-path
    luasnip
    cmp_luasnip
    friendly-snippets

    # Git
    gitsigns-nvim
    diffview-nvim

    # UI
    lualine-nvim
    bufferline-nvim
    indent-blankline-nvim
    noice-nvim
    nui-nvim
    edgy-nvim

    # エディタ機能
    comment-nvim
    nvim-autopairs
    nvim-surround
    which-key-nvim
    flash-nvim
    trouble-nvim
    todo-comments-nvim

    # ターミナル
    toggleterm-nvim

    # 通知
    nvim-notify

    # Rust
    crates-nvim
  ]) ++ [
    # 画像表示
    image-nvim
  ];

  # プラグイン名をサニタイズ（Nixのpname prefixを除去）
  sanitizeName = name:
    let
      # "vimPlugins." などのプレフィックスを除去
      baseName = builtins.baseNameOf name;
    in
      builtins.replaceStrings [ "vimplugin-" ] [ "" ] baseName;

  # プラグインテーブルを生成（Luaの形式）
  pluginTable = lib.strings.concatMapStringsSep ",\n    "
    (plugin: ''["${sanitizeName plugin.pname or plugin.name}"] = "${plugin}"'')
    plugins;

  # lazy-nix-helper のパス
  lazyNixHelperPath = "${lazy-nix-helper}";

in {
  # ============================================================
  # Neovim 設定 (lazy-nix-helper 方式)
  # ============================================================
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # 外部ツール（LSP、フォーマッター等）
    extraPackages = with pkgs; [
      # LSP サーバー
      nil                     # Nix
      lua-language-server     # Lua
      nodePackages.typescript-language-server  # TypeScript/JavaScript
      nodePackages.vscode-langservers-extracted  # HTML/CSS/JSON
      rust-analyzer           # Rust
      gopls                   # Go
      pyright                 # Python
      marksman                # Markdown

      # フォーマッター
      nixfmt
      stylua
      nodePackages.prettier
      rustfmt
      gofumpt
      black
      isort

      # リンター
      shellcheck
      hadolint
      statix

      # ツール
      ripgrep
      fd
      tree-sitter

      # 画像表示
      imagemagick
    ];

    # プラグインは Nix でインストールするが、設定は lazy.nvim 経由
    plugins = plugins ++ [ lazy-nix-helper image-nvim ];

    # Lua パッケージ (image.nvim 用)
    extraLuaPackages = ps: [ ps.magick ];

    # 初期化スクリプト（プラグインテーブルを注入）
    extraLuaConfig = ''
      -- Nix が生成したプラグインテーブル
      local nix_plugins = {
        ${pluginTable}
      }

      -- lazy-nix-helper のパス
      local lazy_nix_helper_path = "${lazyNixHelperPath}"

      -- lazy-nix-helper をロード
      vim.opt.rtp:prepend(lazy_nix_helper_path)

      require("lazy-nix-helper").setup({
        lazypath = nix_plugins["lazy.nvim"],
        input_plugin_table = nix_plugins,
      })

      -- 設定ファイルを読み込み
      require("config.options")
      require("config.keymaps")
      require("config.autocmds")

      -- lazy.nvim をセットアップ
      local lazypath = require("lazy-nix-helper").lazypath()
      vim.opt.rtp:prepend(lazypath)

      require("lazy").setup({
        spec = {
          { import = "plugins" },
        },
        defaults = {
          lazy = true,
        },
        install = {
          -- Nix で管理するのでインストール無効
          missing = false,
        },
        checker = {
          -- アップデートチェック無効
          enabled = false,
        },
        change_detection = {
          enabled = false,
        },
        performance = {
          rtp = {
            disabled_plugins = {
              "gzip",
              "matchit",
              "matchparen",
              "netrwPlugin",
              "tarPlugin",
              "tohtml",
              "tutor",
              "zipPlugin",
            },
          },
        },
      })
    '';
  };

  # Lua 設定ファイルをシンボリンク
  xdg.configFile = {
    "nvim/lua/config" = {
      source = nvimLuaConfigPath;
      recursive = true;
    };
    "nvim/lua/plugins" = {
      source = nvimLuaPluginsPath;
      recursive = true;
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
