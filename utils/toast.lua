local M          = {}
local APP_PATH   = "/Applications/GlassToaster.app"
local NOTIF_NAME = "GlassToaster.Toast"

local function ensureAppRunning()
  if not hs.application.get("GlassToaster") then
    hs.task.new("/usr/bin/open", nil, { "-g", "-a", APP_PATH }):start()
    hs.timer.usleep(200000)
  end
end

local function normalizeFontInfo(input)
  if type(input) ~= "table" then return nil end

  local name                = input.name
  local size                = tonumber(input.size)
  local weight              = (input.weight == "Bold") and "Bold" or "Regular"
  local color               = input.color or "#000000"
  local kerning             = tonumber(input.kerning) or 0
  local lineHeightMultiple  = tonumber(input.lineHeightMultiple) or 0

  if not name or not size or not color then return nil end

  return {
    name               = name,
    size               = size,
    weight             = weight,
    color              = color,
    kerning            = kerning,
    lineHeightMultiple = lineHeightMultiple
  }
end

function M.showToast(titleOrSpec, duration, fontInfo)
  ensureAppRunning()

  local id = tostring(os.time()) .. tostring(math.random(100000, 999999))
  local spec = {
    id       = id,
    payload  = {
      appName  = "Hammerspoon",
      bundleId = "org.hammerspoon.Hammerspoon",
      title    = "",
      subtitle = "",
      body     = ""
    },
    duration = tonumber(duration) or 2.0,
    fontInfo = {
      name               = "",
      size               = 16.0,
      weight             = "Regular",
      color              = "#000000",
      kerning            = 0,
      lineHeightMultiple = 0
    }
  }

  if type(titleOrSpec) == "string" then
    spec.payload.title = titleOrSpec
    local f = normalizeFontInfo(fontInfo)
    if f then spec.fontInfo = f end
  elseif type(titleOrSpec) == "table" then
    local p = titleOrSpec
    spec.payload.appName  = p.appName  or spec.payload.appName
    spec.payload.bundleId = p.bundleId or spec.payload.bundleId
    spec.payload.title    = p.title    or spec.payload.title
    spec.payload.subtitle = p.subtitle or spec.payload.subtitle
    spec.payload.body     = p.body     or spec.payload.body
    spec.duration         = tonumber(p.duration) or spec.duration

    if p.fontInfo then
      local f = normalizeFontInfo(p.fontInfo)
      if f then spec.fontInfo = f end
    end
  else
    return
  end

  local json = hs.json.encode(spec)
  hs.printf("[HSToast] send toast: %s", spec.payload.title)
  hs.distributednotifications.post(NOTIF_NAME, nil, { json = json })
end

return M