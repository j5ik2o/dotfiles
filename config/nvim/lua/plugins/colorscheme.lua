-- ============================================================
-- カラースキーム
-- ============================================================

local helper = require("lazy-nix-helper")

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    dir = helper.get_plugin_path("catppuccin-nvim"),
    lazy = false,
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = false,
        integrations = {
          cmp = true,
          gitsigns = true,
          neo_tree = true,
          telescope = true,
          treesitter = true,
          which_key = true,
          indent_blankline = { enabled = true },
          native_lsp = {
            enabled = true,
          },
          notify = true,
          noice = true,
        },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
}
