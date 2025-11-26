-----------------------------------------------------------------
-- Load your modules in order
--------------------------------------------------------------------
local version = "0.4.0"

store = require("/configs/store")
toast = require("/utils/toast")
-- desktop = require("/modules/desktop")

require("/interceptors/keyHandler")
-- require("/modules/window")
require("/modules/simpleWindow")
require("/modules/point")

print("running version: ", version)
toast.showToast("Hammerspoon toolkits v " .. version, 3)

print("init > schedule deferred restore")
-- desktop.deferRestore()