-- ============================================================
-- Git 統合 (lazygit, diffview)
-- ============================================================

local helper = require("lazy-nix-helper")

-- Lazygit ターミナルを作成する関数
local lazygit = nil
local function toggle_lazygit()
  if lazygit == nil then
    local Terminal = require("toggleterm.terminal").Terminal
    lazygit = Terminal:new({
      cmd = "lazygit",
      dir = "git_dir",
      direction = "float",
      hidden = true,
      float_opts = {
        border = "rounded",
        width = function()
          return math.floor(vim.o.columns * 0.9)
        end,
        height = function()
          return math.floor(vim.o.lines * 0.9)
        end,
      },
      on_open = function(term)
        vim.cmd("startinsert!")
        vim.api.nvim_buf_set_keymap(term.bufnr, "t", "<Esc>", "<Esc>", { noremap = true, silent = true })
      end,
      on_close = function()
        vim.cmd("checktime")
      end,
    })
  end
  lazygit:toggle()
end

return {
  -- Diffview - GitHub風 diff 表示
  {
    "sindrets/diffview.nvim",
    dir = helper.get_plugin_path("diffview.nvim"),
    dependencies = {
      { "nvim-lua/plenary.nvim", dir = helper.get_plugin_path("plenary.nvim") },
    },
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "Diff view" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "File history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<CR>", desc = "Branch history" },
      { "<leader>gq", "<cmd>DiffviewClose<CR>", desc = "Close diff view" },
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = {
          layout = "diff2_horizontal",
        },
        merge_tool = {
          layout = "diff3_mixed",
        },
      },
      file_panel = {
        win_config = {
          position = "left",
          width = 35,
        },
      },
      hooks = {
        diff_buf_read = function()
          vim.opt_local.wrap = false
        end,
      },
    },
  },

  -- Lazygit キーマップ (toggleterm に依存)
  {
    "akinsho/toggleterm.nvim",
    dir = helper.get_plugin_path("toggleterm.nvim"),
    keys = {
      { "<leader>gg", toggle_lazygit, desc = "Lazygit" },
    },
  },
}
