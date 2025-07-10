-- organizeWindow.lua

local hotkey = hs.hotkey
local window = hs.window
local screen = hs.screen

hs.window.animationDuration = 0

-- numeric keypad keycodes
local PAD_PLUS, PAD_MINUS = 69, 78
local PAD1, PAD2, PAD3      = 83, 84, 85
local PAD4, PAD5, PAD6      = 86, 87, 88
local PAD7, PAD8, PAD9      = 89, 91, 92

local MODS = {"cmd", "ctrl"}

-- per-window state storage
local windowStates = {}

-- helper: convert frame to unit rect
local function toUnitRect(f, s)
    return { x=(f.x - s.x)/s.w, y=(f.y - s.y)/s.h, w=f.w/s.w, h=f.h/s.h }
end

-- get focused or frontmost window
local function activeWindow()
    return window.focusedWindow() or window.frontmostWindow()
end

-- ensure state exists for this window
local function ensureWindowState(win)
    local id = win:id()
    if not windowStates[id] then
        windowStates[id] = {
            originalUnit = toUnitRect(win:frame(), win:screen():frame()),
            lastUnit     = toUnitRect(win:frame(), win:screen():frame()),
            resizeIndex  = 1,
            cycle5Index  = 1,
            pad5Units    = nil,
        }
    end
    return windowStates[id]
end

-- resizing presets: {a, b} means w = screenW/a, h = screenH/b
local resizeStates = {
    {1,1}, {1.5,1}, {2,1}, {3,1}, {2,2}, {3,2},
}

-- bind helper preserving hotkey objects and respecting pointing mode
local function bindWindowKey(mods, key, fn)
    local wrapped = function()
        if _G.pointingsOn then return end
        fn()
    end
    local hk = hotkey.new(mods, key, wrapped)
    table.insert(_G.allWindowHotkeys, hk)
    hk:enable()
    return hk
end

-- '-' key: cycle resize forward relative to current
bindWindowKey(MODS, PAD_MINUS, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    -- reset 5-key cycle
    st.cycle5Index = 1
    st.pad5Units = nil
    -- compute next resize index
    local len = #resizeStates
    local idx = st.resizeIndex
    local nextIdx = idx % len + 1
    -- apply resize
    local a,b = table.unpack(resizeStates[nextIdx])
    local wFrac, hFrac = 1/a, 1/b
    local unit = { x=(1-wFrac)/2, y=(1-hFrac)/2, w=wFrac, h=hFrac }
    w:moveToUnit(unit, 0)
    -- update state
    st.lastUnit = unit
    st.resizeIndex = nextIdx
end)

-- '+' key: cycle resize backward relative to current
bindWindowKey(MODS, PAD_PLUS, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    -- reset 5-key cycle
    st.cycle5Index = 1
    st.pad5Units = nil
    -- compute previous resize index
    local len = #resizeStates
    local idx = st.resizeIndex
    local prevIdx = (idx + len - 2) % len + 1
    -- apply resize
    local a,b = table.unpack(resizeStates[prevIdx])
    local wFrac, hFrac = 1/a, 1/b
    local unit = { x=(1-wFrac)/2, y=(1-hFrac)/2, w=wFrac, h=hFrac }
    w:moveToUnit(unit, 0)
    -- update state
    st.lastUnit = unit
    st.resizeIndex = prevIdx
end)

-- '5' key: four-step cycle (center current, center original, original pos, fullscreen)
bindWindowKey(MODS, PAD5, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    if not st.pad5Units then
        local lu, ou = st.lastUnit, st.originalUnit
        -- compute units
        local sw, sh = lu.w, lu.h
        local sx, sy = (1-sw)/2, (1-sh)/2
        local ox, oy = (1-ou.w)/2, (1-ou.h)/2
        st.pad5Units = {
            { x=sx,   y=sy,   w=sw,    h=sh    },
            { x=ox,   y=oy,   w=ou.w,  h=ou.h  },
            { x=ou.x, y=ou.y, w=ou.w,  h=ou.h  },
            { x=0,    y=0,    w=1,     h=1     },
        }
        st.cycle5Index = 1
    end
    local idx = st.cycle5Index
    local unit = st.pad5Units[idx]
    w:moveToUnit(unit, 0)
    st.lastUnit = unit
    st.cycle5Index = idx % #st.pad5Units + 1
end)

-- direction keys: move window to screen edge while keeping size, reset 5-key cycle
local function moveDirection(dir)
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    st.cycle5Index = 1
    st.pad5Units = nil
    local lu = st.lastUnit
    local wf, hf = lu.w, lu.h
    local x, y
    if dir == "1" then x,y = 0,      1-hf
    elseif dir == "2" then x,y = (1-wf)/2, 1-hf
    elseif dir == "3" then x,y = 1-wf,   1-hf
    elseif dir == "4" then x,y = 0,      (1-hf)/2
    elseif dir == "6" then x,y = 1-wf,   (1-hf)/2
    elseif dir == "7" then x,y = 0,      0      
    elseif dir == "8" then x,y = (1-wf)/2, 0      
    elseif dir == "9" then x,y = 1-wf,   0      
    end
    local unit = { x=x, y=y, w=wf, h=hf }
    w:moveToUnit(unit, 0)
    st.lastUnit = unit
end

bindWindowKey(MODS, PAD1, function() moveDirection("1") end)
bindWindowKey(MODS, PAD2, function() moveDirection("2") end)
bindWindowKey(MODS, PAD3, function() moveDirection("3") end)
bindWindowKey(MODS, PAD4, function() moveDirection("4") end)
bindWindowKey(MODS, PAD6, function() moveDirection("6") end)
bindWindowKey(MODS, PAD7, function() moveDirection("7") end)
bindWindowKey(MODS, PAD8, function() moveDirection("8") end)
bindWindowKey(MODS, PAD9, function() moveDirection("9") end)