-- ============================================================
-- LSP Configuration
-- ============================================================
-- Disable mason (LSP servers are managed by Nix)
-- ============================================================

return {
  -- Disable mason (Nix manages LSP servers)
  {
    "mason-org/mason.nvim",
    enabled = false,
    -- Suppress rename warning
    name = "mason.nvim",
  },
  {
    "mason-org/mason-lspconfig.nvim",
    enabled = false,
    name = "mason-lspconfig.nvim",
  },

  -- Language-specific plugins
  {
    "Julian/lean.nvim",
    event = { "BufReadPre *.lean", "BufNewFile *.lean" },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    main = "lean",
    opts = {
      mappings = true,
    },
  },

  -- LSP server settings (servers are installed via Nix)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Nix
        nil_ls = {},
        -- Lua
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = { globals = { "vim" } },
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
            },
          },
        },
        -- TypeScript/JavaScript
        ts_ls = {},
        -- Rust (managed by rustaceanvim via extras.lang.rust)
        -- rust_analyzer = {},
        -- Go
        gopls = {},
        -- Python
        pyright = {},
        -- Haskell
        hls = {},
        -- JSON
        jsonls = {},
        -- YAML
        yamlls = {},
        -- TOML
        taplo = {},
        -- HTML/CSS
        html = {},
        cssls = {},
      },
    },
  },
}
