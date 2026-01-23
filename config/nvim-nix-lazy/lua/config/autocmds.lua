-- Autocmds are automatically loaded on the VeryLazy event.
-- Add any additional autocmds here.
local terminal_mouse_group = vim.api.nvim_create_augroup("UserTerminalMouse", { clear = true })

vim.api.nvim_create_autocmd("TermOpen", {
  group = terminal_mouse_group,
  callback = function(event)
    local opts = { buffer = event.buf, silent = true, desc = "Hide terminal pane" }
    vim.keymap.set({ "n", "t" }, "<RightMouse>", function()
      if #vim.api.nvim_list_wins() > 1 then
        vim.cmd("close")
      end
    end, opts)
  end,
})
