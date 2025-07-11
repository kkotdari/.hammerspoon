-- window.lua

local hotkey  = hs.hotkey
local window  = hs.window
local screen  = hs.screen
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
local resizeStates = {{1,1},{1.5,1},{2,1},{3,1},{2,2},{3,2}}
local ratioChars   = {"1","⅔","½","⅓","¼","⅙"}

-- shrink
bindHotkey(MODS, PAD_MINUS, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local idx = st.resizeIndex % #resizeStates + 1
    local a, b = table.unpack(resizeStates[idx])
    local unit = { x=(1-1/a)/2, y=(1-1/b)/2, w=1/a, h=1/b }
    w:moveToUnit(unit, 0)
    toast.showToast(ratioChars[idx])
    st.lastUnit, st.resizeIndex = unit, idx
end)

-- enlarge
bindHotkey(MODS, PAD_PLUS, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local len = #resizeStates
    local idx = (st.resizeIndex + len - 2) % len + 1
    local a, b = table.unpack(resizeStates[idx])
    local unit = { x=(1-1/a)/2, y=(1-1/b)/2, w=1/a, h=1/b }
    w:moveToUnit(unit, 0)
    toast.showToast(ratioChars[idx])
    st.lastUnit, st.resizeIndex = unit, idx
end)

-- center
bindHotkey(MODS, PAD5, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local lu = st.lastUnit
    local unit = { x=(1-lu.w)/2, y=(1-lu.h)/2, w=lu.w, h=lu.h }
    w:moveToUnit(unit, 0)
    toast.showToast("가운데로")
    st.lastUnit = unit
end)

-- restore
bindHotkey(MODS, PAD_DOT, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local unit = st.originalUnit
    w:moveToUnit(unit, 0)
    toast.showToast("처음으로")
    st.lastUnit, st.resizeIndex = unit, 1
end)

-- fullscreen
bindHotkey(MODS, PAD_ENTER, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local unit = { x=0, y=0, w=1, h=1 }
    w:moveToUnit(unit, 0)
    toast.showToast("가장 크게")
    st.lastUnit, st.resizeIndex = unit, 1
end)

-- display move
local function moveToDisplay(offset, symbol)
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local f, fs = w:frame(), w:screen():frame()
    local unit = toUnitRect(f, fs)
    local all = screen.allScreens()
    local idx = fnutils.indexOf(all, w:screen())
    local target = all[(idx - 1 + offset) % #all + 1]
    w:moveToScreen(target)
    w:moveToUnit(unit, 0)
    toast.showToast(symbol)
    st.lastUnit = unit
end
bindHotkey(MODS, PAD_DIV, function() moveToDisplay(-1, "←") end)
bindHotkey(MODS, PAD_MUL, function() moveToDisplay(1, "→") end)

-- directional move + clamp by actual frame
local dirArrows = {[1]="옮기기: ↙",[2]="옮기기: ↓",[3]="옮기기: ↘",[4]="옮기기: ←",[6]="옮기기: →",[7]="옮기기: ↖",[8]="옮기기: ↑",[9]="옮기기: ↗"}
local function moveDirection(dir)
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local lu = st.lastUnit
    local wf, hf = lu.w, lu.h
    local x, y
    if dir == "1" then x, y = 0,        1-hf
    elseif dir == "2" then x, y = (1-wf)/2, 1-hf
    elseif dir == "3" then x, y = 1-wf,   1-hf
    elseif dir == "4" then x, y = 0,        (1-hf)/2
    elseif dir == "6" then x, y = 1-wf,   (1-hf)/2
    elseif dir == "7" then x, y = 0,        0
    elseif dir == "8" then x, y = (1-wf)/2, 0
    elseif dir == "9" then x, y = 1-wf,     0
    end
    -- 1) move by stored unit
    local unit = { x = x, y = y, w = wf, h = hf }
    w:moveToUnit(unit, 0)
    toast.showToast(dirArrows[tonumber(dir)])
    -- 2) clamp by actual frame
    local f2, s2 = w:frame(), w:screen():frame()
    local clampUnit = toUnitRect(f2, s2)
    w:moveToUnit(clampUnit, 0)
    -- 3) do not update stored state
end

bindHotkey(MODS, PAD1, function() moveDirection("1") end)
bindHotkey(MODS, PAD2, function() moveDirection("2") end)
bindHotkey(MODS, PAD3, function() moveDirection("3") end)
bindHotkey(MODS, PAD4, function() moveDirection("4") end)
bindHotkey(MODS, PAD6, function() moveDirection("6") end)
bindHotkey(MODS, PAD7, function() moveDirection("7") end)
bindHotkey(MODS, PAD8, function() moveDirection("8") end)
bindHotkey(MODS, PAD9, function() moveDirection("9") end)
