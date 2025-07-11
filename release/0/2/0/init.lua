-----------------------------------------------------------------
-- Load your modules in order
--------------------------------------------------------------------
local versionEls = { "0", "2", "0" }
local version = table.concat(versionEls, ".")
local versionPath = table.concat(versionEls, "/")

require("release/" .. versionPath .. "/configs/stores")                      -- manage global shared state
require("release/" .. versionPath .. "/interceptors/keyHandler")             -- fix NumPad modifier flags (if needed) and log key events
toast = require("release/" .. versionPath .. "/utils/toast")            -- alert helper (toast notifications)
require("release/" .. versionPath .. "/modules/organizeWindows")             -- window management hotkeys
require("release/" .. versionPath .. "/modules/point")                       -- pointing‐device functionality

print("running version: ", version)
toast.showToast("You are using Hammerspoon toolkits version " .. version, 3)