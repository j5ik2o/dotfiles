return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      local lombok = vim.fn.expand("$MASON/share/jdtls/lombok.jar")
      local has_lombok = lombok ~= "" and vim.fn.filereadable(lombok) == 1
      if not has_lombok and type(opts.cmd) == "table" then
        local filtered = {}
        for _, arg in ipairs(opts.cmd) do
          if not arg:match("^%-%-jvm%-arg=%-javaagent:") then
            table.insert(filtered, arg)
          end
        end
        opts.cmd = filtered
      end
      return opts
    end,
  },
}
