local M          = {}
local APP_PATH   = "/Applications/GlassToaster.app"
local NOTIF_NAME = "GlassToaster.Toast"

-- Ensure GlassToaster is running
local function ensureAppRunning()
    if not hs.application.get("GlassToaster") then
        hs.task.new("/usr/bin/open", nil, { "-g", "-a", APP_PATH }):start()
        hs.timer.usleep(200000) -- wait briefly for the app to launch
    end
end

-- Show toast using structured JSON payload
function M.showToast(arg1, arg2)
    ensureAppRunning()

    local payload

    -- Case: showToast("message", duration)
    if type(arg1) == "string" then
        payload = {
            appName  = "Hammerspoon",
            bundleId = "org.hammerspoon.Hammerspoon",
            title    = arg1,
            subtitle = "",
            body     = "",
            duration = arg2 or 2.0
        }
    -- Case: showToast({ title=..., subtitle=..., ... })
    elseif type(arg1) == "table" then
        payload = {
            appName  = arg1.appName  or "Hammerspoon",
            bundleId = arg1.bundleId or "org.hammerspoon.Hammerspoon",
            title    = arg1.title    or "No Title",
            subtitle = arg1.subtitle or "",
            body     = arg1.body     or "",
            duration = arg1.duration or 2.0
        }
    else
        print("[GlassToaster] Invalid arguments to showToast()")
        return
    end

    local encoded = hs.json.encode(payload)
    print(string.format("[GlassToaster] JSON payload: %s", encoded))
    hs.distributednotifications.post(NOTIF_NAME, encoded)
end

return M