-- ============================================================
-- キーマップ
-- ============================================================

local map = vim.keymap.set

-- 検索ハイライト解除
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- ウィンドウ移動
map("n", "<C-h>", "<C-w><C-h>", { desc = "Move to left window" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "Move to right window" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "Move to lower window" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "Move to upper window" })

-- ウィンドウリサイズ (<leader>w + hjkl: 小, <leader>W + hjkl: 大)
map("n", "<leader>wh", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<leader>wl", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })
map("n", "<leader>wj", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
map("n", "<leader>wk", "<cmd>resize +2<CR>", { desc = "Increase window height" })
map("n", "<leader>Wh", "<cmd>vertical resize -10<CR>", { desc = "Decrease window width (large)" })
map("n", "<leader>Wl", "<cmd>vertical resize +10<CR>", { desc = "Increase window width (large)" })
map("n", "<leader>Wj", "<cmd>resize -10<CR>", { desc = "Decrease window height (large)" })
map("n", "<leader>Wk", "<cmd>resize +10<CR>", { desc = "Increase window height (large)" })
map("n", "<leader>w=", "<C-w>=", { desc = "Equal window size" })

-- バッファ操作
local function is_normal_window(win)
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    return false
  end
  if vim.wo[win].winfixbuf then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == ""
end

local function focus_normal_window()
  local current = vim.api.nvim_get_current_win()
  if is_normal_window(current) then
    return
  end

  local alternate = vim.fn.win_getid(vim.fn.winnr("#"))
  if alternate ~= 0 and is_normal_window(alternate) then
    vim.api.nvim_set_current_win(alternate)
    return
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if is_normal_window(win) then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
end

local function open_buffer_list()
  focus_normal_window()
  vim.cmd("Telescope buffers")
end

map("n", "<leader>bb", open_buffer_list, { desc = "Buffer list" })
map("n", "<leader>fb", open_buffer_list, { desc = "Buffers" })
map("n", "<leader>bn", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>BufferLineCyclePrev<CR>", { desc = "Previous buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })
map("n", "<S-h>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })

-- 保存・終了
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
map("n", "<leader>Q", "<cmd>qa!<CR>", { desc = "Quit all" })

-- 行移動 (Visual mode)
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down", silent = true })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up", silent = true })

-- インデント維持
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- 診断
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })

-- ターミナル
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("n", "<leader>ts", "<cmd>belowright split | terminal<CR>", { desc = "Terminal below (split)" })
map("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "Move to left window" })
map("t", "<C-j>", "<C-\\><C-n><C-w>j", { desc = "Move to lower window" })
map("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "Move to upper window" })
map("t", "<C-l>", "<C-\\><C-n><C-w>l", { desc = "Move to right window" })

-- better up/down
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
