return {
  {
    "nvim-neo-tree/neo-tree.nvim",
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
      opts.use_popups_for_input = false
      opts.filesystem = opts.filesystem or {}
      opts.filesystem.filtered_items = opts.filesystem.filtered_items or {}
      opts.filesystem.filtered_items.visible = true
      opts.filesystem.filtered_items.hide_dotfiles = false
      opts.filesystem.filtered_items.hide_gitignored = false
      opts.filesystem.commands = opts.filesystem.commands or {}
      opts.filesystem.window = opts.filesystem.window or {}
      opts.filesystem.window.mappings = opts.filesystem.window.mappings or {}

      opts.buffers = opts.buffers or {}
      opts.buffers.commands = opts.buffers.commands or {}
      opts.buffers.window = opts.buffers.window or {}
      opts.buffers.window.mappings = opts.buffers.window.mappings or {}

      local function focus_existing_terminal(bufnr)
        if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
          return false
        end
        if vim.bo[bufnr].buftype ~= "terminal" then
          return false
        end
        local winids = vim.fn.win_findbuf(bufnr)
        if #winids > 0 then
          vim.api.nvim_set_current_win(winids[1])
          return true
        end
        return false
      end

      local function normalize_path(path)
        if type(path) ~= "string" or path == "" then
          return nil
        end
        local normalized = vim.fn.fnamemodify(path, ":p")
        normalized = normalized:gsub("/+$", "")
        if normalized == "" then
          normalized = "/"
        end
        return normalized
      end

      local function project_root_for(path)
        if vim.fs and vim.fs.root then
          local root = vim.fs.root(path, {
            ".git",
            "pyproject.toml",
            "package.json",
            "Cargo.toml",
            "go.mod",
            "Makefile",
            "flake.nix",
          })
          if root and root ~= "" then
            return root
          end
        end
        return vim.fn.getcwd()
      end

      local function relative_to_root(path)
        local abs_path = normalize_path(path)
        local abs_root = normalize_path(project_root_for(path))
        if not abs_path or not abs_root then
          return path
        end
        if abs_path == abs_root then
          return "."
        end
        if abs_path:sub(1, #abs_root + 1) == abs_root .. "/" then
          return abs_path:sub(#abs_root + 2)
        end
        return abs_path
      end

      local function copy_to_clipboard(text)
        if not text or text == "" then
          return
        end
        vim.fn.setreg("+", text)
        vim.fn.setreg("*", text)
      end

      opts.buffers.commands.open_buffer = function(state)
        local node = state.tree and state.tree:get_node()
        if not node then
          return
        end

        local bufnr = node.extra and node.extra.bufnr
        if bufnr and focus_existing_terminal(bufnr) then
          return
        end

        require("neo-tree.sources.common.commands").open(state)
      end

      opts.buffers.window.mappings["<cr>"] = "open_buffer"
      opts.buffers.window.mappings["<2-LeftMouse>"] = "open_buffer"
      opts.filesystem.commands.copy_relative_path = function(state)
        local node = state.tree and state.tree:get_node()
        if not node then
          return
        end
        local path = node.path or node:get_id()
        if not path then
          return
        end
        local relpath = relative_to_root(path)
        copy_to_clipboard(relpath)
        vim.notify(("Copied relative path: %s"):format(relpath))
      end
      opts.filesystem.window.mappings["yr"] = "copy_relative_path"

      return opts
    end,
  },
}
