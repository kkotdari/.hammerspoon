--------------------------------------------------------------------
-- showToast(message[, duration])
--   1) request new toast immediately
--------------------------------------------------------------------
local appPath = "/Applications/GlassToasts.app"

local function showToast(message, duration)
    hs.task.new("/usr/bin/open", nil, {
        "-g", "-a", appPath,
        "--args", message, tostring(duration)
    })
end

return {
    showToast = showToast
}