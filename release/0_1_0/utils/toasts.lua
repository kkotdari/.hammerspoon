--------------------------------------------------------------------
-- showToast(message[, duration])
--   1) kick off push-animation in parallel
--   2) draw & track the new toast immediately
--------------------------------------------------------------------
local json = require("hs.json")

--- showToast(text, duration)
-- @param text     The message to display
-- @param duration How long (in seconds) the toast stays on screen
function showToast(text, duration)
  duration = duration or 2.0
  local payload = json.encode({ message = text, duration = duration })
  hs.distributednotifications.post("GlassToaster.Toast", payload)
end

return { showToast = showToast }