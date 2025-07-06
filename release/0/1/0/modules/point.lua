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

-------------------------------------------------------------------
-- tunables
---------------------------------------------------------------------
local MOVE_STEP       = 0.5
local MAX_MOVE_STEP   = 20
local MOVE_ACCEL      = 1.08

local SCROLL_STEP     = 20
local MAX_SCROLL_STEP = 50
local SCROLL_ACCEL    = 1.15

local CLICK_DELAY     = 0.05
local TICK            = 0.01

local TELEPORT_COORD = { x = 2000, y = 500 }

--------------------------------------------------------------------
-- module-local state
--------------------------------------------------------------------
local moveTimers   = {}
local scrollTimers = {}

--------------------------------------------------------------------
-- Direction helpers 
--------------------------------------------------------------------
local pressedDirs  = {}  -- map from keycode -> {dx, dy}

local function currentDir()
  local dx, dy = 0, 0
  for _, v in pairs(pressedDirs) do
    dx = dx + v.dx
    dy = dy + v.dy
  end
  return dx, dy
end

-- update our current direction set and last direction
local function pressDir(code, dx, dy)
    pressedDirs[code] = { dx = dx, dy = dy }
end

-- remove a direction and tell us if any remain
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
        cdx, cdy   = cdx*norm, cdy*norm
    end
    local tgt = clamp{ x = p.x + cdx*step, y = p.y + cdy*step }
    mouse.absolutePosition(tgt)
    event.newMouseEvent(event.types.mouseMoved, tgt):post()
    step = math.min(step * MOVE_ACCEL, MAX_MOVE_STEP)
end):stop()

-- called on key-down of a move key
local function onMovePress(code, dx, dy)
    pressDir(code, dx, dy)
    moveTimer:start()
end

-- called on key-up of a move key
local function onMoveRelease(code)
    if releaseDir(code) then
        moveTimer:stop()
        step = MOVE_STEP
    end
end

--- moveFunction(code, dx, dy)
--   Returns the onPress/onRelease handlers for move keys
local function moveFunction(code, dx, dy)
    return function() onMovePress(code, dx, dy) end,
           function() onMoveRelease(code)       end
end

--------------------------------------------------------------------
-- dragFunction & helpers
--------------------------------------------------------------------
local dragActive     = false
local dragStep       = MOVE_STEP

local dragTimer = timer.doEvery(TICK, function()
    local p   = mouse.absolutePosition()
    local cdx, cdy = currentDir()
    if cdx ~= 0 and cdy ~= 0 then
        local norm = 1/math.sqrt(2)
        cdx, cdy   = cdx*norm, cdy*norm
    end
    local tgt = clamp{ x = p.x + cdx*dragStep, y = p.y + cdy*dragStep }
    mouse.absolutePosition(tgt)
    event.newMouseEvent(event.types.leftMouseDragged, tgt):post()
    dragStep = math.min(dragStep * MOVE_ACCEL, MAX_MOVE_STEP)
end):stop()

-- called on key-down of a drag key
local function onDragPress(code, dx, dy)
    pressDir(code, dx, dy)
    if not dragActive then
        dragActive = true
        local pos = mouse.absolutePosition()
        event.newMouseEvent(event.types.leftMouseDown, pos):post()
    end
    dragTimer:start()
end

-- called on key-up of a drag key
local function onDragRelease(code)
    if releaseDir(code) then
        dragTimer:stop()
        dragStep = MOVE_STEP
    end
end

--- dragFunction(code, dx, dy)
--   Returns the onPress/onRelease handlers for cmd+ctrl drag keys
local function dragFunction(code, dx, dy)
    return function() onDragPress(code, dx, dy) end,
           function() onDragRelease(code)       end
end

--------------------------------------------------------------------
-- Modifier-change watcher
--  Ends the drag (mouseUp + kill timer) only when ⌘ or ⌃ is released,
--  or any other modifier is pressed.
--------------------------------------------------------------------
_G.dragModifierChangeWatcher = eventtap.new(
    { eventtap.event.types.flagsChanged },
    function(e)
        if not dragActive then return false end
        local f = e:getFlags()
        local other = f.shift or f.ctrl or f.fn
        if not (f.cmd and f.alt) or other then
            -- finish the drag
            if dragTimer then
                dragTimer:stop()
            end
            local pos = mouse.absolutePosition()
            event.newMouseEvent(event.types.leftMouseUp, pos):post()
            -- reset all state
            dragActive    = false
            pressedDirs   = {}
            dragStep      = MOVE_STEP
        end
        return false
    end
)
_G.dragModifierChangeWatcher:start()

--------------------------------------------------------------------
-- scroll helper
--------------------------------------------------------------------
local function doScroll(dx, dy, step)
    event.newScrollEvent({ dx * step, dy * step }, {}, "pixel"):post()
end

local function onScrollPress(code, dx, dy)
    if scrollTimers[code] then return end
    local step = SCROLL_STEP
    scrollTimers[code] = timer.doEvery(TICK, function()
        doScroll(dx, dy, step)
        step = math.min(step * SCROLL_ACCEL, MAX_SCROLL_STEP)
    end)
end

local function onScrollRelease(code)
    if scrollTimers[code] then
        scrollTimers[code]:stop()
        scrollTimers[code] = nil
    end
end

--- scrollFunction(code, dx, dy)
--   Returns the onPress/onRelease handlers for scroll keys
local function scrollFunction(code, dx, dy)
    return function() onScrollPress(code, dx, dy) end,
           function() onScrollRelease(code)       end
end

--------------------------------------------------------------------
-- pointing-mode hotkeys storage
--------------------------------------------------------------------
_G.allPointingHotkeys = _G.allPointingHotkeys or {}

local function bindPointingKey(mods, key, fnDown, fnUp)
    local wrappedDown = function()
        if not _G.pointingsOn then return end
        fnDown()
    end

    local wrappedUp = nil
    if fnUp then
        wrappedUp = function()
            if not _G.pointingsOn then return end
            fnUp()
        end
    end

    local hk = hotkey.new(mods, key, wrappedDown, wrappedUp, wrappedDown)
    hk:disable()
    table.insert(_G.allPointingHotkeys, hk)
    return hk
end

--------------------------------------------------------------------
-- Click keys (NumPad 7/9) → left/right click
--------------------------------------------------------------------
-- NumPad 7 → left-click
bindPointingKey({}, 89,
    function()
        local pos = mouse.absolutePosition()
        event.newMouseEvent(event.types.leftMouseDown, pos):post()
        timer.doAfter(CLICK_DELAY, function()
            event.newMouseEvent(event.types.leftMouseUp, pos):post()
        end)
    end
)

-- NumPad 9 → right-click
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
-- Arrow keys (NumPad 8/5/4/6) → move cursor
--------------------------------------------------------------------
bindPointingKey({}, 91, moveFunction(91,  0, -1))  -- NumPad 8 → up
bindPointingKey({}, 87, moveFunction(87,  0,  1))  -- NumPad 5 → down
bindPointingKey({}, 86, moveFunction(86, -1,  0))  -- NumPad 4 → left
bindPointingKey({}, 88, moveFunction(88,  1,  0))  -- NumPad 6 → right

--------------------------------------------------------------------
-- Cmd+alt + NumPad keys → drag in four directions
--------------------------------------------------------------------
bindPointingKey({"cmd", "shift"}, 91, dragFunction(91,  0, -1))  -- NumPad 8 → drag up
bindPointingKey({"cmd", "shift"}, 87, dragFunction(87,  0,  1))  -- NumPad 5 → drag down
bindPointingKey({"cmd", "shift"}, 86, dragFunction(86, -1,  0))  -- NumPad 4 → drag left
bindPointingKey({"cmd", "shift"}, 88, dragFunction(88,  1,  0))  -- NumPad 6 → drag right

--------------------------------------------------------------------
-- Cmd+Ctrl + NumPad keys → scroll
--------------------------------------------------------------------
bindPointingKey({"cmd", "ctrl"}, 91, scrollFunction(91,  0,  1))  -- NumPad 8 → scroll up
bindPointingKey({"cmd", "ctrl"}, 87, scrollFunction(87,  0, -1))  -- NumPad 5 → scroll down
bindPointingKey({"cmd", "ctrl"}, 86, scrollFunction(86, -1,  0))  -- NumPad 4 → scroll left
bindPointingKey({"cmd", "ctrl"}, 88, scrollFunction(88,  1,  0))  -- NumPad 6 → scroll right

--------------------------------------------------------------------
-- NumPad . → teleport cursor
--------------------------------------------------------------------
bindPointingKey({}, 82,
    function()
        local dest = clamp{ x = TELEPORT_COORD.x, y = TELEPORT_COORD.y }
        mouse.absolutePosition(dest)
        event.newMouseEvent(event.types.mouseMoved, dest):post()
    end
)  -- NumPad 0 → teleport

--------------------------------------------------------------------
-- enter/exit pointing-mode (NumLock = 71)
--------------------------------------------------------------------
local menu = hs.menubar.new()
local isPointerMode = false

local function updateTitle()
  if isPointerMode then
    menu:setTitle("Key-Mouse: ON")
  else
    menu:setTitle("Key-Mouse: OFF")
  end
end

function enterPointingMode()
  _G.pointingsOn = true
  toast.showToast("Numpad: Key-Mouse ON", 2.0)
  _G.toggleHotkeys(_G.allWindowHotkeys, false)
  _G.toggleHotkeys(_G.allPointingHotkeys, true)
  isPointerMode = true
  updateTitle()
end

function exitPointingMode()
  _G.pointingsOn = false
  toast.showToast("Numpad: Key-Mouse OFF ", 2.0)
  _G.toggleHotkeys(_G.allPointingHotkeys, false)
  _G.toggleHotkeys(_G.allWindowHotkeys, true)
  moveTimer:stop()
  dragTimer:stop()
  for _, t in pairs(scrollTimers) do t:stop() end
  pressedDirs = {}
  dragActive  = false
  step        = MOVE_STEP
  dragStep    = MOVE_STEP
  isPointerMode = false
  updateTitle()
end

local function togglePointingMode()
  if _G.pointingsOn then
    exitPointingMode()
  else
    enterPointingMode()
  end
end

hotkey.new({}, 71, togglePointingMode):enable()

menu:setClickCallback(togglePointingMode)
updateTitle()