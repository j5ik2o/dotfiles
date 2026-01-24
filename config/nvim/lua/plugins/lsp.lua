return {
  "neovim/nvim-lspconfig",
  opts = {
    diagnostics = {
      virtual_text = false,
      signs = false,
      underline = false,
      update_in_insert = false,
      severity_sort = true,
    },
    servers = {
      rust_analyzer = {
        -- Nix provides the binary; don't install via mason
        mason = false,
      },
    },
  },
}
