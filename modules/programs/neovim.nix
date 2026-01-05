{ config, pkgs, lib, ... }:

{
  # ============================================================
  # Neovim 設定
  # ============================================================
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # 追加パッケージ
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
      nixfmt-classic
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
    ];

    # プラグイン設定
    plugins = with pkgs.vimPlugins; [
      # パッケージマネージャ (lazy.nvim は手動設定を推奨)

      # カラースキーム
      {
        plugin = catppuccin-nvim;
        type = "lua";
        config = ''
          require("catppuccin").setup({
            flavour = "mocha",
            transparent_background = true,
            integrations = {
              cmp = true,
              gitsigns = true,
              nvimtree = true,
              telescope = true,
              treesitter = true,
              which_key = true,
            },
          })
          vim.cmd.colorscheme "catppuccin"
        '';
      }

      # ファイルエクスプローラー
      {
        plugin = nvim-tree-lua;
        type = "lua";
        config = ''
          require("nvim-tree").setup({
            view = { width = 30 },
            renderer = { icons = { show = { git = true } } },
            filters = { dotfiles = false },
          })
          vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true })
        '';
      }
      nvim-web-devicons

      # ファジーファインダー
      {
        plugin = telescope-nvim;
        type = "lua";
        config = ''
          local telescope = require("telescope")
          telescope.setup({
            defaults = {
              file_ignore_patterns = { "node_modules", ".git/" },
              mappings = {
                i = {
                  ["<C-j>"] = "move_selection_next",
                  ["<C-k>"] = "move_selection_previous",
                },
              },
            },
          })
          local builtin = require("telescope.builtin")
          vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
          vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
          vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
          vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})
        '';
      }
      telescope-fzf-native-nvim
      plenary-nvim

      # シンタックスハイライト (Nix で grammars はプリビルド済み)
      nvim-treesitter.withAllGrammars

      # LSP (nvim-lspconfig は補助的に使用)
      nvim-lspconfig

      # 補完
      {
        plugin = nvim-cmp;
        type = "lua";
        config = ''
          local cmp = require("cmp")
          local luasnip = require("luasnip")

          cmp.setup({
            snippet = {
              expand = function(args)
                luasnip.lsp_expand(args.body)
              end,
            },
            mapping = cmp.mapping.preset.insert({
              ["<C-b>"] = cmp.mapping.scroll_docs(-4),
              ["<C-f>"] = cmp.mapping.scroll_docs(4),
              ["<C-Space>"] = cmp.mapping.complete(),
              ["<C-e>"] = cmp.mapping.abort(),
              ["<CR>"] = cmp.mapping.confirm({ select = true }),
              ["<Tab>"] = cmp.mapping.select_next_item(),
              ["<S-Tab>"] = cmp.mapping.select_prev_item(),
            }),
            sources = cmp.config.sources({
              { name = "nvim_lsp" },
              { name = "luasnip" },
              { name = "buffer" },
              { name = "path" },
            }),
          })
        '';
      }
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      luasnip
      cmp_luasnip

      # Git 統合
      {
        plugin = gitsigns-nvim;
        type = "lua";
        config = ''
          require("gitsigns").setup({
            signs = {
              add = { text = "│" },
              change = { text = "│" },
              delete = { text = "_" },
              topdelete = { text = "‾" },
              changedelete = { text = "~" },
            },
          })
        '';
      }

      # ステータスライン
      {
        plugin = lualine-nvim;
        type = "lua";
        config = ''
          require("lualine").setup({
            options = {
              theme = "catppuccin",
              component_separators = { left = "", right = "" },
              section_separators = { left = "", right = "" },
            },
          })
        '';
      }

      # インデントガイド
      {
        plugin = indent-blankline-nvim;
        type = "lua";
        config = ''
          require("ibl").setup({
            indent = { char = "│" },
            scope = { enabled = true },
          })
        '';
      }

      # コメント
      {
        plugin = comment-nvim;
        type = "lua";
        config = ''require("Comment").setup()'';
      }

      # ペア括弧
      {
        plugin = nvim-autopairs;
        type = "lua";
        config = ''require("nvim-autopairs").setup({})'';
      }

      # サラウンド
      {
        plugin = nvim-surround;
        type = "lua";
        config = ''require("nvim-surround").setup({})'';
      }

      # キーマップヘルプ
      {
        plugin = which-key-nvim;
        type = "lua";
        config = ''require("which-key").setup({})'';
      }

      # ターミナル
      {
        plugin = toggleterm-nvim;
        type = "lua";
        config = ''
          require("toggleterm").setup({
            open_mapping = [[<C-\>]],
            direction = "float",
            float_opts = { border = "rounded" },
          })
        '';
      }
    ];

    # 基本設定 (init.lua)
    extraLuaConfig = ''
      -- リーダーキー
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      -- 基本オプション
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.mouse = "a"
      vim.opt.showmode = false
      vim.opt.clipboard = "unnamedplus"
      vim.opt.breakindent = true
      vim.opt.undofile = true
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.signcolumn = "yes"
      vim.opt.updatetime = 250
      vim.opt.timeoutlen = 300
      vim.opt.splitright = true
      vim.opt.splitbelow = true
      vim.opt.list = true
      vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
      vim.opt.inccommand = "split"
      vim.opt.cursorline = true
      vim.opt.scrolloff = 10

      -- インデント
      vim.opt.expandtab = true
      vim.opt.shiftwidth = 2
      vim.opt.tabstop = 2
      vim.opt.softtabstop = 2
      vim.opt.smartindent = true

      -- 検索
      vim.opt.hlsearch = true
      vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

      -- ウィンドウ移動
      vim.keymap.set("n", "<C-h>", "<C-w><C-h>")
      vim.keymap.set("n", "<C-l>", "<C-w><C-l>")
      vim.keymap.set("n", "<C-j>", "<C-w><C-j>")
      vim.keymap.set("n", "<C-k>", "<C-w><C-k>")

      -- バッファ操作
      vim.keymap.set("n", "<leader>bn", ":bnext<CR>", { silent = true })
      vim.keymap.set("n", "<leader>bp", ":bprevious<CR>", { silent = true })
      vim.keymap.set("n", "<leader>bd", ":bdelete<CR>", { silent = true })

      -- 保存・終了
      vim.keymap.set("n", "<leader>w", ":w<CR>", { silent = true })
      vim.keymap.set("n", "<leader>q", ":q<CR>", { silent = true })
      vim.keymap.set("n", "<leader>Q", ":qa!<CR>", { silent = true })

      -- 行移動 (Visual mode)
      vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { silent = true })
      vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { silent = true })

      -- 診断表示
      vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
      vim.keymap.set("n", "]d", vim.diagnostic.goto_next)
      vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float)

      -- Treesitter (Nix でプリビルド済みなので有効化のみ)
      vim.opt.foldmethod = "expr"
      vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
      vim.opt.foldenable = false  -- 起動時は折りたたまない

      -- LSP 設定 (Neovim 0.11+ の新 API)
      vim.lsp.config('nil_ls', {})
      vim.lsp.config('lua_ls', {
        settings = {
          Lua = {
            diagnostics = { globals = { 'vim' } },
          },
        },
      })
      vim.lsp.config('ts_ls', {})
      vim.lsp.config('rust_analyzer', {})
      vim.lsp.config('gopls', {})
      vim.lsp.config('pyright', {})

      -- LSP を有効化
      vim.lsp.enable({ 'nil_ls', 'lua_ls', 'ts_ls', 'rust_analyzer', 'gopls', 'pyright' })

      -- LSP キーマッピング
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, {})
      vim.keymap.set("n", "gr", vim.lsp.buf.references, {})
      vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, {})
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {})
    '';
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
