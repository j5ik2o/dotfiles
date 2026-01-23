return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      direction = "horizontal",
      size = 15,
      start_in_insert = true,
      persist_size = true,
    },
    keys = {
      { "<Leader>t1", "<Cmd>1ToggleTerm<CR>", desc = "Terminal #1" },
      { "<Leader>t2", "<Cmd>2ToggleTerm<CR>", desc = "Terminal #2" },
      { "<Leader>t3", "<Cmd>3ToggleTerm<CR>", desc = "Terminal #3" },
      { "<Leader>t4", "<Cmd>4ToggleTerm<CR>", desc = "Terminal #4" },
    },
  },
}
