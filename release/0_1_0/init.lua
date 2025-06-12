-----------------------------------------------------------------
-- Load your modules in order
--------------------------------------------------------------------
local version = "0_1_0"

require("release/" .. version .. "/configs/stores")                -- manage global shared state
require("release/" .. version .. "/interceptors/keys")             -- fix NumPad modifier flags (if needed) and log key events
toast      = require("release/" .. version .. "/utils/toasts")     -- alert helper (toast notifications)
indicator  = require("release/" .. version .. "/utils/indicators") -- indicator helper (indicate various states)
require("release/" .. version .. "/modules/windows")               -- window management hotkeys
require("release/" .. version .. "/modules/pointings")             -- pointing‐device functionality
require("release/" .. version .. "/modules/capture")               -- screenshot to clipboard/file helper

print("runiing version: 0.1.0")

local appPath = "/Applications/GlassToasts.app"
local function sendToast(msg, dur)
  hs.task.new("/usr/bin/open", nil, {
    "-g", "-a", appPath,
    "--args", msg, tostring(dur)
  }):start()
end

hs.hotkey.bind({"cmd","alt"}, "G", function()
  sendToast("🍃 HS Toast!", 2)
end)