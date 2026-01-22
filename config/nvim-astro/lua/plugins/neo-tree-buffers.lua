-- Neo-tree buffers: focus existing terminals instead of opening new splits
return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = function(_, opts)
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

    -- Use custom open for buffers source (enter/mouse double click)
    opts.buffers.window.mappings["<cr>"] = "open_buffer"
    opts.buffers.window.mappings["<2-LeftMouse>"] = "open_buffer"
  end,
}
