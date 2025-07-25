local hotkey = hs.hotkey
local spaces  = hs.spaces
local screen  = hs.screen
local window  = hs.window
local fnutils = hs.fnutils
local wfilter = hs.window.filter
local timer = hs.timer
hs.window.animationDuration = 0

local PAD1, PAD2, PAD3 = 83, 84, 85
local PAD4, PAD5, PAD6 = 86, 87, 88
local PAD7, PAD8, PAD9 = 89, 91, 92
local PAD_ENTER = 76
local PAD_DOT = 65
local PAD0  = 82
local PAD_DIV = 75
local PAD_MUL = 67
local PAD_INSERT  = 114

local MODS = {"cmd", "ctrl"}
local windowStates = {}
local watingWatchingCnt = 0

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

local function applyAndClamp(win, unit)
  watingWatchingCnt = watingWatchingCnt + 1
  win:moveToUnit(unit, 0)
  local f2 = win:frame()
  local uf = win:screen():frame()
  win:setFrame(clampFrame(f2, uf), 0)
end

local function activeWindow()
  return window.focusedWindow() or window.frontmostWindow()
end

local function ensureWindowState(win)
  local id = win:id()
  if not windowStates[id] then
  windowStates[id] = {orig = nil, lastUnit = nil, lastDir = nil, step = nil}
  end
  local st = windowStates[id]
  if not st.orig then
  local f, sf = win:frame(), win:screen():frame()
  st.orig = toUnitRect(f, sf)
  st.lastUnit = st.orig
  st.step = 1
  end
  return st
end

local dirMap = {
  ["1"] = {xAlign="left", yAlign="bottom", wSteps={0.5,0.333,0.667}, hFixed=0.5},
  ["2"] = {xAlign="center", yAlign="bottom", wSteps={1,0.5,0.333}, hFixed=0.5},
  ["3"] = {xAlign="right",  yAlign="bottom", wSteps={0.5,0.333,0.667}, hFixed=0.5},
  ["4"] = {xAlign="left", yAlign="center", wSteps={0.5,0.333,0.667}, hFixed=1},
  ["5"] = {xAlign="center", yAlign="center", wFixed=1/3,  hFixed=1},
  ["6"] = {xAlign="right",  yAlign="center", wSteps={0.5,0.333,0.667}, hFixed=1},
  ["7"] = {xAlign="left", yAlign="top",  wSteps={0.5,0.333,0.667}, hFixed=0.5},
  ["8"] = {xAlign="center", yAlign="top",  wSteps={1,0.5,0.333}, hFixed=0.5},
  ["9"] = {xAlign="right",  yAlign="top",  wSteps={0.5,0.333,0.667}, hFixed=0.5},
}

local function moveOrResize(dir)
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)

  if st.lastDir == dir then
  st.step = st.step + 1
  else
  st.step = 1
  end
  st.lastDir = dir

  local info = dirMap[dir]
  local wf
  if info.wFixed then
  wf = info.wFixed
  else
  wf = info.wSteps[((st.step - 1) % #info.wSteps) + 1]
  end
  local hf = info.hFixed or 1

  local x
  if info.xAlign == "left" then
  x = 0
  elseif info.xAlign == "center" then
  x = (1 - wf) / 2
  else
  x = 1 - wf
  end

  local y
  if info.yAlign == "top" then
  y = 0
  elseif info.yAlign == "center" then
  y = (1 - hf) / 2
  else
  y = 1 - hf
  end

  applyAndClamp(w, {x = x, y = y, w = wf, h = hf})
  st.lastUnit = {x = x, y = y, w = wf, h = hf}
end

hotkey.bind(MODS, PAD1, function() moveOrResize("1") end)
hotkey.bind(MODS, PAD2, function() moveOrResize("2") end)
hotkey.bind(MODS, PAD3, function() moveOrResize("3") end)
hotkey.bind(MODS, PAD4, function() moveOrResize("4") end)
hotkey.bind(MODS, PAD5, function() moveOrResize("5") end)
hotkey.bind(MODS, PAD6, function() moveOrResize("6") end)
hotkey.bind(MODS, PAD7, function() moveOrResize("7") end)
hotkey.bind(MODS, PAD8, function() moveOrResize("8") end)
hotkey.bind(MODS, PAD9, function() moveOrResize("9") end)

hotkey.bind(MODS, PAD_ENTER, function()
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  if st.maximized then
  applyAndClamp(w, st.lastUnit)
  st.maximized = false
  else
  local unit = {x = 0, y = 0, w = 1, h = 1}
  applyAndClamp(w, unit)
  st.maximized = true
  end
end)

hotkey.bind(MODS, PAD_DOT, function()
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  applyAndClamp(w, st.orig)
  st.lastUnit, st.step, st.lastDir = st.orig, 1, nil
end)

hotkey.bind(MODS, PAD0, function()
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  local lu = st.lastUnit
  local unit = {
    x = (1 - lu.w) / 2,
    y = (1 - lu.h) / 2,
    w = lu.w,
    h = lu.h
  }
  applyAndClamp(w, unit)
  st.lastUnit, st.step, st.lastDir = unit, 1, "5"
end)

local function moveWindowDisplay(dir)
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  local unit = st.lastUnit
  local all = screen.allScreens()
  local i = fnutils.indexOf(all, w:screen())
  local tgt = dir == -1 and all[((i - 2) % #all) + 1] or all[(i % #all) + 1]
  w:moveToScreen(tgt)
  applyAndClamp(w, unit)
end

hotkey.bind(MODS, PAD_DIV, function() moveWindowDisplay(-1) end)
hotkey.bind(MODS, PAD_MUL, function() moveWindowDisplay(1) end)

wfilter.new():subscribe(
  {wfilter.windowMoved, wfilter.windowResized},
  function(win)
    if not watingWatchingCnt == 0 then
      watingWatchingCnt = watingWatchingCnt - 1
      return
    end
    local id = win:id()
    local st = ensureWindowState(win)
  end
)