-- Terminal keymaps
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = function(_, opts)
    local maps = opts.mappings
    maps.t = maps.t or {}
    maps.n = maps.n or {}
    -- Exit terminal mode with <Esc><Esc>
    maps.t["<Esc><Esc>"] = { "<C-\\><C-n>", desc = "Exit terminal mode" }
    -- Numbered terminals
    maps.n["<Leader>t1"] = { "<Cmd>1ToggleTerm<CR>", desc = "Terminal #1" }
    maps.n["<Leader>t2"] = { "<Cmd>2ToggleTerm<CR>", desc = "Terminal #2" }
    maps.n["<Leader>t3"] = { "<Cmd>3ToggleTerm<CR>", desc = "Terminal #3" }
    maps.n["<Leader>t4"] = { "<Cmd>4ToggleTerm<CR>", desc = "Terminal #4" }
  end,
}
