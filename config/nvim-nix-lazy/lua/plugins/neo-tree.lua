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

      return opts
    end,
  },
}
