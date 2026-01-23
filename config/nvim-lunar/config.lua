-- if you don't want all the parsers change this to a table of the ones you want
lvim.builtin.treesitter.ensure_installed = {
  "lua",
  "rust",
  "toml",
}

-- Use neo-tree instead of nvim-tree
lvim.builtin.nvimtree = lvim.builtin.nvimtree or {}
lvim.builtin.nvimtree.active = false

-- Diagnostics (Neovim 0.11+): configure signs via vim.diagnostic.config
local diagnostic_signs = {
  [vim.diagnostic.severity.ERROR] = lvim.icons.diagnostics.Error,
  [vim.diagnostic.severity.WARN] = lvim.icons.diagnostics.Warning,
  [vim.diagnostic.severity.HINT] = lvim.icons.diagnostics.Hint,
  [vim.diagnostic.severity.INFO] = lvim.icons.diagnostics.Information,
}

vim.diagnostic.config {
  signs = {
    text = diagnostic_signs,
    numhl = {
      [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
      [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
      [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
      [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
    },
  },
  virtual_text = true,
  update_in_insert = false,
  underline = true,
  severity_sort = true,
  float = {
    focusable = true,
    style = "minimal",
    border = "rounded",
    source = "always",
    header = "",
    prefix = "",
  },
}

-- Ensure callers provide position_encoding (required in Neovim 0.11+).
do
  local orig_make_position_params = vim.lsp.util.make_position_params
  vim.lsp.util.make_position_params = function(window, position_encoding)
    local win = window or 0
    if not position_encoding then
      local buf = vim.api.nvim_win_get_buf(win)
      local clients = vim.lsp.get_clients { bufnr = buf }
      position_encoding = (clients[1] and clients[1].offset_encoding) or "utf-16"
    end
    return orig_make_position_params(win, position_encoding)
  end
end

-- Avoid Treesitter provider errors on Neovim 0.11+ with current plugins.
-- Keep LSP + regex providers for illuminate.
lvim.builtin.illuminate = lvim.builtin.illuminate or {}
lvim.builtin.illuminate.options = lvim.builtin.illuminate.options or {}
lvim.builtin.illuminate.options.providers = { "lsp", "regex" }

vim.list_extend(lvim.lsp.automatic_configuration.skipped_servers, { "rust_analyzer" })

local mason_path = vim.fn.glob(vim.fn.stdpath "data" .. "/mason/")

local codelldb_path = mason_path .. "bin/codelldb"
local liblldb_path = mason_path .. "packages/codelldb/extension/lldb/lib/liblldb"
local this_os = vim.loop.os_uname().sysname

-- The path in windows is different
if this_os:find "Windows" then
  codelldb_path = mason_path .. "packages\\codelldb\\extension\\adapter\\codelldb.exe"
  liblldb_path = mason_path .. "packages\\codelldb\\extension\\lldb\\bin\\liblldb.dll"
else
  -- The liblldb extension is .so for linux and .dylib for macOS
  liblldb_path = liblldb_path .. (this_os == "Linux" and ".so" or ".dylib")
end

pcall(function()
  require("rust-tools").setup {
    tools = {
      executor = require("rust-tools/executors").termopen, -- can be quickfix or termopen
      reload_workspace_from_cargo_toml = true,
      runnables = {
        use_telescope = true,
      },
      inlay_hints = {
        auto = true,
        only_current_line = false,
        show_parameter_hints = false,
        parameter_hints_prefix = "<-",
        other_hints_prefix = "=>",
        max_len_align = false,
        max_len_align_padding = 1,
        right_align = false,
        right_align_padding = 7,
        highlight = "Comment",
      },
      hover_actions = {
        border = "rounded",
      },
      on_initialized = function()
        vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "CursorHold", "InsertLeave" }, {
          pattern = { "*.rs" },
          callback = function()
            local _, _ = pcall(vim.lsp.codelens.refresh)
          end,
        })
      end,
    },
    dap = {
      -- adapter= codelldb_adapter,
      adapter = require("rust-tools.dap").get_codelldb_adapter(codelldb_path, liblldb_path),
    },
    server = {
      on_attach = function(client, bufnr)
        require("lvim.lsp").common_on_attach(client, bufnr)
        local rt = require "rust-tools"
        vim.keymap.set("n", "K", rt.hover_actions.hover_actions, { buffer = bufnr })
      end,

      capabilities = require("lvim.lsp").common_capabilities(),
      settings = {
        ["rust-analyzer"] = {
          lens = {
            enable = true,
          },
          checkOnSave = {
            enable = true,
            command = "clippy",
          },
        },
      },
    },
  }
end)

lvim.builtin.dap.on_config_done = function(dap)
  dap.adapters.codelldb = require("rust-tools.dap").get_codelldb_adapter(codelldb_path, liblldb_path)
  dap.configurations.rust = {
    {
      name = "Launch file",
      type = "codelldb",
      request = "launch",
      program = function()
        return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
    },
  }
end

vim.api.nvim_set_keymap("n", "<m-d>", "<cmd>RustOpenExternalDocs<Cr>", { noremap = true, silent = true })

-- Terminal keymaps
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
local function toggle_lvim_term(id)
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    lazy.load { plugins = { "toggleterm.nvim" } }
  end
  local ok, toggleterm = pcall(require, "toggleterm")
  if not ok then
    vim.notify("toggleterm is not available", vim.log.levels.WARN)
    vim.cmd("terminal")
    return
  end
  toggleterm.toggle(id, nil, nil, "horizontal")
end
vim.keymap.set("n", "<Leader>t1", function()
  toggle_lvim_term(1)
end, { desc = "Terminal #1" })
vim.keymap.set("n", "<Leader>t2", function()
  toggle_lvim_term(2)
end, { desc = "Terminal #2" })
vim.keymap.set("n", "<Leader>t3", function()
  toggle_lvim_term(3)
end, { desc = "Terminal #3" })
vim.keymap.set("n", "<Leader>t4", function()
  toggle_lvim_term(4)
end, { desc = "Terminal #4" })

-- Which-key group for terminals (show under <Leader>t)
lvim.builtin.which_key.mappings["t"] = lvim.builtin.which_key.mappings["t"] or { name = "Terminal" }
lvim.builtin.which_key.mappings["t"]["1"] = { "<Cmd>1ToggleTerm direction=horizontal<CR>", "Terminal #1" }
lvim.builtin.which_key.mappings["t"]["2"] = { "<Cmd>2ToggleTerm direction=horizontal<CR>", "Terminal #2" }
lvim.builtin.which_key.mappings["t"]["3"] = { "<Cmd>3ToggleTerm direction=horizontal<CR>", "Terminal #3" }
lvim.builtin.which_key.mappings["t"]["4"] = { "<Cmd>4ToggleTerm direction=horizontal<CR>", "Terminal #4" }

lvim.keys.normal_mode["<Leader>e"] = "<Cmd>Neotree toggle<CR>"
lvim.builtin.which_key.mappings["e"] = { "<Cmd>Neotree toggle<CR>", "Explorer" }

lvim.builtin.which_key.mappings["C"] = {
  name = "Rust",
  r = { "<cmd>RustRunnables<Cr>", "Runnables" },
  t = { "<cmd>lua _CARGO_TEST()<cr>", "Cargo Test" },
  m = { "<cmd>RustExpandMacro<Cr>", "Expand Macro" },
  c = { "<cmd>RustOpenCargo<Cr>", "Open Cargo" },
  p = { "<cmd>RustParentModule<Cr>", "Parent Module" },
  d = { "<cmd>RustDebuggables<Cr>", "Debuggables" },
  v = { "<cmd>RustViewCrateGraph<Cr>", "View Crate Graph" },
  R = {
    "<cmd>lua require('rust-tools/workspace_refresh')._reload_workspace_from_cargo_toml()<Cr>",
    "Reload Workspace",
  },
  o = { "<cmd>RustOpenExternalDocs<Cr>", "Open External Docs" },
  y = { "<cmd>lua require'crates'.open_repository()<cr>", "[crates] open repository" },
  P = { "<cmd>lua require'crates'.show_popup()<cr>", "[crates] show popup" },
  i = { "<cmd>lua require'crates'.show_crate_popup()<cr>", "[crates] show info" },
  f = { "<cmd>lua require'crates'.show_features_popup()<cr>", "[crates] show features" },
  D = { "<cmd>lua require'crates'.show_dependencies_popup()<cr>", "[crates] show dependencies" },
}

lvim.plugins = {
  "simrat39/rust-tools.nvim",
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    opts = function(_, opts)
      opts.sources = { "filesystem", "buffers", "git_status" }
      opts.source_selector = {
        winbar = true,
        statusline = false,
        content_layout = "center",
        tabs_layout = "equal",
        show_separator_on_edge = true,
        sources = {
          { source = "filesystem", display_name = " Files " },
          { source = "buffers", display_name = " Buffers " },
          { source = "git_status", display_name = " Git " },
        },
      }

      opts.filesystem = opts.filesystem or {}
      opts.filesystem.filtered_items = opts.filesystem.filtered_items or {}
      opts.filesystem.filtered_items.visible = true
      opts.filesystem.filtered_items.hide_dotfiles = false
      opts.filesystem.filtered_items.hide_gitignored = false

      opts.buffers = opts.buffers or {}
      opts.buffers.commands = opts.buffers.commands or {}
      opts.buffers.window = opts.buffers.window or {}
      opts.buffers.window.mappings = opts.buffers.window.mappings or {}

      opts.buffers.commands.open_buffer = function(state)
        local node = state.tree and state.tree:get_node()
        if not node then
          return
        end

        if node.type == "terminal" and node.extra and node.extra.bufnr then
          local bufnr = node.extra.bufnr
          local winid = vim.fn.bufwinid(bufnr)
          if winid ~= -1 then
            vim.api.nvim_set_current_win(winid)
          else
            vim.cmd("buffer " .. bufnr)
          end
          return
        end

        require("neo-tree.sources.common.commands").open(state)
      end

      opts.buffers.window.mappings["<cr>"] = "open_buffer"
      opts.buffers.window.mappings["<2-LeftMouse>"] = "open_buffer"

      return opts
    end,
  },
  {
    "saecki/crates.nvim",
    version = "v0.3.0",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("crates").setup {
        null_ls = {
          enabled = true,
          name = "crates.nvim",
        },
        popup = {
          border = "rounded",
        },
      }
    end,
  },
  {
    "j-hui/fidget.nvim",
    config = function()
      require("fidget").setup()
    end,
  },
}
