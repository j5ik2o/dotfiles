return {
  {
    "mrcjkb/rustaceanvim",
    init = function()
      -- Use rustaceanvim as the entrypoint and run rust-analyzer from PATH (Nix-managed).
      vim.g.rustaceanvim = {
        server = {
          cmd = { "rust-analyzer" },
        },
      }
    end,
  },
}
