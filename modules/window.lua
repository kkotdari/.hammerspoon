local hotkey = hs.hotkey
local window = hs.window
local screen = hs.screen
local fnutils = hs.fnutils
local wfilter = hs.window.filter

hs.window.animationDuration = 0

local PAD_PLUS, PAD_MINUS = 69, 78
local PAD_DIV, PAD_MUL = 75, 67
local PAD1, PAD2, PAD3 = 83, 84, 85
local PAD4, PAD5, PAD6 = 86, 87, 88
local PAD7, PAD8, PAD9 = 89, 91, 92
local PAD_DOT = 65
local PAD_ENTER = 76
local PAD0 = 82

local MODS = { "cmd", "ctrl" }
local SHIFT_MODS = { "cmd", "ctrl", "shift" }
local windowStates = {}
local ignoreWatcher = false
local DoingFunctionCnt = 0
local resizeView = nil

local function toUnitRect(f, sf)
  return {
    x = (f.x - sf.x) / sf.w,
    y = (f.y - sf.y) / sf.h,
    w = f.w / sf.w,
    h = f.h / sf.h,
  }
end

local function clampFrame(f, uf)
  f.x = math.max(uf.x, math.min(f.x, uf.x + uf.w - f.w))
  f.y = math.max(uf.y, math.min(f.y, uf.y + uf.h - f.h))
  return f
end

local function applyAndClamp(win, unit)
  DoingFunctionCnt = DoingFunctionCnt + 1
  ignoreWatcher = true
  win:moveToUnit(unit, 0)
  local f2 = win:frame()
  local uf = win:screen():frame()
  win:setFrame(clampFrame(f2, uf), 0)
  hs.timer.doAfter(1, function() 
      if DoingFunctionCnt == 1 then ignoreWatcher = false end
    end)
  DoingFunctionCnt = DoingFunctionCnt - 1   
end

local function activeWindow()
  return window.focusedWindow() or window.frontmostWindow()
end

local resizeStates = {
  { 1, 1 }, { 1.5, 1 }, { 2, 1 }, { 3, 1 }, { 4, 1 },
  { 1, 1.5 }, { 1.5, 1.5 }, { 2, 1.5 }, { 3, 1.5 }, { 4, 1.5 },
  { 1, 2 }, { 1.5, 2 }, { 2, 2 }, { 3, 2 }, { 4, 2 },
  { 1, 3 }, { 1.5, 3 }, { 2, 3 }, { 3, 3 }, { 4, 3 },
  { 8, 4 }
}

local ratioChars = {
  "1×1", "⅔×1", "½×1", "⅓×1", "¼×1",
  "1×⅔", "⅔×⅔", "½×⅔", "⅓×⅔", "¼×⅔",
  "1×½", "⅔×½", "½×½", "⅓×½", "¼×½",
  "1×⅓", "⅔×⅓", "½×⅓", "⅓×⅓", "¼×⅓",
  "⅛×¼"
}

local EPS = 1e-6

local function getResizeIndex(win)
  local f = win:frame()
  local sf = win:screen():frame()
  local u = toUnitRect(f, sf)

  local bestA, bestADiff = resizeStates[1][1], math.huge
  for _, ab in ipairs(resizeStates) do
    local targetW = 1 / ab[1]
    local diff = math.abs(u.w - targetW)
    if diff < bestADiff then bestADiff, bestA = diff, ab[1] end
  end

  local bestB, bestBDiff = resizeStates[1][2], math.huge
  for _, ab in ipairs(resizeStates) do
    local targetH = 1 / ab[2]
    local diff = math.abs(u.h - targetH)
    if diff < bestBDiff then bestBDiff, bestB = diff, ab[2] end
  end

  local matchedIdx = 1
  for i, ab in ipairs(resizeStates) do
    if ab[1] == bestA and ab[2] == bestB then matchedIdx = i break end
  end

  return matchedIdx
end

local function getLastDir(win)
  local f = win:frame()
  local sf = win:screen():frame()
  
  print("getLastDir > win > x/y/w/h: " .. f.x .. "/" .. f.y .. "/" .. f.w .. "/" .. f.h)
  print("getLastDir > screen > x/y/w/h: " .. sf.x .. "/" .. sf.y .. "/" .. sf.w .. "/" .. sf.h)

  local t = math.abs(f.y - sf.y) < EPS
  local b = math.abs(f.y + f.h - (sf.y + sf.h)) <= 1
  local l = math.abs(f.x - sf.x) < EPS
  local r = math.abs(f.x + f.w - (sf.x + sf.w)) < EPS
  
  local lastDir
  if t and not b and l and not r then lastDir = "7"
  elseif t and not b and not l and r then lastDir = "9"
  elseif not t and b and l and not r then lastDir = "1"
  elseif not t and b and not l and r then lastDir = "3"
  elseif t and not b and not l and not r then lastDir = "8"
  elseif not t and b and not l and not r then lastDir = "2"
  elseif not t and not b and l and not r then lastDir = "4"
  elseif not t and not b and not l and r then lastDir = "6"
  else lastDir = "5" end
  
  print("getLastDir > t/b/l/r: " .. tostring(t) .. "/" .. tostring(b) .. "/" .. tostring(l) .. "/" .. tostring(r))
  print("getLastDir > lastDir: " .. lastDir)
  return lastDir
end

local function getColIndex(win)
  local EPS = 1e-6
  local f  = win:frame()
  local sf = win:screen():frame()
  local u  = toUnitRect(f, sf)
  local cx = u.x + u.w/2

  if math.abs(cx - 0.5) < EPS then
    return 1
  elseif cx < 0.5 then
    return 2
  else
    return 3
  end
end

local function ensureWindowState(win)
  local id = win:id()
  
  local ensuredWindowState
  if not windowStates[id]
  then
    windowStates[id] = {
      originalUnit = nil,
      lastUnit = nil,
      resizeIndex = nil,
      lastDir = nil,
      colIndex = nil,
    }
  end
  
  local f = win:frame()
  print("ensureWindowState > win >  x/y/w/h: " .. f.x .. "/" .. f.y .. "/" .. f.w .. "/" .. f.h)
  local sf = win:screen():frame()
  local u = toUnitRect(f, sf)

  if not windowStates[id].originalUnit then windowStates[id].originalUnit = u end
  if not windowStates[id].lastUnit then windowStates[id].lastUnit = u end
  if not windowStates[id].resizeIndex then windowStates[id].resizeIndex = getResizeIndex(win) end
  if not windowStates[id].lastDir then windowStates[id].lastDir = getLastDir(win) end
  
  if (windowStates[id].lastDir == "2"
      or windowStates[id].lastDir == "5"
      or windowStates[id].lastDir == "8") 
    and not windowStates[id].colIndex then
    windowStates[id].colIndex = getColIndex(win)
    print("window > colIndex: " .. windowStates[id].colIndex)
  end

  return windowStates[id]
end

local function bindHotkey(mods, key, fn)
  local hk = hotkey.new(mods, key, fn)
  table.insert(store.allWindowHotkeys, hk)
  hk:enable()
  return hk
end

local function getPositionByDir(dir, wf, hf)
  if dir == "1" then return 0, 1 - hf end
  if dir == "3" then return 1 - wf, 1 - hf end
  if dir == "4" then return 0, (1 - hf) / 2 end
  if dir == "6" then return 1 - wf, (1 - hf) / 2 end
  if dir == "7" then return 0, 0 end
  if dir == "8" then return (1 - wf) / 2, 0 end
  if dir == "9" then return 1 - wf, 0 end
  return (1 - wf) / 2, (1 - hf) / 2
end

local dirArrows = {
  ["1"] = "↙", ["2"] = "↓", ["3"] = "↘",
  ["4"] = "←", ["6"] = "→", ["7"] = "↖",
  ["8"] = "↑", ["9"] = "↗"
}

local function moveWindow(dir)
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  if not st.lastDir == dir then st.colIndex = nil end

  st.lastDir = dir
  
  if st.lastDir == "2" or st.lastDir == "5" or st.lastDir == "8" then
    st.colIndex = st.colIndex == nil and 1 or ((st.colIndex % 3) + 1)

    print("window > lastDir: " .. st.lastDir .. ", colIndex: " .. st.colIndex)
    
    local wf, hf = st.lastUnit.w, st.lastUnit.h
    
    local rawX
    if st.colIndex == 1 then
      rawX = 0.5 - wf/2
    elseif st.colIndex == 2 then
      rawX = 0.5 - wf
    else
      rawX = 0.5
    end
    
    local rawY
    if dir == "2" then
      rawY = 1 - hf
    elseif dir == "8" then
      rawY = 0
    else
      rawY = (1 - hf) / 2
    end
    
    local x = math.max(0, math.min(rawX, 1 - wf))
    local y = math.max(0, math.min(rawY, 1 - hf))
    
    local unit = { x = x, y = y, w = wf, h = hf }
    applyAndClamp(w, unit)
    toast.showToast(({ ["2"] = "↓", ["5"] = "Centre", ["8"] = "↑" })[dir])
    st.lastUnit = unit
    return
  end

  local u = st.lastUnit
  local wf, hf = u.w, u.h
  local x, y = getPositionByDir(dir, wf, hf)
  local unit = { x = x, y = y, w = wf, h = hf }
  applyAndClamp(w, unit)
  toast.showToast(dirArrows[dir])
  st.lastUnit = unit
end

bindHotkey(MODS, PAD1, function() moveWindow("1") end)
bindHotkey(MODS, PAD2, function() moveWindow("2") end)
bindHotkey(MODS, PAD3, function() moveWindow("3") end)
bindHotkey(MODS, PAD4, function() moveWindow("4") end)
bindHotkey(MODS, PAD5, function() moveWindow("5") end)
bindHotkey(MODS, PAD6, function() moveWindow("6") end)
bindHotkey(MODS, PAD7, function() moveWindow("7") end)
bindHotkey(MODS, PAD8, function() moveWindow("8") end)
bindHotkey(MODS, PAD9, function() moveWindow("9") end)

local function resizeWindow(isShrink)
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  local baseIdx = st.resizeIndex or 1
  local newIdx = isShrink and (baseIdx + 1) or (baseIdx - 1)
  if newIdx < 1 or newIdx > #resizeStates
  then toast.showToast(isShrink and "최소 크기" or "최대 크기") return
  end
  local ab = resizeStates[newIdx]
  local wf, hf = 1 / ab[1], 1 / ab[2]
  local x, y = getPositionByDir(st.lastDir, wf, hf)
  local unit = { x = x, y = y, w = wf, h = hf }
  applyAndClamp(w, unit)
  toast.showToast(ratioChars[newIdx])
  st.lastUnit, st.resizeIndex = unit, newIdx
end

bindHotkey(MODS, PAD_MINUS, function() resizeWindow(true) end)
bindHotkey(MODS, PAD_PLUS, function() resizeWindow(false) end)

local function resizeWindowToEnd(isShrink)
  local w = activeWindow()
  if not w then return end

  local st = ensureWindowState(w)
  if st.resizeIndex == #resizeStates and isShrink then
    toast.showToast("최소 크기")
    return
  elseif st.resizeIndex == 1 and not isShrink then
    toast.showToast("최대 크기")
    return
  end

  local newIdx   = isShrink and #resizeStates or 1

  local ab       = resizeStates[newIdx]
  local wf, hf   = 1 / ab[1], 1 / ab[2]
  local x, y     = getPositionByDir(st.lastDir, wf, hf)
  local unit     = { x = x, y = y, w = wf, h = hf }

  applyAndClamp(w, unit)
  toast.showToast(ratioChars[newIdx])

  st.lastUnit, st.resizeIndex = unit, newIdx
end

bindHotkey(SHIFT_MODS, PAD_MINUS, function() resizeWindowToEnd(true) end)
bindHotkey(SHIFT_MODS, PAD_PLUS, function() resizeWindowToEnd(false) end)

bindHotkey(MODS, PAD_DOT, function()
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  applyAndClamp(w, st.originalUnit)
  toast.showToast("처음으로")
  st.lastUnit, st.resizeIndex, st.lastDir = st.originalUnit, 1, "5"
end)

bindHotkey(MODS, PAD_ENTER, function()
  local w = activeWindow()
  if not w then return end
  local unit = { x = 0, y = 0, w = 1, h = 1 }
  applyAndClamp(w, unit)
  toast.showToast("가장 크게")
  local st = ensureWindowState(w)
  st.lastUnit, st.resizeIndex, st.lastDir = unit, 1, "5"
end)

bindHotkey(MODS, PAD_DIV, function()
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  local unit = toUnitRect(w:frame(), w:screen():frame())
  local all = screen.allScreens()
  local i = fnutils.indexOf(all, w:screen())
  local tgt = all[((i - 2) % #all) + 1]
  w:moveToScreen(tgt)
  applyAndClamp(w, unit)
  toast.showToast("←")
  st.lastUnit = unit
end)

bindHotkey(MODS, PAD_MUL, function()
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  local unit = toUnitRect(w:frame(), w:screen():frame())
  local all = screen.allScreens()
  local i = fnutils.indexOf(all, w:screen())
  local tgt = all[(i % #all) + 1]
  w:moveToScreen(tgt)
  applyAndClamp(w, unit)
  toast.showToast("→")
  st.lastUnit = unit
end)

hs.urlevent.bind("resize", function(_, params)
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  local sf = w:screen():frame()
  local w_px = tonumber(params.width)
  local h_px = tonumber(params.height)
  if w_px and h_px then
    local wf, hf = w_px / sf.w, h_px / sf.h
    local x, y   = getPositionByDir(st.lastDir, wf, hf)
    applyAndClamp(w, { x = x, y = y, w = wf, h = hf })
    st.lastUnit   = { x = x, y = y, w = wf, h = hf }
    st.resizeIndex = nil
  end
  resizeView:delete()
  resizeView = nil
end)

hs.urlevent.bind("close", function()
  if resizeView then
    resizeView:delete()
    resizeView = nil
  end
end)

bindHotkey(MODS, PAD0, function()
  local w = activeWindow()
  if not w then return end
  local st = ensureWindowState(w)
  local f  = w:frame()
  local sf = w:screen():frame()

local html = [[
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<style>
  html,body {
    padding:0;
    margin:0;
  }
  body {
    width:100%;
    height:100%;
    box-sizing:border-box;
    background-color:rgba(255,255,255,1);
    font-family:-apple-system,sans-serif;
    font-size:14px;
    color:#333;
    border:1px solid #ccc;
    border-radius:8px;
    padding: 12px 24px 12px 24px;
    display:flex;
    flex-direction:column;
    justify-content:space-between;
    align-items:center;
    overflow:hidden;
  }
  .input-row {  
    flex:initial;
    width:100%;
    display:flex;
    justify-content:space-between;
    align-items:center;
  }
  .input-row label {
    width:25%;
    color:#333;
    font-size:14px;
    font-weight:500;
  }
  .input-row input {
    width:75%;
    padding:4px;
    font-size:12px;
    text-align:right;
    border:1px solid #cccccc;
    border-radius:4px;
    box-sizing:border-box;
  }
  .button-row {  
    flex:initial;
    width:100%;
    display:flex;
    gap:8px;
    margin-top:4px;
    margin-bottom:4px;
    align-items:center;
  }
  .button-row button {
    flex-grow:1;
    height:auto;
    padding:4px 0px 4px 0px;
    border:none;
    border-radius:4px;
    background:#007aff;
    color:#ffffff;
    font-size:14px;
    font-weight:600;
    cursor:hand;
  }
  button:active { background:#0051a8 }
</style>
</head>
<body>
  <div class="input-row"><label>가로</label><input id="w" type="number" value="]]..f.w..[[" /></div>
  <div class="input-row"><label>세로</label><input id="h" type="number" value="]]..f.h..[[" /></div>
  <div class="button-row">
    <button id="btn-submit">확인</button>
    <button id="btn-cancel">취소</button>
  </div>
  <script>
    function apply(){
      var wi = document.getElementById('w').value;
      var hi = document.getElementById('h').value;
      window.location = 'hammerspoon://resize?width=' + wi + '&height=' + hi;
    }
    document.getElementById('btn-submit').addEventListener('click', apply);
    document.getElementById('btn-cancel').addEventListener('click', function(){
      window.location = 'hammerspoon://close';
    });
    document.addEventListener('keydown', function(e){
      if (e.key === 'Enter') apply();
      else if (e.key === 'Escape') window.location = 'hammerspoon://close';
    });
  </script>
</body>
</html>
]]

  if resizeView then
    resizeView:delete()
    resizeView = nil
  end

  resizeView = hs.webview.new({
      x = sf.x + sf.w/2 - 90,
      y = sf.y + sf.h/2 - 60,
      w = 180,
      h = 120
    })
    :windowStyle("utility")
    :allowTextEntry(true)
    :transparent(true)
    :html(html)

  resizeView:show()
  resizeView:bringToFront()
end)

wfilter.new():subscribe(
  { wfilter.windowMoved, wfilter.windowResized },
  function(win)
    if ignoreWatcher then return end
    local id = win:id()
    local st = windowStates[id]
    if not st then return end
    st.lastDir = "5"
    local f, sf = win:frame(), win:screen():frame()
    st.originalUnit = toUnitRect(f, sf)
    st.lastUnit = toUnitRect(f, sf)
  end
)