-- ============================================================
-- Keymaps (LazyVim defaults + custom additions)
-- ============================================================
-- LazyVim provides comprehensive keymaps. Only add what's missing.
-- See: https://www.lazyvim.org/keymaps
-- ============================================================

local map = vim.keymap.set

-- ============================================================
-- Window resize (custom - LazyVim uses <C-Arrow>)
-- ============================================================
map("n", "<leader>wh", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<leader>wl", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })
map("n", "<leader>wj", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
map("n", "<leader>wk", "<cmd>resize +2<CR>", { desc = "Increase window height" })
map("n", "<leader>w=", "<C-w>=", { desc = "Equal window size" })

-- ============================================================
-- Terminal (custom - supplement LazyVim's terminal keymaps)
-- ============================================================
map("n", "<leader>ts", "<cmd>belowright split | terminal<CR>", { desc = "Terminal below (split)" })
