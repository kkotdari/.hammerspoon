-----------------------------------------------------------------
-- Load your modules in order
--------------------------------------------------------------------
local versionEls = { "0", "2", "0" }
local version = table.concat(versionEls, ".")
local versionPath = table.concat(versionEls, "/")

require("release/" .. versionPath .. "/configs/stores") -- manage global shared state
require("release/" .. versionPath .. "/interceptors/keyHandler") -- fix NumPad modifier flags (if needed) and log key events
toast = require("release/" .. versionPath .. "/utils/toast") -- alert helper (toast notifications)
require("release/" .. versionPath .. "/modules/window") -- window management hotkeys
require("release/" .. versionPath .. "/modules/point") -- pointing‐device functionality

print("running version: ", version)
toast.showToast("You are using Hammerspoon toolkits version " .. version, 3)

local logTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(e)
    local code = e:getKeyCode()
    local chars = e:getCharacters(true)
    local flags = e:getFlags()
    print(string.format("KEYDOWN → keyCode=%d, chars='%s', flags=%s", code, chars, hs.inspect(flags)))
    return false
end)
logTap:start()