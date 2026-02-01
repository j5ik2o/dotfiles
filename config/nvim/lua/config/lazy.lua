local uv = vim.uv or vim.loop
local data_path = vim.fn.stdpath("data")
local plugin_dir = vim.env.NVIM_PLUGIN_DIR
if type(plugin_dir) ~= "string" or plugin_dir == "" then
  plugin_dir = vim.fn.fnamemodify(data_path, ":h") .. "/nvim-plugins"
end

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
local rtp_paths = {}

local function fatal(msg)
  vim.api.nvim_err_writeln(msg)
  local ok_uis, uis = pcall(vim.api.nvim_list_uis)
  if ok_uis and type(uis) == "table" and #uis > 0 then
    vim.api.nvim_echo({ { "Press any key to exit..." } }, true, {})
    vim.fn.getchar()
  end
  os.exit(1)
end

if not use_nix_plugins then
  fatal(("Nix-managed LazyVim is missing in NVIM_PLUGIN_DIR: %s\nRun `make apply` to provision plugins."):format(
    plugin_dir
  ))
end
-- Nix-managed plugin flow (overview in docs/neovim.md).

-- Ensure Nix-managed lazy.nvim is on runtimepath before requiring it.
local lazy_dir = plugin_dir .. "/lazy.nvim"
if is_dir(lazy_dir) then
  vim.opt.rtp:prepend(lazy_dir)
else
  fatal("Nix-managed lazy.nvim is missing. Run `make apply` to provision plugins.")
end

-- Ensure trouble.nvim runtime files are visible when using Nix plugin dir.
-- trouble.nvim scans runtimepath for its sources; without this, lualine statusline can error.
if use_nix_plugins then
  local trouble_dir = plugin_dir .. "/trouble.nvim"
  if is_dir(trouble_dir) then
    vim.opt.rtp:append(trouble_dir)
    table.insert(rtp_paths, trouble_dir)
  end
  -- Nix-managed treesitter grammars (parser .so + queries .scm).
  -- withPlugins の依存を symlinkJoin でまとめた derivation を rtp に載せる。
  -- append でプラグイン側クエリを優先させる。
  local grammars_dir = plugin_dir .. "/nvim-treesitter-grammars"
  if is_dir(grammars_dir) then
    vim.opt.rtp:append(grammars_dir)
    table.insert(rtp_paths, grammars_dir)
  end
end

-- Require Nix-managed lazy.nvim (runtimepath). Do not bootstrap from git.
local ok_lazy, lazy = pcall(require, "lazy")
if not ok_lazy then
  fatal("Failed to load Nix-managed lazy.nvim. Run `make apply` to provision plugins.")
end

lazy.setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- import LazyVim extras
    { import = "lazyvim.plugins.extras.editor.neo-tree" },
    { import = "lazyvim.plugins.extras.editor.fzf" },
    { import = "lazyvim.plugins.extras.editor.telescope" },
    { import = "lazyvim.plugins.extras.coding.blink" },
    { import = "lazyvim.plugins.extras.ai.copilot" },
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
      paths = rtp_paths,
    },
  },
})
