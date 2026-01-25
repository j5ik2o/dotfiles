local uv = vim.uv or vim.loop
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local plugin_dir = vim.env.NVIM_PLUGIN_DIR

local function is_dir(path)
  if type(path) ~= "string" or path == "" then
    return false
  end
  local stat = uv.fs_stat(path)
  return stat and stat.type == "directory"
end

local function has_plugin_dir(base, name)
  return is_dir(base) and is_dir(base .. "/" .. name)
end

local use_nix_plugins = has_plugin_dir(plugin_dir, "LazyVim")
if type(plugin_dir) == "string" and plugin_dir ~= "" and not use_nix_plugins then
  vim.schedule(function()
    vim.notify(
      ("NVIM_PLUGIN_DIR is set but LazyVim is missing: %s. Falling back to git install."):format(
        plugin_dir
      ),
      vim.log.levels.WARN
    )
  end)
end
-- Nix-managed plugin flow (overview in docs/neovim.md).

-- Ensure trouble.nvim runtime files are visible when using Nix plugin dir.
-- trouble.nvim scans runtimepath for its sources; without this, lualine statusline can error.
if use_nix_plugins then
  local trouble_dir = plugin_dir .. "/trouble.nvim"
  if is_dir(trouble_dir) then
    vim.opt.rtp:append(trouble_dir)
  end
end

-- Prefer Nix-managed lazy.nvim (runtimepath) if available, otherwise bootstrap.
local ok_lazy, lazy = pcall(require, "lazy")
if not ok_lazy then
  if not uv.fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
      vim.api.nvim_echo({
        { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
        { out, "WarningMsg" },
        { "\nPress any key to exit..." },
      }, true, {})
      vim.fn.getchar()
      os.exit(1)
    end
  end
  vim.opt.rtp:prepend(lazypath)
  lazy = require("lazy")
end

lazy.setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- import LazyVim extras
    { import = "lazyvim.plugins.extras.editor.neo-tree" },
    { import = "lazyvim.plugins.extras.editor.fzf" },
    { import = "lazyvim.plugins.extras.lang.java" },
    { import = "lazyvim.plugins.extras.lang.scala" },
    -- import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  dev = use_nix_plugins and {
    path = plugin_dir,
    -- lazy.nvim matches patterns as literal substrings (plain find). "" matches all.
    patterns = { "" },
    fallback = false,
  } or nil,
  install = {
    missing = not use_nix_plugins,
    colorscheme = { "catppuccin", "habamax" },
  },
  checker = {
    enabled = not use_nix_plugins, -- check for plugin updates periodically
    notify = false, -- notify on update
  }, -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
