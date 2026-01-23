return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- ToggleTerm (match Astro's terminal behavior for <Leader>t#)
  {
    "akinsho/toggleterm.nvim",
    cmd = { "ToggleTerm", "TermExec" },
    keys = {
      { "<Leader>t1", "<Cmd>1ToggleTerm<CR>", desc = "Terminal #1" },
      { "<Leader>t2", "<Cmd>2ToggleTerm<CR>", desc = "Terminal #2" },
      { "<Leader>t3", "<Cmd>3ToggleTerm<CR>", desc = "Terminal #3" },
      { "<Leader>t4", "<Cmd>4ToggleTerm<CR>", desc = "Terminal #4" },
    },
    opts = {
      direction = "horizontal",
      size = 10,
      shading_factor = 2,
      float_opts = { border = "rounded" },
    },
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
}
