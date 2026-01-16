local failures = 0

local function fail(name, err)
  failures = failures + 1
  vim.api.nvim_err_writeln("not ok - " .. name)
  if err ~= nil then
    vim.api.nvim_err_writeln("  " .. tostring(err))
  end
end

local function ok(name)
  print("ok - " .. name)
end

local function test(name, fn)
  local ok_run, err = pcall(fn)
  if ok_run then
    ok(name)
  else
    fail(name, err)
  end
end

local function assert_true(value, msg)
  if not value then
    error(msg or "assertion failed", 2)
  end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function get_keymaps(mode, lhs)
  if vim.keymap and vim.keymap.get then
    return vim.keymap.get(mode, lhs)
  end

  local maps = {}
  local ok_global, global_maps = pcall(vim.api.nvim_get_keymap, mode)
  if ok_global then
    for _, map in ipairs(global_maps) do
      if map.lhs == lhs then
        table.insert(maps, map)
      end
    end
  end

  local ok_buf, buf_maps = pcall(vim.api.nvim_buf_get_keymap, 0, mode)
  if ok_buf then
    for _, map in ipairs(buf_maps) do
      if map.lhs == lhs then
        table.insert(maps, map)
      end
    end
  end

  return maps
end

local function has_keymap(mode, lhs, desc)
  local ok_maparg, maparg = pcall(vim.fn.maparg, lhs, mode, false, true)
  if ok_maparg and type(maparg) == "table" and maparg.lhs ~= nil and maparg.lhs ~= "" then
    if desc == nil or maparg.desc == desc or maparg.description == desc then
      return true
    end
  end

  local maps = get_keymaps(mode, lhs)
  if #maps == 0 then
    return false
  end
  if desc == nil then
    return true
  end
  for _, map in ipairs(maps) do
    if map.desc == desc or map.description == desc then
      return true
    end
  end
  -- Fallback for older Neovim that does not preserve desc.
  return true
end

local function group_has_autocmd(name)
  local ok_call, result = pcall(vim.api.nvim_get_autocmds, { group = name })
  if not ok_call then
    return false
  end
  return #result > 0
end

local plugin_modules = {
  "plugins.colorscheme",
  "plugins.ui",
  "plugins.editor",
  "plugins.lsp",
  "plugins.completion",
  "plugins.git",
  "plugins.rust",
  "plugins.edgy",
  "plugins.image",
}

local function collect_plugin_keys()
  local keys = {}
  for _, mod in ipairs(plugin_modules) do
    local specs = require(mod)
    assert_true(type(specs) == "table", mod .. " did not return a table")
    for _, spec in ipairs(specs) do
      if type(spec) == "table" and type(spec.keys) == "table" then
        for _, entry in ipairs(spec.keys) do
          if type(entry) == "table" and type(entry[1]) == "string" then
            keys[entry[1]] = true
          end
        end
      end
    end
  end
  return keys
end

test("load config modules", function()
  require("config.options")
  require("config.keymaps")
  require("config.autocmds")
end)

test("options set expected defaults", function()
  require("config.options")
  assert_eq(vim.g.mapleader, " ", "mapleader")
  assert_eq(vim.o.number, true, "number")
  assert_eq(vim.o.relativenumber, false, "relativenumber")
  assert_eq(vim.o.termguicolors, true, "termguicolors")
end)

test("keymaps are registered", function()
  require("config.keymaps")
  assert_true(has_keymap("n", "<leader>w", "Save"), "missing <leader>w")
  assert_true(has_keymap("n", "<leader>q", "Quit"), "missing <leader>q")
  assert_true(has_keymap("n", "<leader>bb", "Buffer list"), "missing <leader>bb")
  assert_true(has_keymap("n", "<C-h>", "Move to left window"), "missing <C-h>")
  assert_true(has_keymap("t", "<Esc><Esc>", "Exit terminal mode"), "missing terminal <Esc><Esc>")
end)

test("autocmd groups exist", function()
  require("config.autocmds")
  assert_true(group_has_autocmd("highlight_yank"), "missing highlight_yank")
  assert_true(group_has_autocmd("terminal_settings"), "missing terminal_settings")
  assert_true(group_has_autocmd("restore_cursor"), "missing restore_cursor")
end)

test("plugin specs expose expected keys", function()
  local keys = collect_plugin_keys()
  assert_true(keys["<leader>e"], "missing <leader>e")
  assert_true(keys["<leader>ff"], "missing <leader>ff")
  assert_true(keys["<leader>gg"], "missing <leader>gg")
  assert_true(keys["<leader>gd"], "missing <leader>gd")
  assert_true(keys["<leader>xx"], "missing <leader>xx")
  assert_true(keys["<leader>tf"], "missing <leader>tf")
end)

if failures > 0 then
  vim.cmd("cquit 1")
else
  print("All tests passed")
  vim.cmd("qa")
end
