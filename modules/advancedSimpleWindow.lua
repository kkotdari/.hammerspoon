local hotkey = hs.hotkey
local spaces  = hs.spaces
local screen  = hs.screen
local window  = hs.window
local fnutils = hs.fnutils
local wfilter = hs.window.filter
local timer = hs.timer
local inspect = hs.inspect
hs.window.animationDuration = 0

local PAD1, PAD2, PAD3 = 83, 84, 85
local PAD4, PAD5, PAD6 = 86, 87, 88
local PAD7, PAD8, PAD9 = 89, 91, 92
local PAD_ENTER = 76
local PAD_DOT = 65
local PAD0  = 82
local PAD_DIV = 75
local PAD_MUL = 67
local PAD_PLUS = 69

local MODS = {"cmd", "ctrl"}
local windowStates = {}

local isProgrammaticWindows = {}

local function toUnitRect(f, sf)
  return {
    x = (f.x - sf.x) / sf.w,
    y = (f.y - sf.y) / sf.h,
    w = f.w / sf.w,
    h = f.h / sf.h
  }
end

local function clampFrame(f, uf)
  f.x = math.max(uf.x, math.min(f.x, uf.x + uf.w - f.w))
  f.y = math.max(uf.y, math.min(f.y, uf.y + uf.h - f.h))
  return f
end

local function ensureWindowState(win)
  local id = win:id()
  if not windowStates[id] then
    windowStates[id] = {
      orig = nil,
      lastUnit = nil,
      targetUnit = nil,
      lastDir = nil,
      step = 1,
      mode = 'preset',
      targetSize = nil
    }
  end
  local st = windowStates[id]
  if not st.orig then
    local f, sf = win:frame(), win:screen():frame()
    st.orig = toUnitRect(f, sf)
    st.lastUnit = st.orig
    st.targetUnit = st.orig
  end
  return st
end

local function logWindowState(win, event)
  local st = ensureWindowState(win)
  local app = win:application()
  local appName = app and app:name() or "N/A"

  local logMessage = string.format("--- Window State Log ---\nEvent: %s\nWindow ID: %s\nApp: %s\nTitle: %s",
    event,
    win:id(),
    appName,
    win:title()
  )
  print(logMessage)
  print("State Properties:")
  print(inspect(st))
  print("------------------------")
end

local function applyAndClamp(win, unit)
  local winId = win:id()
  if isProgrammaticWindows[winId] then
    isProgrammaticWindows[winId] = isProgrammaticWindows[winId] + 1
  else
    isProgrammaticWindows[winId] = 1
  end

  win:moveToUnit(unit, 0)
  local f2 = win:frame()
  local uf = win:screen():frame()
  win:setFrame(clampFrame(f2, uf), 0)

  local st = ensureWindowState(win)
  st.lastUnit = toUnitRect(win:frame(), win:screen():frame())

  timer.doAfter(1.5, function()
    isProgrammaticWindows[winId] = isProgrammaticWindows[winId] - 1
  end)

  logWindowState(win, "Script Move/Resize")
end

local function activeWindow()
  return window.focusedWindow() or window.frontmostWindow()
end

local dirMap = {
  ["1"] = {xAlign="left", yAlign="bottom", wSteps={0.75, 0.667, 0.5, 0.333, 0.25}, hFixed=0.5},
  ["2"] = {xAlign="center", yAlign="bottom", wSteps={1, 0.75, 0.667, 0.5, 0.333, 0.25}, hFixed=0.5},
  ["3"] = {xAlign="right",  yAlign="bottom", wSteps={0.75, 0.667, 0.5, 0.333, 0.25}, hFixed=0.5},
  ["4"] = {xAlign="left", yAlign="center", wSteps={0.75, 0.667, 0.5, 0.333, 0.25}, hFixed=1},
  ["5"] = {xAlign="center", yAlign="center", wFixed=1/3,  hFixed=1},
  ["6"] = {xAlign="right",  yAlign="center", wSteps={0.75, 0.667, 0.5, 0.333, 0.25}, hFixed=1},
  ["7"] = {xAlign="left", yAlign="top",  wSteps={0.75, 0.667, 0.5, 0.333, 0.25}, hFixed=0.5},
  ["8"] = {xAlign="center", yAlign="top",  wSteps={1, 0.75, 0.667, 0.5, 0.333, 0.25}, hFixed=0.5},
  ["9"] = {xAlign="right",  yAlign="top",  wSteps={0.75, 0.667, 0.5, 0.333, 0.25}, hFixed=0.5},
}

local function moveOrResize(dir)
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)

  st.mode = 'preset'
  st.targetSize = nil

  local info = dirMap[dir]
  local numSteps = info.wSteps and #info.wSteps or 1

  if st.lastDir == dir and numSteps > 1 then
    st.step = ((st.step % numSteps) or 0) + 1
  else
    st.step = 1
  end
  st.lastDir = dir

  local wf = info.wFixed or info.wSteps[st.step]
  local hf = info.hFixed or 1

  local x = (info.xAlign == "left") and 0 or (info.xAlign == "center" and (1 - wf) / 2 or 1 - wf)
  local y = (info.yAlign == "top") and 0 or (info.yAlign == "center" and (1 - hf) / 2 or 1 - hf)

  local unit = {x = x, y = y, w = wf, h = hf}
  st.targetUnit = unit

  applyAndClamp(w, unit)
end

for i=1, 9 do
  hotkey.bind(MODS, "PAD"..i, function() moveOrResize(tostring(i)) end)
end

hotkey.bind(MODS, PAD_ENTER, function()
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)

  st.mode = 'preset'
  st.targetSize = nil

  if st.maximized then
    applyAndClamp(w, st.lastUnit)
    st.maximized = false
    st.targetUnit = st.lastUnit
  else
    local unit = {x = 0, y = 0, w = 1, h = 1}
    applyAndClamp(w, unit)
    st.maximized = true
    st.targetUnit = unit
  end
end)

hotkey.bind(MODS, PAD_DOT, function()
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  st.mode = 'preset'
  st.targetSize = nil
  applyAndClamp(w, st.orig)
  st.targetUnit = st.orig
  st.step = 1
  st.lastDir = nil
end)

hotkey.bind(MODS, PAD0, function()
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  local lu = st.lastUnit
  local unit = { x = (1 - lu.w) / 2, y = (1 - lu.h) / 2, w = lu.w, h = lu.h }
  applyAndClamp(w, unit)
  st.mode = 'preset'
  st.targetSize = nil
  st.targetUnit = unit
  st.step = 1
  st.lastDir = "5"
end)

hotkey.bind(MODS, PAD_PLUS, function()
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  local sf = w:screen():frame()

  local targetW, targetH = 380, 380

  st.mode = 'manual'
  st.targetSize = {w = targetW, h = targetH}
  st.targetUnit = nil

  local unit = {
    x = (sf.w - targetW) / sf.w,
    y = (sf.h - targetH) / sf.h,
    w = targetW / sf.w,
    h = targetH / sf.h
  }
  applyAndClamp(w, unit)
  st.step = 1
  st.lastDir = nil
end)

local function moveWindowDisplay(dir)
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)

  local all = screen.allScreens()
  local i = fnutils.indexOf(all, w:screen())
  local tgtScreen = dir == -1 and all[((i - 2) % #all) + 1] or all[(i % #all) + 1]

  w:moveToScreen(tgtScreen)

  local newSf = tgtScreen:frame()
  local unitToApply

  if st.mode == 'manual' and st.targetSize then
    local fixedW = st.targetSize.w
    local fixedH = st.targetSize.h

    unitToApply = {
      x = st.lastUnit.x,
      y = st.lastUnit.y,
      w = fixedW / newSf.w,
      h = fixedH / newSf.h
    }
  else
    st.targetSize = nil
    unitToApply = st.targetUnit or st.lastUnit
  end

  applyAndClamp(w, unitToApply)
end

hotkey.bind(MODS, PAD_DIV, function() moveWindowDisplay(-1) end)
hotkey.bind(MODS, PAD_MUL, function() moveWindowDisplay(1) end)

wfilter.new():subscribe(
  {wfilter.windowMoved, wfilter.windowResized},
  function(win)
    local winId = win:id()
    if isProgrammaticWindows[winId] > 0 then
      return
    end

    local id = win:id()
    local st = ensureWindowState(win)

    st.mode = 'manual'

    local f = win:frame()
    st.targetSize = {w = f.w, h = f.h}
    st.targetUnit = nil

    local sf = win:screen():frame()
    st.lastUnit = toUnitRect(f, sf)

    logWindowState(win, "Manual Move/Resize")
  end
)