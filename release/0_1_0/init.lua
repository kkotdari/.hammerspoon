-----------------------------------------------------------------
-- Load your modules in order
--------------------------------------------------------------------
local version = "0_1_0"

require("release/" .. version .. "/configs/stores")                -- manage global shared state
require("release/" .. version .. "/interceptors/keyHandler")       -- fix NumPad modifier flags (if needed) and log key events
toast      = require("release/" .. version .. "/utils/toasts")     -- alert helper (toast notifications)
indicator  = require("release/" .. version .. "/utils/indicators") -- indicator helper (indicate various states)
require("release/" .. version .. "/modules/organizeWindows")       -- window management hotkeys
require("release/" .. version .. "/modules/point")                 -- pointing‐device functionality
require("release/" .. version .. "/modules/capture")               -- screenshot to clipboard/file helper

print("runiing version: 0.1.0")