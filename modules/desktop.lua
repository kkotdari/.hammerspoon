local application = hs.application
local window      = hs.window
local screen      = hs.screen
local spaces      = hs.spaces
local timer       = hs.timer
local json        = hs.json
local hotkey      = hs.hotkey
local fnutils     = hs.fnutils

local M = {}

-- config
local layoutFile            = hs.configdir .. "/desktopLayout.json"
local SAVE_DWELL_SEC        = 0.35
local RESTORE_DWELL_SEC     = 1.0      -- initial settle after gotoSpace & launch
local RESTORE_POLL_SEC      = 0.25     -- poll interval while waiting for windows
local RESTORE_WAIT_SEC      = 10.0     -- max wait per space before giving up
local KILL_APPS_ON_RESTORE  = false

-- util
local function screenUUID(scr)
  return scr and scr:getUUID() or "unknown"
end

local function spaceSequence()
  local seq = {}
  local screens = screen.allScreens()
  table.sort(screens, function(a, b) return a:frame().x < b:frame().x end)
  local all = spaces.allSpaces()
  for _, scr in ipairs(screens) do
    local uuid = screenUUID(scr)
    local list = all[uuid] or {}
    for i, sid in ipairs(list) do
      seq[#seq + 1] = { sid = sid, screen = scr, screenUUID = uuid, index = i }
    end
  end
  return seq
end

local function gotoSpaceBlocking(sid, dwellSec, cb)
  spaces.gotoSpace(sid)
  timer.doAfter(dwellSec or SAVE_DWELL_SEC, cb)
end

local function windowRecord(win)
  local f = win:frame()
  return {
    app   = (win:application() and win:application():bundleID()) or "",
    title = win:title() or "",
    frame = { x = f.x, y = f.y, w = f.w, h = f.h }
  }
end

-- save (new format: { meta={active=...}, spaces=[...] })
function M.saveDesktopLayout(path)
  local target = path or layoutFile
  local seq = spaceSequence()
  local result = {}
  local i = 0

  local origActive = spaces.activeSpaces()
  local allSpacesMap = spaces.allSpaces()
  local activeMeta = {}
  for suuid, sid in pairs(origActive) do
    local idx
    local list = allSpacesMap[suuid] or {}
    for j, s in ipairs(list) do
      if s == sid then idx = j break end
    end
    activeMeta[suuid] = { spaceID = sid, spaceIndex = idx }
  end

  local origSids = {}
  for _, sid in pairs(origActive) do
    origSids[#origSids + 1] = sid
  end

  local function finish()
    local payload = { meta = { active = activeMeta }, spaces = result }
    local encoded = json.encode(payload)
    local fh, err = io.open(target, "w")
    if not fh then
      print("desktop > save write error:", err)
      return
    end
    fh:write(encoded)
    fh:close()
    for _, sid in ipairs(origSids) do
      spaces.gotoSpace(sid)
    end
    toast.showToast("스페이스 구성 업데이트 완료", 2.0)
  end

  local function step()
    i = i + 1
    local entry = seq[i]
    if not entry then
      finish()
      return
    end
    gotoSpaceBlocking(entry.sid, SAVE_DWELL_SEC, function()
      local wins = window.visibleWindows()
      local recs = {}
      for _, win in ipairs(wins) do
        if win:isStandard() then
          recs[#recs + 1] = windowRecord(win)
        end
      end
      result[#result + 1] = {
        screenUUID = entry.screenUUID,
        spaceIndex = entry.index,
        windows    = recs
      }
      step()
    end)
  end

  step()
end

-- current space index map
local function currentSpacesIndex()
  local m = {}
  local all = spaces.allSpaces()
  for scrUUID, list in pairs(all) do
    local idx = {}
    for i, sid in ipairs(list) do idx[sid] = i end
    m[scrUUID] = { list = list, idx = idx }
  end
  return m
end

-- resolve screen from UUID
local function screenForUUID(uuid)
  for _, scr in ipairs(screen.allScreens()) do
    if scr:getUUID() == uuid then return scr end
  end
  return screen.primaryScreen()
end

-- ensure number of spaces
local function ensureSpacesForScreen(scr, wantedCount)
  local uuid = screenUUID(scr)
  local curList = spaces.spacesForScreen(scr) or {}
  local curCount = #curList
  while curCount < wantedCount do
    local ok = pcall(spaces.addSpaceToScreen, scr)
    if not ok then
      print("desktop > addSpace fail for screen", uuid)
      break
    end
    curList = spaces.spacesForScreen(scr) or curList
    curCount = #curList
  end
  while curCount > wantedCount do
    local sid = curList[#curList]
    local ok = pcall(spaces.removeSpace, sid)
    if not ok then
      print("desktop > removeSpace fail, sid=", sid)
      break
    end
    curList = spaces.spacesForScreen(scr) or curList
    curCount = #curList
  end
  return spaces.spacesForScreen(scr) or curList
end

-- running?
local function isBundleRunning(bundleID)
  local t = application.applicationsForBundleID(bundleID)
  return t and #t > 0
end

-- launch once
local launchedCache = {}
local function ensureAppLaunched(bundleID)
  if not bundleID or bundleID == "" then return end
  if launchedCache[bundleID] then return end
  if not isBundleRunning(bundleID) then
    application.launchOrFocusByBundleID(bundleID)
  end
  launchedCache[bundleID] = true
end

-- find specific window
local function findWindow(bundleID, title)
  if not bundleID then return nil end
  for _, appObj in ipairs(application.applicationsForBundleID(bundleID) or {}) do
    for _, win in ipairs(appObj:allWindows()) do
      if win:isStandard() and (win:title() or "") == (title or "") then
        return win
      end
    end
  end
  return nil
end

-- apply frame
local function applyFrame(win, frame)
  if not (win and frame) then return end
  win:setFrame(frame, 0)
end

-- wait until all (or timeout) windows for a saved space exist; move & frame them as they appear
local function realizeSpaceWindows(savedSpace, targetSID, doneCb)
  local winspecs = savedSpace.windows or {}
  if #winspecs == 0 then
    doneCb()
    return
  end
  for _, ws in ipairs(winspecs) do
    ensureAppLaunched(ws.app)
  end
  local seen = {}
  local waited = 0
  local function poll()
    local allFound = true
    for i, ws in ipairs(winspecs) do
      if not seen[i] then
        local w = findWindow(ws.app, ws.title)
        if w then
          spaces.moveWindowToSpace(w, targetSID)
          applyFrame(w, ws.frame)
          seen[i] = true
        else
          allFound = false
        end
      end
    end
    if allFound or waited >= RESTORE_WAIT_SEC then
      doneCb()
    else
      waited = waited + RESTORE_POLL_SEC
      timer.doAfter(RESTORE_POLL_SEC, poll)
    end
  end
  timer.doAfter(RESTORE_DWELL_SEC, poll)
end

-- restore
function M.restoreDesktopLayout(path)
  local target = path or layoutFile
  local fh = io.open(target, "r")
  if not fh then
    toast.showToast("스페이스 구성 없음", 2.0)
    return
  end
  local raw = fh:read("*a")
  fh:close()
  local ok, data = pcall(json.decode, raw)
  if not ok or type(data) ~= "table" then
    toast.showToast("스페이스 구성 없음", 2.0)
    return
  end
  local activeMeta
  local savedSpaces
  if data.meta and data.spaces then
    activeMeta  = data.meta.active or {}
    savedSpaces = data.spaces
  else
    activeMeta  = nil
    savedSpaces = data
  end
  if type(savedSpaces) ~= "table" or #savedSpaces == 0 then
    toast.showToast("스페이스 구성 없음", 2.0)
    return
  end
  local grouped = {}
  for _, sp in ipairs(savedSpaces) do
    grouped[sp.screenUUID] = grouped[sp.screenUUID] or {}
    table.insert(grouped[sp.screenUUID], sp)
  end
  for _, arr in pairs(grouped) do
    table.sort(arr, function(a, b) return (a.spaceIndex or 1) < (b.spaceIndex or 1) end)
  end
  if KILL_APPS_ON_RESTORE then
    for _, appObj in ipairs(application.runningApplications()) do
      local bid = appObj:bundleIdentifier()
      if bid ~= "org.hammerspoon.Hammerspoon" then
        appObj:kill()
      end
    end
    hs.timer.usleep(500000)
  end
  launchedCache = {}
  local screensOrder = {}
  for scrUUID, _ in pairs(grouped) do
    screensOrder[#screensOrder + 1] = scrUUID
  end
  table.sort(screensOrder, function(a, b)
    local sa = screenForUUID(a):frame().x
    local sb = screenForUUID(b):frame().x
    return sa < sb
  end)
  local focusSIDs = {}
  if activeMeta then
    local curMap = currentSpacesIndex()
    for suuid, meta in pairs(activeMeta) do
      local entry = curMap[suuid]
      if entry then
        local sid = meta.spaceID
        if not entry.idx[sid] and meta.spaceIndex and entry.list[meta.spaceIndex] then
          sid = entry.list[meta.spaceIndex]
        end
        if sid then focusSIDs[#focusSIDs + 1] = sid end
      end
    end
  end
  local sIdx = 0
  local function stepScreen()
    sIdx = sIdx + 1
    local suuid = screensOrder[sIdx]
    if not suuid then
      if #focusSIDs > 0 then
        for _, sid in ipairs(focusSIDs) do
          spaces.gotoSpace(sid)
        end
      end
      toast.showToast("스페이스 구성 복구 완료", 2.0)
      return
    end
    local scr = screenForUUID(suuid)
    local savedSpacesForScreen = grouped[suuid]
    local wantedCount = #savedSpacesForScreen
    local curList = ensureSpacesForScreen(scr, wantedCount)
    local spIdx = 0
    local function stepSpace()
      spIdx = spIdx + 1
      local savedSpace = savedSpacesForScreen[spIdx]
      if not savedSpace then
        stepScreen()
        return
      end
      local targetSID = curList[spIdx] or curList[#curList]
      spaces.gotoSpace(targetSID)
      realizeSpaceWindows(savedSpace, targetSID, function()
        stepSpace()
      end)
    end
    stepSpace()
  end
  stepScreen()
end

-- readiness check
local function _readyForRestore()
  local finder = application.get("Finder")
  if not finder then return false end
  local all = spaces.allSpaces()
  if not all or next(all) == nil then return false end
  return true
end

function M.deferRestore(path, opts)
  opts = opts or {}
  local interval = opts.interval or 0.5
  local timeout  = opts.timeout  or 30
  local waited   = 0
  timer.doUntil(
    function()
      if _readyForRestore() then
        M.restoreDesktopLayout(path)
        return true
      end
      waited = waited + interval
      if waited >= timeout then
        print("desktop > deferRestore timeout; skipping auto-restore")
        return true
      end
      return false
    end,
    interval
  )
end

-- manual save: cmd+ctrl+Insert (keycode 114)
hotkey.bind({ "cmd", "ctrl" }, 114, function()
  M.saveDesktopLayout()
end)

return M