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
        use_libuv_file_watcher = true, -- ファイルシステム監視で自動更新
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
        },
        group_empty_dirs = true,
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
        { "<leader>t", group = "Terminal" },
        { "<leader>g", group = "Git" },
        { "<leader>w", group = "Window" },
        { "<leader>W", group = "Window (large)" },
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
      -- 番号付きターミナル（常に下部、フォーカスのみ・トグルしない）
      {
        [[<leader>t1]],
        function()
          local term = require("toggleterm.terminal").get(1)
          if term == nil then
            vim.cmd("1ToggleTerm direction=horizontal")
          elseif not term:is_open() then
            term:open()
          else
            term:focus()
          end
        end,
        desc = "Terminal #1",
      },
      {
        [[<leader>t2]],
        function()
          local term = require("toggleterm.terminal").get(2)
          if term == nil then
            vim.cmd("2ToggleTerm direction=horizontal")
          elseif not term:is_open() then
            term:open()
          else
            term:focus()
          end
        end,
        desc = "Terminal #2",
      },
      {
        [[<leader>t3]],
        function()
          local term = require("toggleterm.terminal").get(3)
          if term == nil then
            vim.cmd("3ToggleTerm direction=horizontal")
          elseif not term:is_open() then
            term:open()
          else
            term:focus()
          end
        end,
        desc = "Terminal #3",
      },
      {
        [[<leader>t4]],
        function()
          local term = require("toggleterm.terminal").get(4)
          if term == nil then
            vim.cmd("4ToggleTerm direction=horizontal")
          elseif not term:is_open() then
            term:open()
          else
            term:focus()
          end
        end,
        desc = "Terminal #4",
      },
      { [[<leader>tS]], "<cmd>TermSelect<CR>", desc = "Select terminal" },
      { [[<leader>tN]], "<cmd>ToggleTermSetName<CR>", desc = "Name terminal" },
      { [[<leader>ta]], "<cmd>ToggleTermToggleAll<CR>", desc = "Toggle all terminals" },
      -- ターミナルを隠す（終了せずに非表示）
      {
        [[<leader>tc]],
        function()
          local terms = require("toggleterm.terminal").get_all()
          for _, term in ipairs(terms) do
            if term:is_open() then
              term:close()
            end
          end
        end,
        desc = "Hide all terminals",
      },
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
