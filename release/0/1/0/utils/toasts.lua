local M          = {}
local APP_PATH   = "/Applications/GlassToaster.app"
local NOTIF_NAME = "GlassToaster.Toast"

--------------------------------------------------------------------
-- ensureAppRunning()
--   Launches GlassToaster.app in the background if it isn’t running.
--------------------------------------------------------------------
local function ensureAppRunning()
    if not hs.application.get("GlassToaster") then
        hs.task.new("/usr/bin/open", nil, { "-g", "-a", APP_PATH }):start()
        hs.timer.usleep(200000) -- 0.2 s to allow observer setup
    end
end

--------------------------------------------------------------------
-- M.showToast(message[, duration])
--   Sends toast message to GlassToaster via distributed notification.
--------------------------------------------------------------------
function M.showToast(message, duration)
    duration = duration or 2
    print(string.format("[GlassToaster] message='%s', duration=%s", message, duration))

    ensureAppRunning()

    local payload = hs.json.encode({
        message  = message,
        duration = duration
    })

    hs.distributednotifications.post(NOTIF_NAME, payload)
end

return M