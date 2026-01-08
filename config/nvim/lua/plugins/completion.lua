-- ============================================================
-- 補完
-- ============================================================

local helper = require("lazy-nix-helper")

return {
  -- 補完エンジン
  {
    "hrsh7th/nvim-cmp",
    dir = helper.get_plugin_path("nvim-cmp"),
    event = "InsertEnter",
    dependencies = {
      { "hrsh7th/cmp-nvim-lsp", dir = helper.get_plugin_path("cmp-nvim-lsp") },
      { "hrsh7th/cmp-buffer", dir = helper.get_plugin_path("cmp-buffer") },
      { "hrsh7th/cmp-path", dir = helper.get_plugin_path("cmp-path") },
      { "L3MON4D3/LuaSnip", dir = helper.get_plugin_path("luasnip") },
      { "saadparwaiz1/cmp_luasnip", dir = helper.get_plugin_path("cmp_luasnip") },
      { "rafamadriz/friendly-snippets", dir = helper.get_plugin_path("friendly-snippets") },
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      -- friendly-snippets をロード
      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
        formatting = {
          format = function(entry, vim_item)
            vim_item.menu = ({
              nvim_lsp = "[LSP]",
              luasnip = "[Snip]",
              buffer = "[Buf]",
              path = "[Path]",
            })[entry.source.name]
            return vim_item
          end,
        },
      })
    end,
  },
}
