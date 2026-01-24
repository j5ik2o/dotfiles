return {
  "stevearc/conform.nvim",
  opts = function(_, opts)
    opts.formatters_by_ft = opts.formatters_by_ft or {}
    -- Ensure common formatters for frequently edited files.
    opts.formatters_by_ft.nix = { "nixfmt" }
    opts.formatters_by_ft.lua = opts.formatters_by_ft.lua or { "stylua" }
    opts.formatters_by_ft.rust = { "rustfmt" }
  end,
}
