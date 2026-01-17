-- ============================================================
-- Neo-tree configuration (override LazyVim defaults)
-- ============================================================
return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },
    window = {
      mappings = {
        -- Remove ESC mapping to allow normal mode navigation
        -- Use 'q' to close neo-tree instead
        ["<esc>"] = "noop",
      },
    },
  },
}
