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
      lua_ls = {
        settings = {
          Lua = {
            runtime = {
              version = "LuaJIT",
            },
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              library = {
                vim.env.VIMRUNTIME,
              },
              checkThirdParty = false,
            },
            telemetry = {
              enable = false,
            },
          },
        },
      },
      clangd = {
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
