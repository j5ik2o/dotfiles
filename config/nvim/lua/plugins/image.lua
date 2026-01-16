-- ============================================================
-- image.nvim - Terminal image display (Kitty protocol)
-- ============================================================
-- Supports terminals with Kitty graphics protocol:
-- - Kitty
-- - Ghostty
-- - WezTerm (partial support)
-- Works over SSH if TERM is properly set
-- ============================================================

-- Detect terminals that support Kitty graphics protocol
local function supports_kitty_graphics()
  local term = vim.env.TERM or ""
  local term_program = vim.env.TERM_PROGRAM or ""

  -- Kitty (direct or SSH with TERM preserved)
  if term == "xterm-kitty" or vim.env.KITTY_WINDOW_ID ~= nil then
    return true
  end

  -- Ghostty (direct or SSH with TERM preserved)
  if term == "xterm-ghostty" or vim.env.GHOSTTY_RESOURCES_DIR ~= nil then
    return true
  end

  -- WezTerm (has partial Kitty graphics support)
  if term_program == "WezTerm" or term:match("wezterm") then
    return true
  end

  -- Check for generic kitty support in TERM
  if term:match("kitty") then
    return true
  end

  return false
end

-- Check if imagemagick is available (required for image processing)
local function has_imagemagick()
  return vim.fn.executable("magick") == 1 or vim.fn.executable("convert") == 1
end

if not supports_kitty_graphics() then
  return {}
end

if not has_imagemagick() then
  vim.notify("image.nvim: imagemagick not found, disabling", vim.log.levels.WARN)
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
