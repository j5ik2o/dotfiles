-- ============================================================
-- image.nvim - Terminal image display (Kitty only)
-- ============================================================
-- Not included in LazyVim, custom plugin for Kitty terminal
-- Only loads when running in Kitty terminal
-- ============================================================

-- Only enable in Kitty terminal
local is_kitty = vim.env.TERM == "xterm-kitty" or vim.env.KITTY_WINDOW_ID ~= nil

if not is_kitty then
  return {}
end

return {
  {
    "3rd/image.nvim",
    lazy = false,
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          filetypes = { "markdown", "vimwiki" },
        },
        neorg = { enabled = false },
        html = { enabled = false },
        css = { enabled = false },
      },
      max_width = nil,
      max_height = nil,
      max_height_window_percentage = 50,
      window_overlap_clear_enabled = true,
      hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
    },
  },
}
