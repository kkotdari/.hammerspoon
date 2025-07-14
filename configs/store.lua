--------------------------------------------------------------------
-- Global state declarations
--------------------------------------------------------------------
local M = {}

M.pointingsOn        = false      -- when true, pointing‐mode is active
M.allWindowHotkeys   = {}         -- populated by windows.lua
M.allPointingHotkeys = {}         -- populated by pointings.lua

--------------------------------------------------------------------
-- Common function to toggle any list of hotkeys on or off
--------------------------------------------------------------------
M.toggleHotkeys = function(hotkeyList, enabled)
  for _, hk in ipairs(hotkeyList) do
    if enabled then
      hk:enable()
    else
      hk:disable()
    end
  end
end

return M