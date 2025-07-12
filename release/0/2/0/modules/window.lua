-- window.lua

local hotkey = hs.hotkey
local window = hs.window
local screen = hs.screen
local fnutils = hs.fnutils

hs.window.animationDuration = 0

-- keypad keycodes
local PAD_PLUS, PAD_MINUS = 69, 78
local PAD1, PAD2, PAD3    = 83, 84, 85
local PAD4, PAD5, PAD6    = 86, 87, 88
local PAD7, PAD8, PAD9    = 89, 91, 92
local PAD_DIV, PAD_MUL    = 75, 67   -- '/' and '*'
local PAD_DOT             = 65       -- '.'
local PAD_ENTER           = 76       -- Enter

local MODS = {"cmd", "ctrl"}

-- per-window state
local windowStates = {}

-- convert a frame to unit rect
local function toUnitRect(frame, screenFrame)
    return {
        x = (frame.x - screenFrame.x) / screenFrame.w,
        y = (frame.y - screenFrame.y) / screenFrame.h,
        w = frame.w / screenFrame.w,
        h = frame.h / screenFrame.h,
    }
end

-- get active window
local function activeWindow()
    return window.focusedWindow() or window.frontmostWindow()
end

-- ensure state exists
local function ensureWindowState(win)
    local id = win:id()
    if not windowStates[id] then
        local f, s = win:frame(), win:screen():frame()
        windowStates[id] = {
            originalUnit = toUnitRect(f, s),
            lastUnit     = toUnitRect(f, s),
            resizeIndex  = 1,
            lastDir      = "5",
        }
    end
    return windowStates[id]
end

-- bind helper
local function bindHotkey(mods, key, fn)
    local wrapped = function()
        if _G.pointingsOn then return end
        fn()
    end
    local hk = hotkey.new(mods, key, wrapped)
    table.insert(_G.allWindowHotkeys, hk)
    hk:enable()
    return hk
end

-- resize presets and labels
local resizeStates = {{1,1}, {1.5,1}, {2,1}, {3,1}, {2,2}, {3,2}}
local ratioChars   = {"× 1", "× ⅔", "× ½", "× ⅓", "× ¼", "× ⅙"}

-- helper: compute position based on direction
local function getPositionByDir(dir, wf, hf)
    if     dir == "1" then return 0,        1 - hf
    elseif dir == "2" then return (1 - wf)/2, 1 - hf
    elseif dir == "3" then return 1 - wf,     1 - hf
    elseif dir == "4" then return 0,        (1 - hf)/2
    elseif dir == "5" then return (1 - wf)/2, (1 - hf)/2
    elseif dir == "6" then return 1 - wf,     (1 - hf)/2
    elseif dir == "7" then return 0,        0
    elseif dir == "8" then return (1 - wf)/2, 0
    elseif dir == "9" then return 1 - wf,     0
    end
    return (1 - wf)/2, (1 - hf)/2
end

-- find nearest preset index based on current unit
local function findNearestIndex(wf, hf)
    local area = wf * hf
    local bestIdx, bestDiff
    for i, ab in ipairs(resizeStates) do
        local a, b   = ab[1], ab[2]
        local pw, ph = 1 / a, 1 / b
        local diff   = math.abs((pw * ph) - area)
        if not bestDiff or diff < bestDiff then
            bestDiff = diff
            bestIdx  = i
        end
    end
    return bestIdx or 1
end

-- shrink (줄이기)
bindHotkey(MODS, PAD_MINUS, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local cur = findNearestIndex(st.lastUnit.w, st.lastUnit.h)
    -- already smallest?
    if cur >= #resizeStates then
        toast.showToast("더 줄일 수 없어요")
        return
    end
    local next = cur + 1
    local a, b = table.unpack(resizeStates[next])
    local wf, hf = 1 / a, 1 / b
    local x, y   = getPositionByDir(st.lastDir, wf, hf)
    local unit   = { x = x, y = y, w = wf, h = hf }
    w:moveToUnit(unit, 0)
    toast.showToast(ratioChars[next])
    st.lastUnit, st.resizeIndex = unit, next
end)

-- enlarge (늘리기)
bindHotkey(MODS, PAD_PLUS, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local cur = findNearestIndex(st.lastUnit.w, st.lastUnit.h)
    -- already largest?
    if cur <= 1 then
        toast.showToast("더 늘릴 수 없어요")
        return
    end
    local next = cur - 1
    local a, b   = table.unpack(resizeStates[next])
    local wf, hf = 1 / a, 1 / b
    local x, y   = getPositionByDir(st.lastDir, wf, hf)
    local unit   = { x = x, y = y, w = wf, h = hf }
    w:moveToUnit(unit, 0)
    toast.showToast(ratioChars[next])
    st.lastUnit, st.resizeIndex = unit, next
end)

-- center
bindHotkey(MODS, PAD5, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local lu   = st.lastUnit
    local unit = { x = (1 - lu.w)/2, y = (1 - lu.h)/2, w = lu.w, h = lu.h }
    w:moveToUnit(unit, 0)
    toast.showToast("가운데로")
    st.lastUnit, st.lastDir = unit, "5"
end)

-- restore
bindHotkey(MODS, PAD_DOT, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local unit                = st.originalUnit
    w:moveToUnit(unit, 0)
    toast.showToast("처음으로")
    st.lastUnit, st.resizeIndex, st.lastDir = unit, 1, "5"
end)

-- fullscreen
bindHotkey(MODS, PAD_ENTER, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local unit = { x = 0, y = 0, w = 1, h = 1 }
    w:moveToUnit(unit, 0)
    toast.showToast("가장 크게")
    st.lastUnit, st.resizeIndex, st.lastDir = unit, 1, "5"
end)

-- display move
local function moveToDisplay(offset, symbol)
    local w  = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local f, fs = w:frame(), w:screen():frame()
    local unit  = toUnitRect(f, fs)
    local all   = screen.allScreens()
    local idx   = fnutils.indexOf(all, w:screen())
    local tgt   = all[(idx - 1 + offset) % #all + 1]
    w:moveToScreen(tgt)
    w:moveToUnit(unit, 0)
    toast.showToast(symbol)
    st.lastUnit = unit
end
bindHotkey(MODS, PAD_DIV, function() moveToDisplay(-1, "←") end)
bindHotkey(MODS, PAD_MUL, function() moveToDisplay(1,  "→") end)

-- directional move + clamp
local dirArrows = {[1]="↙",[2]="↓",[3]="↘",[4]="←",[6]="→",[7]="↖",[8]="↑",[9]="↗"}
local function moveDirection(dir)
    local w  = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    st.lastDir = dir
    local lu  = st.lastUnit
    local wf, hf = lu.w, lu.h
    local x, y   = getPositionByDir(dir, wf, hf)
    local unit   = { x = x, y = y, w = wf, h = hf }
    w:moveToUnit(unit, 0)
    toast.showToast("옮기기: " .. dirArrows[tonumber(dir)])
    local f2, s2    = w:frame(), w:screen():frame()
    local clampUnit = toUnitRect(f2, s2)
    w:moveToUnit(clampUnit, 0)
end
bindHotkey(MODS, PAD1, function() moveDirection("1") end)
bindHotkey(MODS, PAD2, function() moveDirection("2") end)
bindHotkey(MODS, PAD3, function() moveDirection("3") end)
bindHotkey(MODS, PAD4, function() moveDirection("4") end)
bindHotkey(MODS, PAD6, function() moveDirection("6") end)
bindHotkey(MODS, PAD7, function() moveDirection("7") end)
bindHotkey(MODS, PAD8, function() moveDirection("8") end)
bindHotkey(MODS, PAD9, function() moveDirection("9") end)