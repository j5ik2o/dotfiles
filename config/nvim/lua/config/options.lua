-- ============================================================
-- Options (LazyVim defaults + custom overrides)
-- ============================================================
-- LazyVim provides sensible defaults. Only override what's different.
-- See: https://www.lazyvim.org/configuration/general
-- ============================================================

local opt = vim.opt

-- Line numbers: use absolute instead of relative (LazyVim default)
opt.relativenumber = false

-- Mouse: enable movement events for hover
opt.mousemoveevent = true

-- Window borders
opt.fillchars = {
  horiz = "━",
  horizup = "┻",
  horizdown = "┳",
  vert = "┃",
  vertleft = "┫",
  vertright = "┣",
  verthoriz = "╋",
}

-- Folding: disable by default (override LazyVim's UFO folding)
opt.foldenable = false

-- Spell check: disable (problematic with Japanese text)
opt.spell = false
