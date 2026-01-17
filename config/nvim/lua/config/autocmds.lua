-- ============================================================
-- Autocmds (LazyVim defaults + custom additions)
-- ============================================================
-- LazyVim provides many useful autocmds. Only add what's missing.
-- See: https://www.lazyvim.org/configuration/general#auto-commands
-- ============================================================

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- ============================================================
-- Terminal: pin buffer to window
-- ============================================================
autocmd("TermOpen", {
  group = augroup("terminal_winfixbuf", { clear = true }),
  callback = function()
    vim.opt_local.winfixbuf = true
  end,
})

-- ============================================================
-- Disable spell check (override LazyVim default)
-- ============================================================
autocmd("FileType", {
  group = augroup("lazyvim_wrap_spell", { clear = true }),
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.spell = false
  end,
})

-- ============================================================
-- Trim trailing whitespace on save
-- ============================================================
autocmd("BufWritePre", {
  group = augroup("trim_whitespace", { clear = true }),
  pattern = "*",
  callback = function()
    local save_cursor = vim.fn.getpos(".")
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setpos(".", save_cursor)
  end,
})
