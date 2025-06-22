local M          = {}
local APP_PATH   = "/Applications/GlassToaster.app"
local NOTIF_NAME = "GlassToaster.Toast"

local function ensureAppRunning()
    if not hs.application.get("GlassToaster") then
        hs.task.new("/usr/bin/open", nil, { "-g", "-a", APP_PATH }):start()
        hs.timer.usleep(200000)
    end
end

function M.showToast(titleOrSpec, duration, fontInfo)
    ensureAppRunning()

    local spec = {
        payload = {
            appName  = "Hammerspoon",
            bundleId = "org.hammerspoon.Hammerspoon",
            title    = "",
            subtitle = "",
            body     = ""
        },
        duration = 2.0,
        fontInfo = {
            name   = "",
            size   = "",
            weight = "",
            color  = nil,
            kerning = "1.2"
        }
    }

    if type(titleOrSpec) == "string" then
        spec.payload.title = titleOrSpec
        if type(duration) == "number" then
            spec.duration = duration
        end
        if type(fontInfo) == "table" then
            local f = fontInfo
            spec.fontInfo.name   = f.name   or spec.fontInfo.name
            spec.fontInfo.size   = f.size   or spec.fontInfo.size
            spec.fontInfo.weight = (f.weight == "Bold") and "Bold" or "Regular"
            if f.color ~= nil then spec.fontInfo.color = f.color end
            spec.fontInfo.kerning = f.kerning or spec.fontInfo.kerning
        end

    elseif type(titleOrSpec) == "table" then
        local p = titleOrSpec
        spec.payload.appName  = p.appName  or spec.payload.appName
        spec.payload.bundleId = p.bundleId or spec.payload.bundleId
        spec.payload.title    = p.title    or spec.payload.title
        spec.payload.subtitle = p.subtitle or spec.payload.subtitle
        spec.payload.body     = p.body     or spec.payload.body
        spec.duration         = p.duration or spec.duration

        if p.fontInfo then
            local f = p.fontInfo
            spec.fontInfo.name   = f.name   or spec.fontInfo.name
            spec.fontInfo.size   = f.size   or spec.fontInfo.size
            spec.fontInfo.weight = (f.weight == "Bold") and "Bold" or "Regular"
            if f.color ~= nil then spec.fontInfo.color = f.color end
            spec.fontInfo.kerning = f.kerning or spec.fontInfo.kerning
        end
    else
        return
    end

    local json = hs.json.encode(spec)
    hs.distributednotifications.post(NOTIF_NAME, nil, { json = json })
end

return M