-- ============================================================
-- LazyVim Configuration
-- ============================================================
-- LazyVim core + extras で構成
-- カスタマイズは最小限に抑え、LazyVim のデフォルトを活かす
-- ============================================================

require("lazy").setup({
  spec = {
    -- LazyVim core
    {
      "LazyVim/LazyVim",
      import = "lazyvim.plugins",
      opts = {
        colorscheme = "catppuccin",
      },
    },

    -- ============================================================
    -- Language Support (extras.lang.*)
    -- ============================================================
    { import = "lazyvim.plugins.extras.lang.rust" },
    { import = "lazyvim.plugins.extras.lang.go" },
    { import = "lazyvim.plugins.extras.lang.typescript" },
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.lang.yaml" },
    { import = "lazyvim.plugins.extras.lang.toml" },
    { import = "lazyvim.plugins.extras.lang.nix" },

    -- ============================================================
    -- UI (extras.ui.*)
    -- edgy must be loaded BEFORE outline
    -- ============================================================
    { import = "lazyvim.plugins.extras.ui.edgy" },

    -- ============================================================
    -- Editor Features (extras.editor.*)
    -- neo-tree is included in LazyVim core by default
    -- ============================================================
    { import = "lazyvim.plugins.extras.editor.outline" },

    -- ============================================================
    -- Coding (extras.coding.*)
    -- ============================================================
    { import = "lazyvim.plugins.extras.coding.luasnip" },

    -- ============================================================
    -- Colorscheme (catppuccin)
    -- ============================================================
    {
      "catppuccin/nvim",
      name = "catppuccin",
      priority = 1000,
      opts = {
        flavour = "mocha",
        integrations = {
          cmp = true,
          gitsigns = true,
          nvimtree = true,
          treesitter = true,
          notify = true,
          mini = true,
          native_lsp = {
            enabled = true,
          },
        },
      },
    },

    -- ============================================================
    -- Custom plugins (minimal overrides)
    -- ============================================================
    { import = "plugins" },
  },
  defaults = {
    lazy = false,
    version = false, -- always use the latest git commit
  },
  install = { colorscheme = { "catppuccin", "tokyonight", "habamax" } },
  checker = {
    enabled = true,
    notify = false,
  },
  change_detection = {
    notify = false,
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
