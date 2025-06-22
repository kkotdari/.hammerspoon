--------------------------------------------------------------------
-- imports / shortcuts
--------------------------------------------------------------------
local hotkey             = hs.hotkey
hotkey.setLogLevel('warning')
local window             = hs.window
local wfilter            = hs.window.filter
local screen             = hs.screen

--------------------------------------------------------------------
-- disable animations
--------------------------------------------------------------------
local DURATION = 0
hs.window.animationDuration = 0

--------------------------------------------------------------------
-- constants
--------------------------------------------------------------------
local EDGE_FRACS   = {0.75, 2/3, 0.5, 1/3, 0.25}
local CORNER_FRACS = EDGE_FRACS

local PAD4 = 86
local PAD6 = 88
local PAD8 = 91
local PAD2 = 84
local PAD7 = 89
local PAD9 = 92
local PAD1 = 83
local PAD3 = 85
local PAD5 = 87

local MODS = {"cmd", "ctrl"}

--------------------------------------------------------------------
-- per-window state
--------------------------------------------------------------------
local windowStates = {}

local function toUnitRect(pixelRect, screenFrame)
    return {
        x = (pixelRect.x - screenFrame.x) / screenFrame.w,
        y = (pixelRect.y - screenFrame.y) / screenFrame.h,
        w = pixelRect.w / screenFrame.w,
        h = pixelRect.h / screenFrame.h,
    }
end

local function activeWindow()
    return window.focusedWindow() or window.frontmostWindow()
end

local function ensureWindowState(win)
    local id = win:id()
    if not windowStates[id] then
        local f, s = win:frame(), win:screen():frame()
        windowStates[id] = {
            originalUnit = toUnitRect(f, s),
            lastUnit     = toUnitRect(f, s),
            cycle4Index  = 1,
            cycle6Index  = 1,
            cycle8Index  = 1,
            cycle2Index  = 1,
            cycle7Index  = 1,
            cycle9Index  = 1,
            cycle1Index  = 1,
            cycle3Index  = 1,
            cycle5Index  = 1,
            fullscreen   = false,
        }
    end
    return windowStates[id]
end

local wf = wfilter.new(nil)
wf:subscribe(wfilter.windowDestroyed, function(win)
    windowStates[win:id()] = nil
end)

local function resetOtherCycles(st, selfKey)
    for k,_ in pairs(st) do
        if k:match("^cycle%d+Index$") and k ~= selfKey then
            st[k] = 1
        end
    end
end

local function resetAllCycles(st)
    for k,_ in pairs(st) do
        if k:match("^cycle%d+Index$") then
            st[k] = 1
        end
    end
end

local function animateToUnit(win, unitRect)
    win:moveToUnit(unitRect, DURATION)
end

--------------------------------------------------------------------
-- hotkey helper
--------------------------------------------------------------------
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

--------------------------------------------------------------------
-- each binding: capture prev, compute newUnit, animate, show change, update state
--------------------------------------------------------------------
bindWindowKey(MODS, PAD4, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w); resetOtherCycles(st, "cycle4Index")
    local prev = st.lastUnit
    local idx  = ((st.cycle4Index - 1) % #EDGE_FRACS) + 1
    local frac = EDGE_FRACS[idx]
    local newUnit = { x=0, y=0, w=frac, h=1.0 }
    animateToUnit(w, newUnit)
    windowHelper.showToast(prev, newUnit)
    st.lastUnit = newUnit; st.cycle4Index = idx + 1
end)

bindWindowKey(MODS, PAD6, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w); resetOtherCycles(st, "cycle6Index")
    local prev = st.lastUnit
    local idx  = ((st.cycle6Index - 1) % #EDGE_FRACS) + 1
    local frac = EDGE_FRACS[idx]
    local newUnit = { x=1.0-frac, y=0, w=frac, h=1.0 }
    animateToUnit(w, newUnit)
    windowHelper.showToast(prev, newUnit)
    st.lastUnit = newUnit; st.cycle6Index = idx + 1
end)

bindWindowKey(MODS, PAD8, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w); resetOtherCycles(st, "cycle8Index")
    local prev = st.lastUnit
    local idx = ((st.cycle8Index - 1) % 4) + 1
    local unit = ({
        [1] = { x=0,   y=0,   w=1.0,   h=0.5 },
        [2] = { x=(1-1/3)/2, y=0, w=1/3,   h=0.5 },
        [3] = { x=1/4, y=0,   w=1/4,   h=0.5 },
        [4] = { x=1/2, y=0,   w=1/4,   h=0.5 },
    })[idx]
    animateToUnit(w, unit)
    windowHelper.showToast(prev, unit)
    st.lastUnit = unit; st.cycle8Index = idx + 1
end)

bindWindowKey(MODS, PAD2, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w); resetOtherCycles(st, "cycle2Index")
    local prev = st.lastUnit
    local halfH, yPos = 0.5, 0.5
    local idx = ((st.cycle2Index - 1) % 4) + 1
    local unit = ({
        [1] = { x=0,   y=1-halfH, w=1.0, h=halfH },
        [2] = { x=(1-1/3)/2, y=1-halfH, w=1/3, h=halfH },
        [3] = { x=1/4, y=1-halfH, w=1/4, h=halfH },
        [4] = { x=1/2, y=1-halfH, w=1/4, h=halfH },
    })[idx]
    animateToUnit(w, unit)
    windowHelper.showToast(prev, unit)
    st.lastUnit = unit; st.cycle2Index = idx + 1
end)

bindWindowKey(MODS, PAD7, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w); resetOtherCycles(st, "cycle7Index")
    local prev = st.lastUnit
    local idx  = ((st.cycle7Index - 1) % #CORNER_FRACS) + 1
    local frac = CORNER_FRACS[idx]
    local unit = { x=0, y=0, w=frac, h=0.5 }
    animateToUnit(w, unit)
    windowHelper.showToast(prev, unit)
    st.lastUnit = unit; st.cycle7Index = idx + 1
end)

bindWindowKey(MODS, PAD9, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w); resetOtherCycles(st, "cycle9Index")
    local prev = st.lastUnit
    local idx  = ((st.cycle9Index - 1) % #CORNER_FRACS) + 1
    local frac = CORNER_FRACS[idx]
    local unit = { x=1-frac, y=0, w=frac, h=0.5 }
    animateToUnit(w, unit)
    windowHelper.showToast(prev, unit)
    st.lastUnit = unit; st.cycle9Index = idx + 1
end)

bindWindowKey(MODS, PAD1, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w); resetOtherCycles(st, "cycle1Index")
    local prev = st.lastUnit
    local idx  = ((st.cycle1Index - 1) % #CORNER_FRACS) + 1
    local frac = CORNER_FRACS[idx]
    local unit = { x=0, y=0.5, w=frac, h=0.5 }
    animateToUnit(w, unit)
    windowHelper.showToast(prev, unit)
    st.lastUnit = unit; st.cycle1Index = idx + 1
end)

bindWindowKey(MODS, PAD3, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w); resetOtherCycles(st, "cycle3Index")
    local prev = st.lastUnit
    local idx  = ((st.cycle3Index - 1) % #CORNER_FRACS) + 1
    local frac = CORNER_FRACS[idx]
    local unit = { x=1-frac, y=0.5, w=frac, h=0.5 }
    animateToUnit(w, unit)
    windowHelper.showToast(prev, unit)
    st.lastUnit = unit; st.cycle3Index = idx + 1
end)

bindWindowKey(MODS, PAD5, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w); resetOtherCycles(st, "cycle5Index")
    local prev = st.lastUnit
    local idx  = ((st.cycle5Index - 1) % 5) + 1
    local unit
    if idx == 1 then
        local ou = st.originalUnit
        unit = { x=(1-ou.w)/2, y=(1-ou.h)/2, w=ou.w, h=ou.h }
    elseif idx == 2 then unit = { x=1/4, y=0, w=1/2, h=1.0 }
    elseif idx == 3 then unit = { x=1/3, y=0, w=1/3, h=1.0 }
    elseif idx == 4 then unit = { x=1/4, y=0, w=1/4, h=1.0 }
    else               unit = { x=1/2, y=0, w=1/4, h=1.0 }
    end
    animateToUnit(w, unit)
    windowHelper.showToast(prev, unit)
    st.lastUnit = unit; st.cycle5Index = idx + 1
end)

bindWindowKey(MODS, "return", function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local prev = st.lastUnit
    if not st.fullscreen then
        local f, s = w:frame(), w:screen():frame()
        st.previousUnit = toUnitRect(f, s)
        w:maximize()
        local unit = { x=0, y=0, w=1, h=1 }
        windowHelper.showToast(prev, unit)
        st.lastUnit, st.fullscreen = unit, true
    else
        if st.previousUnit then
            w:moveToUnit(st.previousUnit, 0)
            windowHelper.showToast(prev, st.previousUnit)
            st.lastUnit, st.fullscreen = st.previousUnit, false
        end
    end
end)

bindWindowKey(MODS, "delete", function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    if st.originalUnit then
        local prev = st.lastUnit
        w:moveToUnit(st.originalUnit, 0)
        windowHelper.showToast(prev, st.originalUnit)
        st.lastUnit, st.fullscreen = st.originalUnit, false
        resetAllCycles(st)
    end
end)

bindWindowKey(MODS, "[", function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local prev = st.lastUnit
    local all = screen.allScreens()
    local curIdx = hs.fnutils.indexOf(all, w:screen())
    local ni = (curIdx % #all) + 1
    w:moveToScreen(all[ni])
    local unit = toUnitRect(w:frame(), w:screen():frame())
    windowHelper.showToast(prev, unit)
    st.lastUnit = unit
end)

bindWindowKey(MODS, "]", function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local prev = st.lastUnit
    local all = screen.allScreens()
    local curIdx = hs.fnutils.indexOf(all, w:screen())
    local pi = curIdx - 1 > 0 and curIdx - 1 or #all
    w:moveToScreen(all[pi])
    local unit = toUnitRect(w:frame(), w:screen():frame())
    windowHelper.showToast(prev, unit)
    st.lastUnit = unit
end)

--------------------------------------------------------------------
-- activate hotkeys & indicator
--------------------------------------------------------------------
_G.toggleHotkeys(_G.allWindowHotkeys, true)
indicator.showIndicator("mode", "Calc & Organizer")