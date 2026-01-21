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
      "haskell",
      "ocaml",
      "ocaml_interface",
      "ocamllex",
    },
  },
  config = function(plugin, opts)
    -- tree-sitter CLI 0.26+ removed --no-bindings. Patch args for 0.26+.
    local install = require "nvim-treesitter.install"
    if vim.fn.executable "tree-sitter" == 1 then
      local out = vim.fn.systemlist { "tree-sitter", "--version" }
      local ver = out and out[1] or ""
      local major, minor = ver:match("(%d+)%.(%d+)")
      major, minor = tonumber(major), tonumber(minor)
      if major and minor and (major > 0 or minor >= 26) then
        install.ts_generate_args = { "generate", "--abi", vim.treesitter.language_version }
      end
    end

    -- Keep AstroNvim's default config behavior
    require("astronvim.plugins.configs.nvim-treesitter")(plugin, opts)
  end,
}
