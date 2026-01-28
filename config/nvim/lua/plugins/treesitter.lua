return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    -- パーサーは Nix (neovim.nix の treesitterWithGrammars) で管理。
    -- ランタイムでのコンパイル/インストールは行わない。
    ensure_installed = {},
    auto_install = false,
    highlight = {
      enable = true,
    },
    indent = {
      enable = true,
    },
  },
}
