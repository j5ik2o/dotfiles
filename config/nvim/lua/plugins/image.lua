local helper = require("lazy-nix-helper")

return {
  {
    "3rd/image.nvim",
    dir = helper.get_plugin_path("image.nvim"),
    lazy = false,  -- 即座にロード
    opts = {
      backend = "kitty",
      processor = "magick_cli",  -- magick_rockは追加設定が必要なためcliに変更
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
