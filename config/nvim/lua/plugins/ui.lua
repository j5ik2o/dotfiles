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
      { "<leader>bP", "<cmd>BufferLineTogglePin<CR>", desc = "Pin buffer" },
      { "<leader>bX", "<cmd>BufferLineGroupClose ungrouped<CR>", desc = "Close unpinned buffers" },
    },
    opts = {
      options = {
        diagnostics = "nvim_lsp",
        always_show_bufferline = true,
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
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      current_line_blame = false,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 500,
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map("n", "]h", function()
          if vim.wo.diff then return "]h" end
          vim.schedule(function() gs.next_hunk() end)
          return "<Ignore>"
        end, { expr = true, desc = "Next hunk" })

        map("n", "[h", function()
          if vim.wo.diff then return "[h" end
          vim.schedule(function() gs.prev_hunk() end)
          return "<Ignore>"
        end, { expr = true, desc = "Previous hunk" })

        -- Actions
        map("n", "<leader>gs", gs.stage_hunk, { desc = "Stage hunk" })
        map("n", "<leader>gr", gs.reset_hunk, { desc = "Reset hunk" })
        map("v", "<leader>gs", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "Stage hunk" })
        map("v", "<leader>gr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "Reset hunk" })
        map("n", "<leader>gS", gs.stage_buffer, { desc = "Stage buffer" })
        map("n", "<leader>gu", gs.undo_stage_hunk, { desc = "Undo stage hunk" })
        map("n", "<leader>gR", gs.reset_buffer, { desc = "Reset buffer" })
        map("n", "<leader>gp", gs.preview_hunk, { desc = "Preview hunk" })
        map("n", "<leader>gb", function()
          gs.blame_line({ full = true })
        end, { desc = "Blame line" })
        map("n", "<leader>gB", gs.toggle_current_line_blame, { desc = "Toggle line blame" })
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
