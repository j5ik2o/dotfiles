# LazyVim (nvim-nix-lazy)

LazyVim starter-style config for NVIM_APPNAME=nvim-nix-lazy.

Usage:
- Launch: `nvn` (alias) or `NVIM_APPNAME=nvim-nix-lazy nvim`
- First launch bootstraps lazy.nvim and LazyVim

Nix-managed plugins:
- Plugins are provided by Home Manager via `programs.neovim.plugins`.
- Lazy.nvim is pointed at the Nix plugin dir via `NVIM_NIX_LAZY_PLUGIN_DIR`.

Structure:
- `init.lua`: entrypoint
- `lua/config/`: options/keymaps/autocmds
- `lua/plugins/`: extra plugin specs

Notes:
- LazyVim itself is not vendored; it is pulled by lazy.nvim.
