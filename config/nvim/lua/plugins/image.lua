-- ============================================================
-- image.nvim - Terminal image display (Kitty protocol)
-- ============================================================
-- Supports terminals with Kitty graphics protocol:
-- - Kitty
-- - Ghostty
-- - WezTerm (partial support)
-- ============================================================

-- Detect terminals that support Kitty graphics protocol
local function supports_kitty_graphics()
  -- Kitty
  if vim.env.TERM == "xterm-kitty" or vim.env.KITTY_WINDOW_ID ~= nil then
    return true
  end
  -- Ghostty
  if vim.env.TERM == "xterm-ghostty" or vim.env.GHOSTTY_RESOURCES_DIR ~= nil then
    return true
  end
  -- WezTerm (has partial Kitty graphics support)
  if vim.env.TERM_PROGRAM == "WezTerm" then
    return true
  end
  return false
end

if not supports_kitty_graphics() then
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
