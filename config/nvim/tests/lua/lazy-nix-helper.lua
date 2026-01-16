-- Stub helper for headless tests.
local M = {}

function M.get_plugin_path(name)
  return "/tmp/nvim-test/" .. name
end

return M
