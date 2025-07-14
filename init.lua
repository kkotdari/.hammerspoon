-----------------------------------------------------------------
-- Load your modules in order
--------------------------------------------------------------------
local version = "0.3.0"

store = require("/configs/store") -- manage global shared state
toast = require("/utils/toast") -- alert helper (toast notifications)

require("/interceptors/keyHandler") -- fix NumPad modifier flags (if needed) and log key events
require("/modules/window") -- window management hotkeys
require("/modules/point") -- pointing‐device functionality

print("running version: ", version)
toast.showToast("You are using Hammerspoon toolkits version " .. version, 3)