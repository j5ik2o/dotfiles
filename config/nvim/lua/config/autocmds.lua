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

local nospell_group = vim.api.nvim_create_augroup("UserNoSpell", { clear = true })

vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
  group = nospell_group,
  callback = function()
    vim.opt_local.spell = false
  end,
})

vim.opt_local.spell = false

function _G.CodeCompanionWinbar()
  local meta = _G.codecompanion_chat_metadata
  if not meta then
    return "CodeCompanion"
  end
  local buf = vim.api.nvim_get_current_buf()
  local entry = meta[buf]
  if not entry or not entry.adapter then
    return "CodeCompanion"
  end
  local name = entry.adapter.name or "adapter"
  local model = entry.adapter.model
  if model and model ~= "" then
    return ("CC: %s (%s)"):format(name, model)
  end
  return ("CC: %s"):format(name)
end

local codecompanion_winbar_group = vim.api.nvim_create_augroup("UserCodeCompanionWinbar", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = codecompanion_winbar_group,
  pattern = "codecompanion",
  callback = function()
    vim.opt_local.winbar = "%{v:lua.CodeCompanionWinbar()}"
  end,
})
