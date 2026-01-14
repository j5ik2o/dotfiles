-- ============================================================
-- edgy.nvim - VS Code風パネルレイアウト
-- ============================================================

local helper = require("lazy-nix-helper")

return {
  "folke/edgy.nvim",
  dir = helper.get_plugin_path("edgy.nvim"),
  event = "VeryLazy",
  opts = {
    -- 下部パネル（ターミナル、診断など）
    bottom = {
      {
        ft = "toggleterm",
        size = { height = 0.3 },
        filter = function(buf, win)
          return vim.api.nvim_win_get_config(win).relative == ""
        end,
      },
      {
        ft = "trouble",
        title = "Diagnostics",
        size = { height = 0.3 },
      },
      {
        ft = "qf",
        title = "QuickFix",
        size = { height = 0.3 },
      },
      {
        ft = "help",
        size = { height = 0.4 },
        filter = function(buf)
          return vim.bo[buf].buftype == "help"
        end,
      },
    },
    -- 左パネル（ファイルエクスプローラー）
    left = {
      {
        ft = "neo-tree",
        title = "Explorer",
        size = { width = 30 },
        pinned = true,
        open = "Neotree",
      },
    },
    -- 右パネル（アウトライン、シンボルなど）
    right = {
      {
        ft = "Outline",
        title = "Symbols",
        size = { width = 30 },
      },
    },
    -- アニメーション設定
    animate = {
      enabled = true,
      fps = 60,
      cps = 120,
    },
    -- キーマップ
    keys = {
      -- edgy ウィンドウのリサイズ
      ["<c-Right>"] = function(win)
        win:resize("width", 2)
      end,
      ["<c-Left>"] = function(win)
        win:resize("width", -2)
      end,
      ["<c-Up>"] = function(win)
        win:resize("height", 2)
      end,
      ["<c-Down>"] = function(win)
        win:resize("height", -2)
      end,
    },
  },
}
