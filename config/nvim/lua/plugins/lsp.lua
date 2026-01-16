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
        -- Markdown
        marksman = {},
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
