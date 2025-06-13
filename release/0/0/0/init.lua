-----------------------------------------------------------------
-- Load your modules in order
--------------------------------------------------------------------
local versionEls = { "0", "0", "0" }
local version = table.concat(versionEls, ".")
local versionPath = table.concat(versionEls, "/")

require("release/" .. versionPath .. "/configs/stores")                -- manage global shared state
require("release/" .. versionPath .. "/interceptors/keys")             -- fix NumPad modifier flags (if needed) and log key events
toast      = require("release/" .. versionPath .. "/utils/toasts")     -- alert helper (toast notifications)
indicator  = require("release/" .. versionPath .. "/utils/indicators") -- indicator helper (indicate various states)
require("release/" .. versionPath .. "/modules/windows")               -- window management hotkeys
require("release/" .. versionPath .. "/modules/pointings")             -- pointing‐device functionality
require("release/" .. versionPath .. "/modules/capture")               -- screenshot to clipboard/file helper

print("running version: ", version)
toast.showToast("🙂 Welcome to Hammerspoon toolkits. You are using version " .. version, 3)