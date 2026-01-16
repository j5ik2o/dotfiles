-- Minimal init for headless tests.
local root = os.getenv("NVIM_TEST_ROOT")
if root == nil or root == "" then
  error("NVIM_TEST_ROOT is required")
end

local function add_package_paths(path)
  package.path = path .. "/?.lua;" .. path .. "/?/init.lua;" .. package.path
end

add_package_paths(root .. "/config/nvim/tests/lua")
add_package_paths(root .. "/config/nvim/lua")

-- Keep defaults predictable for keymap tests.
vim.g.mapleader = " "
vim.g.maplocalleader = " "
