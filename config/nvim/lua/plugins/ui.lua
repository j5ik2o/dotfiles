-- ============================================================
-- UI 設定
-- ============================================================

local helper = require("lazy-nix-helper")

return {
  -- ステータスライン
  {
    "nvim-lualine/lualine.nvim",
    dir = helper.get_plugin_path("lualine.nvim"),
    event = "VeryLazy",
    dependencies = {
      { "nvim-tree/nvim-web-devicons", dir = helper.get_plugin_path("nvim-web-devicons") },
    },
    opts = {
      options = {
        theme = "catppuccin",
        globalstatus = true,
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },

  -- バッファライン
  {
    "akinsho/bufferline.nvim",
    dir = helper.get_plugin_path("bufferline.nvim"),
    event = "VeryLazy",
    dependencies = {
      { "nvim-tree/nvim-web-devicons", dir = helper.get_plugin_path("nvim-web-devicons") },
    },
    keys = {
      { "<leader>bp", "<cmd>BufferLineTogglePin<CR>", desc = "Pin buffer" },
      { "<leader>bP", "<cmd>BufferLineGroupClose ungrouped<CR>", desc = "Close unpinned buffers" },
    },
    opts = {
      options = {
        diagnostics = "nvim_lsp",
        always_show_bufferline = false,
        offsets = {
          {
            filetype = "neo-tree",
            text = "File Explorer",
            highlight = "Directory",
            text_align = "left",
          },
        },
      },
    },
  },

  -- インデントガイド
  {
    "lukas-reineke/indent-blankline.nvim",
    dir = helper.get_plugin_path("indent-blankline.nvim"),
    lazy = false,
    main = "ibl",
    opts = {
      indent = { char = "│" },
      scope = { enabled = true },
      exclude = {
        filetypes = { "help", "neo-tree", "Trouble", "lazy" },
      },
    },
  },

  -- Git サイン
  {
    "lewis6991/gitsigns.nvim",
    dir = helper.get_plugin_path("gitsigns.nvim"),
    lazy = false,
    opts = {
      signs = {
        add = { text = "│" },
        change = { text = "│" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
        end

        map("n", "]h", gs.next_hunk, "Next hunk")
        map("n", "[h", gs.prev_hunk, "Previous hunk")
        map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
        map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
        map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>hb", gs.blame_line, "Blame line")
      end,
    },
  },

  -- 通知
  {
    "rcarriga/nvim-notify",
    dir = helper.get_plugin_path("nvim-notify"),
    event = "VeryLazy",
    opts = {
      timeout = 3000,
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.75)
      end,
    },
    config = function(_, opts)
      require("notify").setup(opts)
      vim.notify = require("notify")
    end,
  },

  -- モダン UI
  {
    "folke/noice.nvim",
    dir = helper.get_plugin_path("noice.nvim"),
    event = "VeryLazy",
    dependencies = {
      { "MunifTanjim/nui.nvim", dir = helper.get_plugin_path("nui.nvim") },
      { "rcarriga/nvim-notify", dir = helper.get_plugin_path("nvim-notify") },
    },
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
      },
    },
  },

  -- アイコン
  {
    "nvim-tree/nvim-web-devicons",
    dir = helper.get_plugin_path("nvim-web-devicons"),
    lazy = true,
    opts = {},
  },
}
