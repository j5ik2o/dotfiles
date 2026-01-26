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
      clangd = {
        -- Nix provides the binary; don't install via mason
        mason = false,
      },
      rust_analyzer = {
        -- Nix provides the binary; don't install via mason
        mason = false,
      },
      jdtls = {
        -- Nix provides the binary; don't install via mason
        mason = false,
      },
    },
  },
}
