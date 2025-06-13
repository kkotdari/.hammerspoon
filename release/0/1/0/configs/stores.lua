--------------------------------------------------------------------
-- Global state declarations
--------------------------------------------------------------------
_G.pointingsOn        = false      -- when true, pointing‐mode is active
_G.allWindowHotkeys   = {}         -- populated by windows.lua
_G.allPointingHotkeys = {}         -- populated by pointings.lua

--------------------------------------------------------------------
-- Common function to toggle any list of hotkeys on or off
--------------------------------------------------------------------
_G.toggleHotkeys = function(hotkeyList, enabled)
    for _, hk in ipairs(hotkeyList) do
        if enabled then
            hk:enable()
        else
            hk:disable()
        end
    end
end