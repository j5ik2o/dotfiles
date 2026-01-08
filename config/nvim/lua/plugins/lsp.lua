-- ============================================================
-- LSP 設定 (Neovim 0.11+ API)
-- ============================================================

local helper = require("lazy-nix-helper")

return {
  -- LSP 設定
  {
    "neovim/nvim-lspconfig",
    dir = helper.get_plugin_path("nvim-lspconfig"),
    lazy = false,
    dependencies = {
      { "hrsh7th/cmp-nvim-lsp", dir = helper.get_plugin_path("cmp-nvim-lsp") },
    },
    config = function()
      -- キーマップ設定
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_attach", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
          end

          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "Go to references")
          map("gI", vim.lsp.buf.implementation, "Go to implementation")
          map("gy", vim.lsp.buf.type_definition, "Go to type definition")
          map("gD", vim.lsp.buf.declaration, "Go to declaration")
          map("K", vim.lsp.buf.hover, "Hover documentation")
          map("<leader>cr", vim.lsp.buf.rename, "Rename")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>cf", function() vim.lsp.buf.format({ async = true }) end, "Format")
        end,
      })

      -- Neovim 0.11+ の新 API を使用
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- LSP サーバー設定 (vim.lsp.config)
      vim.lsp.config("nil_ls", {
        capabilities = capabilities,
      })

      vim.lsp.config("lua_ls", {
        capabilities = capabilities,
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      vim.lsp.config("ts_ls", {
        capabilities = capabilities,
      })

      vim.lsp.config("rust_analyzer", {
        capabilities = capabilities,
      })

      vim.lsp.config("gopls", {
        capabilities = capabilities,
      })

      vim.lsp.config("pyright", {
        capabilities = capabilities,
      })

      vim.lsp.config("marksman", {
        capabilities = capabilities,
      })

      vim.lsp.config("jsonls", {
        capabilities = capabilities,
      })

      vim.lsp.config("cssls", {
        capabilities = capabilities,
      })

      vim.lsp.config("html", {
        capabilities = capabilities,
      })

      -- LSP を有効化
      vim.lsp.enable({
        "nil_ls",
        "lua_ls",
        "ts_ls",
        "rust_analyzer",
        "gopls",
        "pyright",
        "marksman",
        "jsonls",
        "cssls",
        "html",
      })
    end,
  },

  -- Treesitter (Nixでプリビルド済み、設定のみ)
  {
    "nvim-treesitter/nvim-treesitter",
    dir = helper.get_plugin_path("nvim-treesitter"),
    lazy = false, -- 即時ロード
    config = function()
      -- Nix でビルド済みなので、基本設定のみ
      vim.opt.foldmethod = "expr"
      vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
      vim.opt.foldenable = false

      -- ハイライトは自動で有効になる
      -- incremental_selection のキーマップ
      vim.keymap.set("n", "<C-space>", function()
        require("nvim-treesitter.incremental_selection").init_selection()
      end, { desc = "Init selection" })
      vim.keymap.set("x", "<C-space>", function()
        require("nvim-treesitter.incremental_selection").node_incremental()
      end, { desc = "Node incremental" })
      vim.keymap.set("x", "<bs>", function()
        require("nvim-treesitter.incremental_selection").node_decremental()
      end, { desc = "Node decremental" })
    end,
  },
}
