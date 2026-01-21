-- Customize Treesitter

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
      "lua",
      "vim",
      "vimdoc",
      "bash",
      "json",
      "yaml",
      "toml",
      "markdown",
      "markdown_inline",
      "nix",
      "python",
      "javascript",
      "typescript",
      "tsx",
      "go",
      "gomod",
      "gosum",
      "gowork",
      "rust",
      "java",
    },
  },
}
