local M          = {}
local APP_PATH   = "/Applications/GlassToaster.app"
local NOTIF_NAME = "GlassToaster.Toast"

--------------------------------------------------------------------
-- ensureAppRunning()
--   Launches GlassToaster.app in the background if it isn’t running.
--------------------------------------------------------------------
local function ensureAppRunning()
    if not hs.application.get("GlassToaster") then
        -- Launch in background (-g) without bringing it to the front
        hs.task.new("/usr/bin/open", nil, { "-g", "-a", APP_PATH }):start()
        -- Optional short delay to give the app time to register its observer
        hs.timer.usleep(200) -- 0.2 s
    end
end

--------------------------------------------------------------------
-- M.showToast(message[, duration])
--------------------------------------------------------------------
function M.showToast(message, duration)
    duration = duration or 2
    print(string.format("[GlassToaster] message='%s', duration=%s", message, duration))

    ensureAppRunning()

    -- Build JSON payload
    local payload = hs.json.encode({
        message  = message,
        duration = duration
    })

    -- Post distributed notification
    hs.distributednotifications.post(NOTIF_NAME, payload)
end

return M