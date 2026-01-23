# LazyVim (nvim-lazy)

LazyVim starter-style config for NVIM_APPNAME=nvim-lazy.

Usage:
- Launch: `nvl` (alias) or `NVIM_APPNAME=nvim-lazy nvim`
- First launch bootstraps lazy.nvim and LazyVim

Structure:
- `init.lua`: entrypoint
- `lua/config/`: options/keymaps/autocmds
- `lua/plugins/`: extra plugin specs

Notes:
- LazyVim itself is not vendored; it is pulled by lazy.nvim.
