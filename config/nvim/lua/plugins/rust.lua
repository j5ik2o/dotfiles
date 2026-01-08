-- ============================================================
-- Rust 開発環境
-- ============================================================

local helper = require("lazy-nix-helper")

return {
  -- Cargo.toml の依存関係管理
  {
    "saecki/crates.nvim",
    dir = helper.get_plugin_path("crates.nvim"),
    event = { "BufRead Cargo.toml" },
    dependencies = {
      { "nvim-lua/plenary.nvim", dir = helper.get_plugin_path("plenary.nvim") },
    },
    config = function()
      local crates = require("crates")
      crates.setup({
        popup = {
          autofocus = true,
          border = "rounded",
        },
        lsp = {
          enabled = true,
          actions = true,
          completion = true,
          hover = true,
        },
      })

      -- Cargo.toml 用キーマップ
      vim.api.nvim_create_autocmd("BufRead", {
        group = vim.api.nvim_create_augroup("crates_keymaps", { clear = true }),
        pattern = "Cargo.toml",
        callback = function(event)
          local opts = { buffer = event.buf, silent = true }

          -- バージョン情報
          vim.keymap.set("n", "<leader>ct", crates.toggle, vim.tbl_extend("force", opts, { desc = "Toggle crates" }))
          vim.keymap.set("n", "<leader>cr", crates.reload, vim.tbl_extend("force", opts, { desc = "Reload crates" }))

          -- バージョン操作
          vim.keymap.set("n", "<leader>cv", crates.show_versions_popup, vim.tbl_extend("force", opts, { desc = "Show versions" }))
          vim.keymap.set("n", "<leader>cf", crates.show_features_popup, vim.tbl_extend("force", opts, { desc = "Show features" }))
          vim.keymap.set("n", "<leader>cd", crates.show_dependencies_popup, vim.tbl_extend("force", opts, { desc = "Show dependencies" }))

          -- アップグレード
          vim.keymap.set("n", "<leader>cu", crates.upgrade_crate, vim.tbl_extend("force", opts, { desc = "Upgrade crate" }))
          vim.keymap.set("v", "<leader>cu", crates.upgrade_crates, vim.tbl_extend("force", opts, { desc = "Upgrade crates" }))
          vim.keymap.set("n", "<leader>cU", crates.upgrade_all_crates, vim.tbl_extend("force", opts, { desc = "Upgrade all crates" }))

          -- ドキュメント
          vim.keymap.set("n", "<leader>cH", crates.open_homepage, vim.tbl_extend("force", opts, { desc = "Open homepage" }))
          vim.keymap.set("n", "<leader>cR", crates.open_repository, vim.tbl_extend("force", opts, { desc = "Open repository" }))
          vim.keymap.set("n", "<leader>cD", crates.open_documentation, vim.tbl_extend("force", opts, { desc = "Open docs.rs" }))
          vim.keymap.set("n", "<leader>cC", crates.open_crates_io, vim.tbl_extend("force", opts, { desc = "Open crates.io" }))
        end,
      })
    end,
  },
}
