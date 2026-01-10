-- ============================================================
-- エディタ機能
-- ============================================================

local helper = require("lazy-nix-helper")

return {
  -- ファイルエクスプローラー
  {
    "nvim-neo-tree/neo-tree.nvim",
    dir = helper.get_plugin_path("neo-tree.nvim"),
    branch = "v3.x",
    dependencies = {
      { "nvim-lua/plenary.nvim", dir = helper.get_plugin_path("plenary.nvim") },
      { "nvim-tree/nvim-web-devicons", dir = helper.get_plugin_path("nvim-web-devicons") },
      { "MunifTanjim/nui.nvim", dir = helper.get_plugin_path("nui.nvim") },
    },
    cmd = "Neotree",
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "Toggle Neo-tree" },
      { "<leader>fe", "<cmd>Neotree reveal<CR>", desc = "Reveal in Neo-tree" },
    },
    opts = {
      filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
      window = {
        width = 30,
        mappings = {
          ["P"] = {
            "toggle_preview",
            config = {
              use_float = false,
              use_image_nvim = true,
            },
          },
        },
      },
      open_files_do_not_replace_types = { "terminal", "trouble", "qf" },
      default_component_configs = {
        file_opened = {
          window_picker = {
            enable = false,
          },
        },
      },
    },
  },

  -- ファジーファインダー
  {
    "nvim-telescope/telescope.nvim",
    dir = helper.get_plugin_path("telescope.nvim"),
    dependencies = {
      { "nvim-lua/plenary.nvim", dir = helper.get_plugin_path("plenary.nvim") },
      { "nvim-telescope/telescope-fzf-native.nvim", dir = helper.get_plugin_path("telescope-fzf-native.nvim") },
    },
    cmd = "Telescope",
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help tags" },
      { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
      { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search in buffer" },
    },
    opts = {
      defaults = {
        file_ignore_patterns = { "node_modules", ".git/" },
        mappings = {
          i = {
            ["<C-j>"] = "move_selection_next",
            ["<C-k>"] = "move_selection_previous",
          },
        },
      },
    },
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)
      telescope.load_extension("fzf")
    end,
  },

  -- コメント
  {
    "numToStr/Comment.nvim",
    dir = helper.get_plugin_path("comment.nvim"),
    keys = {
      { "gc", mode = { "n", "v" }, desc = "Comment toggle" },
      { "gb", mode = { "n", "v" }, desc = "Block comment toggle" },
    },
    opts = {},
  },

  -- サラウンド
  {
    "kylechui/nvim-surround",
    dir = helper.get_plugin_path("nvim-surround"),
    event = "VeryLazy",
    opts = {},
  },

  -- ペア括弧
  {
    "windwp/nvim-autopairs",
    dir = helper.get_plugin_path("nvim-autopairs"),
    event = "InsertEnter",
    opts = {},
  },

  -- 高速移動
  {
    "folke/flash.nvim",
    dir = helper.get_plugin_path("flash.nvim"),
    dev = true,
    event = "VeryLazy",
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    },
    opts = {},
  },

  -- TODO コメント
  {
    "folke/todo-comments.nvim",
    dir = helper.get_plugin_path("todo-comments.nvim"),
    dependencies = {
      { "nvim-lua/plenary.nvim", dir = helper.get_plugin_path("plenary.nvim") },
    },
    event = "VeryLazy",
    keys = {
      { "<leader>ft", "<cmd>TodoTelescope<CR>", desc = "Find TODOs" },
    },
    opts = {},
  },

  -- 診断一覧
  {
    "folke/trouble.nvim",
    dir = helper.get_plugin_path("trouble.nvim"),
    cmd = "Trouble",
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", desc = "Diagnostics" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Buffer diagnostics" },
    },
    opts = {},
  },

  -- キーマップヘルプ
  {
    "folke/which-key.nvim",
    dir = helper.get_plugin_path("which-key.nvim"),
    dev = true,
    event = "VeryLazy",
    opts = {
      plugins = { spelling = true },
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)
      wk.add({
        { "<leader>f", group = "Find" },
        { "<leader>b", group = "Buffer" },
        { "<leader>c", group = "Code" },
        { "<leader>x", group = "Diagnostics" },
      })
    end,
  },

  -- ターミナル
  {
    "akinsho/toggleterm.nvim",
    dir = helper.get_plugin_path("toggleterm.nvim"),
    keys = {
      { [[<C-\>]], desc = "Toggle terminal" },
      { [[<leader>tf]], "<cmd>ToggleTerm direction=float<CR>", desc = "Float terminal" },
      { [[<leader>th]], "<cmd>ToggleTerm direction=horizontal<CR>", desc = "Horizontal terminal" },
      { [[<leader>tv]], "<cmd>ToggleTerm direction=vertical<CR>", desc = "Vertical terminal" },
    },
    opts = {
      open_mapping = [[<C-\>]],
      direction = "horizontal",
      size = 15,
      float_opts = { border = "rounded" },
    },
  },
}
