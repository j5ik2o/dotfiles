require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
map("n", "<Leader>e", "<Cmd>Neotree toggle<CR>", { desc = "NeoTree" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

-- Terminal keymaps
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("n", "<Leader>t1", "<Cmd>1ToggleTerm<CR>", { desc = "Terminal #1" })
map("n", "<Leader>t2", "<Cmd>2ToggleTerm<CR>", { desc = "Terminal #2" })
map("n", "<Leader>t3", "<Cmd>3ToggleTerm<CR>", { desc = "Terminal #3" })
map("n", "<Leader>t4", "<Cmd>4ToggleTerm<CR>", { desc = "Terminal #4" })
