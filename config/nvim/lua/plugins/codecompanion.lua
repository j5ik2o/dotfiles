return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "MunifTanjim/nui.nvim",
    },
    cmd = {
      "CodeCompanion",
      "CodeCompanionChat",
      "CodeCompanionActions",
    },
    keys = {
      { "<leader>aa", "<cmd>CodeCompanionChat Toggle<cr>", desc = "Chat Toggle", mode = { "n", "v" } },
      { "<leader>ax", "<cmd>CodeCompanionChat Clear<cr>", desc = "Chat Clear" },
      { "<leader>ap", "<cmd>CodeCompanionActions<cr>", desc = "Action Palette", mode = { "n", "v" } },
      { "<leader>ai", "<cmd>CodeCompanion<cr>", desc = "Inline Assist", mode = { "n", "v" } },
    },
    opts = {
      adapters = {
        claude_code = function()
          return require("codecompanion.adapters").extend("claude_code", {})
        end,
      },
      strategies = {
        chat = {
          adapter = "claude_code",
        },
        inline = {
          adapter = "claude_code",
        },
        cmd = {
          adapter = "claude_code",
        },
      },
      display = {
        chat = {
          window = {
            layout = "vertical",
            position = "right",
            width = 0.35,
          },
        },
      },
    },
  },
}
