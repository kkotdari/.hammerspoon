-----------------------------------------------------------------
-- Load your modules in order
--------------------------------------------------------------------
local version = "0.4.0"

store = require("/configs/store")
toast = require("/utils/toast")
desktop = require("/modules/desktop")

require("/interceptors/keyHandler")
require("/modules/window")
require("/modules/point")

print("running version: ", version)
toast.showToast("You are using Hammerspoon toolkits version " .. version, 3)

hs.timer.doAfter(1, function()
  print("init > start restoring layout")
  desktop.restoreDesktopLayout()
end)