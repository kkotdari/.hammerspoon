--------------------------------------------------------------------
-- imports
--------------------------------------------------------------------
local hotkey   = hs.hotkey
hotkey.setLogLevel('warning')
local timer    = hs.timer
local eventtap = hs.eventtap
local mouse    = hs.mouse
local screen   = hs.screen
local alert    = hs.alert
local event    = eventtap.event

--------------------------------------------------------------------
-- tunables
--------------------------------------------------------------------
local MOVE_STEP       = 0.5
local MAX_MOVE_STEP   = 20
local MOVE_ACCEL      = 1.08

local SCROLL_STEP     = 20
local MAX_SCROLL_STEP = 50
local SCROLL_ACCEL    = 1.15

local CLICK_DELAY     = 0.05
local TICK            = 0.01

local TELEPORT_COORD  = { x = 2000, y = 500 }

--------------------------------------------------------------------
-- module-local state
--------------------------------------------------------------------
local moveTimers   = {}
local scrollTimers = {}

--------------------------------------------------------------------
-- Direction helpers 
--------------------------------------------------------------------
local pressedDirs = {}  -- map from keycode -> {dx, dy}

local function currentDir()
  local dx, dy = 0, 0
  for _, v in pairs(pressedDirs) do
    dx = dx + v.dx
    dy = dy + v.dy
  end
  return dx, dy
end

local function pressDir(code, dx, dy)
  pressedDirs[code] = { dx = dx, dy = dy }
end

local function releaseDir(code)
  pressedDirs[code] = nil
  return next(pressedDirs) == nil
end

--------------------------------------------------------------------
-- clamp a point to primary screen
--------------------------------------------------------------------
local function clamp(pt)
  local f = screen.primaryScreen():fullFrame()
  pt.x = math.max(f.x, math.min(f.x + f.w - 1, pt.x))
  pt.y = math.max(f.y, math.min(f.y + f.h - 1, pt.y))
  return pt
end

--------------------------------------------------------------------
-- movement helpers
--------------------------------------------------------------------
local step = MOVE_STEP
local moveTimer = timer.doEvery(TICK, function()
  local p = mouse.absolutePosition()
  local cdx, cdy = currentDir()
  if cdx ~= 0 and cdy ~= 0 then
    local norm = 1/math.sqrt(2)
    cdx, cdy = cdx*norm, cdy*norm
  end
  local tgt = clamp{ x = p.x + cdx*step, y = p.y + cdy*step }
  mouse.absolutePosition(tgt)
  event.newMouseEvent(event.types.mouseMoved, tgt):post()
  step = math.min(step * MOVE_ACCEL, MAX_MOVE_STEP)
end):stop()

local function onMovePress(code, dx, dy)
  pressDir(code, dx, dy)
  moveTimer:start()
end

local function onMoveRelease(code)
  if releaseDir(code) then
    moveTimer:stop()
    step = MOVE_STEP
  end
end

local function moveFunction(code, dx, dy)
  return function() onMovePress(code, dx, dy) end,
         function() onMoveRelease(code)       end
end

--------------------------------------------------------------------
-- drag helpers
--------------------------------------------------------------------
local dragActive = false
local dragStep   = MOVE_STEP
local dragTimer  = timer.doEvery(TICK, function()
  local p = mouse.absolutePosition()
  local cdx, cdy = currentDir()
  if cdx ~= 0 and cdy ~= 0 then
    local norm = 1/math.sqrt(2)
    cdx, cdy = cdx*norm, cdy*norm
  end
  local tgt = clamp{ x = p.x + cdx*dragStep, y = p.y + cdy*dragStep }
  mouse.absolutePosition(tgt)
  event.newMouseEvent(event.types.leftMouseDragged, tgt):post()
  dragStep = math.min(dragStep * MOVE_ACCEL, MAX_MOVE_STEP)
end):stop()

local function onDragPress(code, dx, dy)
  pressDir(code, dx, dy)
  if not dragActive then
    dragActive = true
    local pos = mouse.absolutePosition()
    event.newMouseEvent(event.types.leftMouseDown, pos):post()
  end
  dragTimer:start()
end

local function onDragRelease(code)
  if releaseDir(code) then
    dragTimer:stop()
    dragStep = MOVE_STEP
  end
end

local function dragFunction(code, dx, dy)
  return function() onDragPress(code, dx, dy) end,
         function() onDragRelease(code)       end
end

--------------------------------------------------------------------
-- modifier watcher to end drag on ⌘ or ⌃ release
--------------------------------------------------------------------
_G.dragModifierChangeWatcher = eventtap.new(
  { eventtap.event.types.flagsChanged },
  function(e)
    if not dragActive then return false end
    local f = e:getFlags()
    local other = f.shift or f.ctrl or f.fn
    if not (f.cmd and f.alt) or other then
      dragTimer:stop()
      local pos = mouse.absolutePosition()
      event.newMouseEvent(event.types.leftMouseUp, pos):post()
      dragActive  = false
      pressedDirs = {}
      dragStep    = MOVE_STEP
    end
    return false
  end
)
_G.dragModifierChangeWatcher:start()

--------------------------------------------------------------------
-- scroll helpers
--------------------------------------------------------------------
local function doScroll(dx, dy, step)
  event.newScrollEvent({ dx*step, dy*step }, {}, "pixel"):post()
end

local function onScrollPress(code, dx, dy)
  if scrollTimers[code] then return end
  local s = SCROLL_STEP
  scrollTimers[code] = timer.doEvery(TICK, function()
    doScroll(dx, dy, s)
    s = math.min(s * SCROLL_ACCEL, MAX_SCROLL_STEP)
  end)
end

local function onScrollRelease(code)
  if scrollTimers[code] then
    scrollTimers[code]:stop()
    scrollTimers[code] = nil
  end
end

local function scrollFunction(code, dx, dy)
  return function() onScrollPress(code, dx, dy) end,
         function() onScrollRelease(code)       end
end

--------------------------------------------------------------------
-- pointing-mode hotkeys storage
--------------------------------------------------------------------
store.allPointingHotkeys = store.allPointingHotkeys or {}

local function bindPointingKey(mods, key, fnDown, fnUp)
  local wrappedDown = function()
    if not store.pointingsOn then return end
    fnDown()
  end
  local wrappedUp = fnUp and function()
    if not store.pointingsOn then return end
    fnUp()
  end or nil

  local hk = hotkey.new(mods, key, wrappedDown, wrappedUp, wrappedDown)
  hk:disable()
  table.insert(store.allPointingHotkeys, hk)
  return hk
end

--------------------------------------------------------------------
-- click keys
--------------------------------------------------------------------
bindPointingKey({}, 89,
  function()
    local pos = mouse.absolutePosition()
    event.newMouseEvent(event.types.leftMouseDown, pos):post()
    timer.doAfter(CLICK_DELAY, function()
      event.newMouseEvent(event.types.leftMouseUp, pos):post()
    end)
  end
)

bindPointingKey({}, 92,
  function()
    local pos = mouse.absolutePosition()
    event.newMouseEvent(event.types.rightMouseDown, pos):post()
    timer.doAfter(CLICK_DELAY, function()
      event.newMouseEvent(event.types.rightMouseUp, pos):post()
    end)
  end
)

--------------------------------------------------------------------
-- arrow keys → move cursor
--------------------------------------------------------------------
bindPointingKey({}, 91, moveFunction(91,  0, -1))
bindPointingKey({}, 87, moveFunction(87,  0,  1))
bindPointingKey({}, 86, moveFunction(86, -1,  0))
bindPointingKey({}, 88, moveFunction(88,  1,  0))

--------------------------------------------------------------------
-- cmd+shift + arrows → drag
--------------------------------------------------------------------
bindPointingKey({"cmd", "shift"}, 91, dragFunction(91,  0, -1))
bindPointingKey({"cmd", "shift"}, 87, dragFunction(87,  0,  1))
bindPointingKey({"cmd", "shift"}, 86, dragFunction(86, -1,  0))
bindPointingKey({"cmd", "shift"}, 88, dragFunction(88,  1,  0))

--------------------------------------------------------------------
-- cmd+ctrl + arrows → scroll
--------------------------------------------------------------------
bindPointingKey({"cmd", "ctrl"}, 91, scrollFunction(91,  0,  1))
bindPointingKey({"cmd", "ctrl"}, 87, scrollFunction(87,  0, -1))
bindPointingKey({"cmd", "ctrl"}, 86, scrollFunction(86, -1,  0))
bindPointingKey({"cmd", "ctrl"}, 88, scrollFunction(88,  1,  0))

--------------------------------------------------------------------
-- numpad 0 → teleport
--------------------------------------------------------------------
bindPointingKey({}, 82,
  function()
    local dest = clamp{ x = TELEPORT_COORD.x, y = TELEPORT_COORD.y }
    mouse.absolutePosition(dest)
    event.newMouseEvent(event.types.mouseMoved, dest):post()
  end
)

--------------------------------------------------------------------
-- toggle pointing-mode (NumLock)
--------------------------------------------------------------------
local menu         = hs.menubar.new()
local isPointerMode = false

local function updateTitle()
  menu:setTitle(isPointerMode and "Key-Mouse: ON" or "Key-Mouse: OFF")
end

function enterPointingMode()
  store.pointingsOn = true
  toast.showToast("Numpad: Key-Mouse ON", 2.0)
  store.toggleHotkeys(store.allWindowHotkeys, false)
  store.toggleHotkeys(store.allPointingHotkeys, true)
  isPointerMode = true
  updateTitle()
end

function exitPointingMode()
  store.pointingsOn = false
  toast.showToast("Numpad: Key-Mouse OFF", 2.0)
  store.toggleHotkeys(store.allPointingHotkeys, false)
  store.toggleHotkeys(store.allWindowHotkeys, true)
  moveTimer:stop()
  dragTimer:stop()
  for _, t in pairs(scrollTimers) do t:stop() end
  pressedDirs  = {}
  dragActive   = false
  step         = MOVE_STEP
  dragStep     = MOVE_STEP
  isPointerMode = false
  updateTitle()
end

local function togglePointingMode()
  if store.pointingsOn then
    exitPointingMode()
  else
    enterPointingMode()
  end
end

hotkey.new({}, 71, togglePointingMode):enable()
menu:setClickCallback(togglePointingMode)
updateTitle()