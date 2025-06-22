-----------------------------------------------------------------
-- Load your modules in order
--------------------------------------------------------------------
local versionEls = { "0", "1", "0" }
local version = table.concat(versionEls, ".")
local versionPath = table.concat(versionEls, "/")

require("release/" .. versionPath .. "/configs/stores")                      -- manage global shared state
require("release/" .. versionPath .. "/interceptors/keyHandler")             -- fix NumPad modifier flags (if needed) and log key events
toast      = require("release/" .. versionPath .. "/utils/toast")            -- alert helper (toast notifications)
indicator  = require("release/" .. versionPath .. "/utils/indicator")        -- indicator helper (indicate various states)
require("release/" .. versionPath .. "/modules/organizeWindows")             -- window management hotkeys
require("release/" .. versionPath .. "/modules/point")                       -- pointing‐device functionality
require("release/" .. versionPath .. "/modules/capture")                     -- screenshot to clipboard/file helper
windowHelper = require("release/" .. versionPath .. "/modules/windowHelper") -- window management helper

print("running version: ", version)
toast.showToast("🙂 Welcome to Hammerspoon toolkits. You are using version " .. version, 3)