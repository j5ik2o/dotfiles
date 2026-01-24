-- Keymaps are automatically loaded on the VeryLazy event.
-- Add any additional keymaps here.
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Save file (Cmd+S / Ctrl+S)
vim.keymap.set("n", "<D-s>", "<Cmd>w<CR>", { desc = "Save file" })
vim.keymap.set("i", "<D-s>", "<C-o><Cmd>w<CR>", { desc = "Save file" })
vim.keymap.set("v", "<D-s>", "<Cmd>w<CR>", { desc = "Save file" })
vim.keymap.set("n", "<C-s>", "<Cmd>w<CR>", { desc = "Save file" })
vim.keymap.set("i", "<C-s>", "<C-o><Cmd>w<CR>", { desc = "Save file" })
vim.keymap.set("v", "<C-s>", "<Cmd>w<CR>", { desc = "Save file" })

-- Diagnostics (separate view)
vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
vim.keymap.set(
  "n",
  "<leader>xX",
  "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
  { desc = "Buffer Diagnostics (Trouble)" }
)
vim.keymap.set("n", "<leader>xl", function()
  vim.diagnostic.setloclist()
end, { desc = "Diagnostics (LocList)" })
