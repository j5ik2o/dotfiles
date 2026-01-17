-- ============================================================
-- Neo-tree configuration (override LazyVim defaults)
-- ============================================================
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      opts.filesystem = opts.filesystem or {}
      opts.filesystem.filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
      }
      opts.window = opts.window or {}
      opts.window.mappings = opts.window.mappings or {}
      opts.window.mappings["<esc>"] = "noop"
      return opts
    end,
  },
}
