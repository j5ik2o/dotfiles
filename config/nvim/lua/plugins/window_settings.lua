-- Window sizing behavior and resize keymaps
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = function(_, opts)
    opts.options = opts.options or {}
    opts.options.opt = opts.options.opt or {}
    -- Avoid equalizing all window sizes when closing/opening splits
    opts.options.opt.equalalways = false

    local maps = opts.mappings
    maps.n = maps.n or {}
    -- Window resize shortcuts (match previous LazyVim style)
    maps.n["<Leader>wh"] = { "<Cmd>vertical resize -2<CR>", desc = "Decrease window width" }
    maps.n["<Leader>wl"] = { "<Cmd>vertical resize +2<CR>", desc = "Increase window width" }
    maps.n["<Leader>wj"] = { "<Cmd>resize -2<CR>", desc = "Decrease window height" }
    maps.n["<Leader>wk"] = { "<Cmd>resize +2<CR>", desc = "Increase window height" }
    maps.n["<Leader>w="] = { "<C-w>=", desc = "Equal window size" }
  end,
}
