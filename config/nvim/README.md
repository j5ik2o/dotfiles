# LazyVim (nvim)

LazyVim starter-style config for the default `nvim` config.

Usage:
- Launch: `nvim` (or `nvn` alias if you keep it)
- First launch bootstraps lazy.nvim and LazyVim

Nix-managed plugins:
- Plugins are provided by Home Manager via `programs.neovim.plugins`.
- Lazy.nvim is pointed at the Nix plugin dir via `NVIM_PLUGIN_DIR`.

Structure:
- `init.lua`: entrypoint
- `lua/config/`: options/keymaps/autocmds
- `lua/plugins/`: extra plugin specs

Notes:
- LazyVim itself is not vendored; it is pulled by lazy.nvim.
