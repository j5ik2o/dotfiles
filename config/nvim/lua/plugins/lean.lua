-- ============================================================
-- Lean 4 support (lean.nvim)
-- ============================================================

return {
  {
    "Julian/lean.nvim",
    event = { "BufReadPre *.lean", "BufNewFile *.lean" },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    main = "lean",
    opts = {
      mappings = true,
    },
  },
}
