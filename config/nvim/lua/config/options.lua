-- Options are automatically loaded before lazy.nvim startup.
-- Add any additional options here.
vim.opt.number = true
vim.opt.relativenumber = false

-- Diagnostics: keep code view clean; use Trouble/loclist instead
vim.diagnostic.config({
  virtual_text = false,
  signs = false,
  underline = false,
  update_in_insert = false,
  severity_sort = true,
  float = { border = "rounded", source = "if_many" },
})
