-- LunarVim bootstrap for NVIM_APPNAME=nvim-lunar

local fn = vim.fn
local uv = vim.uv or vim.loop

local data_dir = fn.stdpath("data")
local config_dir = fn.stdpath("config")
local cache_dir = fn.stdpath("cache")

local lvim_base = data_dir .. "/lunarvim"
local lvim_init = lvim_base .. "/init.lua"

if not (uv and uv.fs_stat(lvim_init)) then
  if fn.executable("git") ~= 1 then
    vim.notify("git is required to bootstrap LunarVim", vim.log.levels.ERROR)
    return
  end
  local result = fn.system({ "git", "clone", "--depth", "1", "https://github.com/LunarVim/LunarVim.git", lvim_base })
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to clone LunarVim: " .. tostring(result), vim.log.levels.ERROR)
    return
  end
end

vim.env.LUNARVIM_BASE_DIR = lvim_base
vim.env.LUNARVIM_RUNTIME_DIR = data_dir
vim.env.LUNARVIM_CONFIG_DIR = config_dir
vim.env.LUNARVIM_CACHE_DIR = cache_dir

local ok, err = pcall(dofile, lvim_init)
if not ok then
  vim.notify("Failed to load LunarVim: " .. tostring(err), vim.log.levels.ERROR)
end
