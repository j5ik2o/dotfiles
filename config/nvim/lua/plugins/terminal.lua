-- ============================================================
-- toggleterm.nvim - Multiple terminal management
-- ============================================================

return {
  -- edgy.nvim から toggleterm を除外してリサイズを許可
  {
    "folke/edgy.nvim",
    optional = true,
    opts = function(_, opts)
      -- bottom パネルから toggleterm を除外
      if opts.bottom then
        opts.bottom = vim.tbl_filter(function(view)
          return view.ft ~= "toggleterm"
        end, opts.bottom)
      end
    end,
  },
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { [[<C-\>]], desc = "Toggle terminal" },
      { [[<leader>tf]], "<cmd>ToggleTerm direction=float<CR>", desc = "Float terminal" },
      { [[<leader>th]], "<cmd>ToggleTerm direction=horizontal<CR>", desc = "Horizontal terminal" },
      { [[<leader>tv]], "<cmd>ToggleTerm direction=vertical<CR>", desc = "Vertical terminal" },
      -- Numbered terminals
      { [[<leader>t1]], "<cmd>1ToggleTerm direction=horizontal<CR>", desc = "Terminal #1" },
      { [[<leader>t2]], "<cmd>2ToggleTerm direction=horizontal<CR>", desc = "Terminal #2" },
      { [[<leader>t3]], "<cmd>3ToggleTerm direction=horizontal<CR>", desc = "Terminal #3" },
      { [[<leader>t4]], "<cmd>4ToggleTerm direction=horizontal<CR>", desc = "Terminal #4" },
      { [[<leader>tS]], "<cmd>TermSelect<CR>", desc = "Select terminal" },
      { [[<leader>tN]], "<cmd>ToggleTermSetName<CR>", desc = "Name terminal" },
      { [[<leader>ta]], "<cmd>ToggleTermToggleAll<CR>", desc = "Toggle all terminals" },
    },
    opts = {
      open_mapping = [[<C-\>]],
      direction = "horizontal",
      size = function(term)
        if term.direction == "horizontal" then
          return math.floor(vim.o.lines * 0.3)
        elseif term.direction == "vertical" then
          return math.floor(vim.o.columns * 0.4)
        end
      end,
      float_opts = {
        border = "rounded",
        width = function()
          return math.floor(vim.o.columns * 0.8)
        end,
        height = function()
          return math.floor(vim.o.lines * 0.8)
        end,
      },
      shade_terminals = true,
      shading_factor = 2,
      persist_size = true,
      persist_mode = true,
    },
  },
}
