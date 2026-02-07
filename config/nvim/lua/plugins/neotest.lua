return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/neotest-python",
      "nvim-neotest/neotest-go",
      "rcasia/neotest-java",
      "stevanmilic/neotest-scala",
      "mrcjkb/rustaceanvim",
    },
    opts = {
      adapters = {
        ["neotest-python"] = {},
        ["neotest-go"] = {},
        ["neotest-java"] = {},
        ["neotest-scala"] = {},
        ["rustaceanvim.neotest"] = {},
      },
    },
  },
}
