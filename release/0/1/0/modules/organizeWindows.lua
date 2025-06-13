--------------------------------------------------------------------
-- imports / shortcuts
--------------------------------------------------------------------
local hotkey       = hs.hotkey
hotkey.setLogLevel('warning')
local window       = hs.window
local wfilter      = hs.window.filter
local screen       = hs.screen

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

local PAD4 = 86   -- NumPad 4 (left edge)
local PAD6 = 88   -- NumPad 6 (right edge)
local PAD8 = 91   -- NumPad 8 (top edge)
local PAD2 = 84   -- NumPad 2 (bottom edge)
local PAD7 = 89   -- NumPad 7 (top-left corner)
local PAD9 = 92   -- NumPad 9 (top-right corner)
local PAD1 = 83   -- NumPad 1 (bottom-left corner)
local PAD3 = 85   -- NumPad 3 (bottom-right corner)
local PAD5 = 87   -- NumPad 5 (centre toggle)

local MODS = {"cmd", "ctrl"}

--------------------------------------------------------------------
-- per-window state
--------------------------------------------------------------------
local windowStates = {}

-- Convert pixel rect to unit coords
local function toUnitRect(pixelRect, screenFrame)
    return {
        x = (pixelRect.x - screenFrame.x) / screenFrame.w,
        y = (pixelRect.y - screenFrame.y) / screenFrame.h,
        w = pixelRect.w / screenFrame.w,
        h = pixelRect.h / screenFrame.h,
    }
end

-- window select helper ▼
local function activeWindow()
    return window.focusedWindow() or window.frontmostWindow()
end

-- Ensure a state table exists for this window
local function ensureWindowState(win)
    local id = win:id()
    if not windowStates[id] then
        local f      = win:frame()
        local sFrame = win:screen():frame()
        windowStates[id] = {
            originalUnit  = toUnitRect(f, sFrame),
            lastUnit      = toUnitRect(f, sFrame),
            cycle4Index   = 1,
            cycle6Index   = 1,
            cycle8Index   = 1,
            cycle2Index   = 1,
            cycle7Index   = 1,
            cycle9Index   = 1,
            cycle1Index   = 1,
            cycle3Index   = 1,
            cycle5Index   = 1,
            fullscreen    = false,
        }
    end
    return windowStates[id]
end

-- Clean up when a window is destroyed
local wf = wfilter.new(nil)
wf:subscribe(wfilter.windowDestroyed, function(win)
    windowStates[win:id()] = nil
end)

-- Reset all other cycle indices except the one in use
local function resetOtherCycles(st, selfKey)
    for k,_ in pairs(st) do
        if k:match("^cycle%d+Index$") and k ~= selfKey then
            st[k] = 1
        end
    end
end

-- Reset all cycle indices to 1
local function resetAllCycles(st)
    for k,_ in pairs(st) do
        if k:match("^cycle%d+Index$") then
            st[k] = 1
        end
    end
end

-- Animate window to unit rect (instant, since DURATION = 0)
local function animateToUnit(win, unitRect)
    win:moveToUnit(unitRect, DURATION)
end

--------------------------------------------------------------------
-- Hotkey registration helper
--------------------------------------------------------------------
local function bindWindowKey(mods, key, fn)
    -- Skip execution if pointing-mode is active
    local wrappedFn = function()
        if _G.pointingsOn then return end
        fn()
    end

    local hk = hotkey.new(mods, key, wrappedFn)
    table.insert(_G.allWindowHotkeys, hk)
    hk:enable()
    return hk
end

--------------------------------------------------------------------
-- NUMPAD 4: left edge, full height, width cycles ¾ → ⅔ → ½ → ⅓ → ¼
--------------------------------------------------------------------
bindWindowKey(MODS, PAD4, function()
    local w = activeWindow()
    if not w then return end
    local st = ensureWindowState(w)
    resetOtherCycles(st, "cycle4Index")

    local idx  = ((st.cycle4Index - 1) % #EDGE_FRACS) + 1
    local frac = EDGE_FRACS[idx]
    local newUnit = { x = 0, y = 0, w = frac, h = 1.0 }

    animateToUnit(w, newUnit)
    st.lastUnit = newUnit
    st.cycle4Index = idx + 1
end)

--------------------------------------------------------------------
-- NUMPAD 6: right edge, full height, width cycles ¾ → ⅔ → ½ → ⅓ → ¼
--------------------------------------------------------------------
bindWindowKey(MODS, PAD6, function()
    local w = activeWindow()
    if not w then return end
    local st = ensureWindowState(w)
    resetOtherCycles(st, "cycle6Index")

    local idx  = ((st.cycle6Index - 1) % #EDGE_FRACS) + 1
    local frac = EDGE_FRACS[idx]
    local newUnit = { x = 1.0 - frac, y = 0, w = frac, h = 1.0 }

    animateToUnit(w, newUnit)
    st.lastUnit = newUnit
    st.cycle6Index = idx + 1
end)

--------------------------------------------------------------------
-- NUMPAD 8: top edge, half height, width cycles [full → ⅓(slot2) → ¼(slot2) → ¼(slot3)]
--------------------------------------------------------------------
bindWindowKey(MODS, PAD8, function()
    local w = activeWindow()
    if not w then return end
    local st = ensureWindowState(w)
    resetOtherCycles(st, "cycle8Index")

    local idx = ((st.cycle8Index - 1) % 4) + 1
    local unitRect
    if idx == 1 then
        unitRect = { x = 0, y = 0, w = 1.0, h = 0.5 }
    elseif idx == 2 then
        unitRect = { x = (1.0 - 1/3)/2, y = 0, w = 1/3, h = 0.5 }  -- ⅓ (slot2)
    elseif idx == 3 then
        unitRect = { x = 1/4, y = 0, w = 1/4, h = 0.5 }           -- ¼ (slot2)
    else
        unitRect = { x = 1/2, y = 0, w = 1/4, h = 0.5 }           -- ¼ (slot3)
    end

    animateToUnit(w, unitRect)
    st.lastUnit = unitRect
    st.cycle8Index = idx + 1
end)

--------------------------------------------------------------------
-- NUMPAD 2: bottom edge, half height, width cycles [full → ⅓(slot2) → ¼(slot2) → ¼(slot3)]
--------------------------------------------------------------------
bindWindowKey(MODS, PAD2, function()
    local w = activeWindow()
    if not w then return end
    local st = ensureWindowState(w)
    resetOtherCycles(st, "cycle2Index")

    local idx  = ((st.cycle2Index - 1) % 4) + 1
    local halfH = 0.5
    local yPos  = 1.0 - halfH
    local unitRect
    if idx == 1 then
        unitRect = { x = 0, y = yPos, w = 1.0, h = halfH }
    elseif idx == 2 then
        unitRect = { x = (1.0 - 1/3)/2, y = yPos, w = 1/3, h = halfH }  -- ⅓ (slot2)
    elseif idx == 3 then
        unitRect = { x = 1/4, y = yPos, w = 1/4, h = halfH }            -- ¼ (slot2)
    else
        unitRect = { x = 1/2, y = yPos, w = 1/4, h = halfH }            -- ¼ (slot3)
    end

    animateToUnit(w, unitRect)
    st.lastUnit = unitRect
    st.cycle2Index = idx + 1
end)

--------------------------------------------------------------------
-- NUMPAD 7: top-left corner, half height, width cycles ¾ → ⅔ → ½ → ⅓ → ¼
--------------------------------------------------------------------
bindWindowKey(MODS, PAD7, function()
    local w = activeWindow()
    if not w then return end
    local st = ensureWindowState(w)
    resetOtherCycles(st, "cycle7Index")

    local idx  = ((st.cycle7Index - 1) % #CORNER_FRACS) + 1
    local frac = CORNER_FRACS[idx]
    local unitRect = { x = 0, y = 0, w = frac, h = 0.5 }

    animateToUnit(w, unitRect)
    st.lastUnit = unitRect
    st.cycle7Index = idx + 1
end)

--------------------------------------------------------------------
-- NUMPAD 9: top-right corner, half height, width cycles ¾ → ⅔ → ½ → ⅓ → ¼
--------------------------------------------------------------------
bindWindowKey(MODS, PAD9, function()
    local w = activeWindow()
    if not w then return end
    local st = ensureWindowState(w)
    resetOtherCycles(st, "cycle9Index")

    local idx  = ((st.cycle9Index - 1) % #CORNER_FRACS) + 1
    local frac = CORNER_FRACS[idx]
    local unitRect = { x = 1.0 - frac, y = 0, w = frac, h = 0.5 }

    animateToUnit(w, unitRect)
    st.lastUnit = unitRect
    st.cycle9Index = idx + 1
end)

--------------------------------------------------------------------
-- NUMPAD 1: bottom-left corner, half height, width cycles ¾ → ⅔ → ½ → ⅓ → ¼
--------------------------------------------------------------------
bindWindowKey(MODS, PAD1, function()
    local w = activeWindow()
    if not w then return end
    local st = ensureWindowState(w)
    resetOtherCycles(st, "cycle1Index")

    local idx  = ((st.cycle1Index - 1) % #CORNER_FRACS) + 1
    local frac = CORNER_FRACS[idx]
    local halfH = 0.5
    local yPos  = 1.0 - halfH
    local unitRect = { x = 0, y = yPos, w = frac, h = halfH }

    animateToUnit(w, unitRect)
    st.lastUnit = unitRect
    st.cycle1Index = idx + 1
end)

--------------------------------------------------------------------
-- NUMPAD 3: bottom-right corner, half height, width cycles ¾ → ⅔ → ½ → ⅓ → ¼
--------------------------------------------------------------------
bindWindowKey(MODS, PAD3, function()
    local w = activeWindow()
    if not w then return end
    local st = ensureWindowState(w)
    resetOtherCycles(st, "cycle3Index")

    local idx  = ((st.cycle3Index - 1) % #CORNER_FRACS) + 1
    local frac = CORNER_FRACS[idx]
    local halfH = 0.5
    local yPos  = 1.0 - halfH
    local unitRect = { x = 1.0 - frac, y = yPos, w = frac, h = halfH }

    animateToUnit(w, unitRect)
    st.lastUnit = unitRect
    st.cycle3Index = idx + 1
end)

--------------------------------------------------------------------
-- NUMPAD 5: centre toggle — original-centre → ⅓(slot2) → ¼(slot2) → ¼(slot3)
--------------------------------------------------------------------
bindWindowKey(MODS, PAD5, function()
    local w = activeWindow()
    if not w then return end
    local st = ensureWindowState(w)
    resetOtherCycles(st, "cycle5Index")

    local idx = ((st.cycle5Index - 1) % 5) + 1
    local unitRect
    if idx == 1 then
        local ou = st.originalUnit
        unitRect = {
            x = (1.0 - ou.w) / 2,
            y = (1.0 - ou.h) / 2,
            w = ou.w,
            h = ou.h
        }
    elseif idx == 2 then
        unitRect = { x = 1/4, y = 0, w = 1/2, h = 1.0 }
    elseif idx == 3 then
        unitRect = { x = 1/3, y = 0, w = 1/3, h = 1.0 }
    elseif idx == 4 then
        unitRect = { x = 1/4, y = 0, w = 1/4, h = 1.0 }
    else
        unitRect = { x = 1/2, y = 0, w = 1/4, h = 1.0 }
    end

    animateToUnit(w, unitRect)
    st.lastUnit = unitRect
    st.cycle5Index = idx + 1
end)

--------------------------------------------------------------------
-- RETURN: toggle fullscreen ↔ restore previous frame
--------------------------------------------------------------------
bindWindowKey(MODS, "return", function()
    local w = activeWindow()
    if not w then return end
    local st = ensureWindowState(w)
    if not st.fullscreen then
        local f      = w:frame()
        local sFrame = w:screen():frame()
        st.previousUnit = toUnitRect(f, sFrame)
        w:maximize()
        st.lastUnit = { x = 0, y = 0, w = 1.0, h = 1.0 }
        st.fullscreen = true
    else
        if st.previousUnit then
            w:moveToUnit(st.previousUnit, 0)
            st.lastUnit = st.previousUnit
        end
        st.fullscreen = false
    end
end)

--------------------------------------------------------------------
-- Backspace: restore original frame + reset all cycle indices
--------------------------------------------------------------------
bindWindowKey(MODS, "delete", function()
    local w = activeWindow()
    if not w then return end
    local st = ensureWindowState(w)
    if st.originalUnit then
        w:moveToUnit(st.originalUnit, 0)
        st.lastUnit = st.originalUnit
        resetAllCycles(st)
        st.fullscreen = false
    end
end)

--------------------------------------------------------------------
-- Cmd+Ctrl+[ : move window to previous display
-- Cmd+Ctrl+] : move window to next display
--------------------------------------------------------------------
bindWindowKey(MODS, "[", function()
    local w = activeWindow()
    if not w then return end
    local currentScreen = w:screen()
    local allScreens    = screen.allScreens()
    local idx = hs.fnutils.indexOf(allScreens, currentScreen)
    if not idx then return end
    local prevIndex = idx - 1
    if prevIndex < 1 then prevIndex = #allScreens end
    w:moveToScreen(allScreens[prevIndex])
    local f      = w:frame()
    local sFrame = w:screen():frame()
    windowStates[w:id()].lastUnit = toUnitRect(f, sFrame)
end)

bindWindowKey(MODS, "]", function()
    local w = activeWindow()
    if not w then return end
    local currentScreen = w:screen()
    local allScreens    = screen.allScreens()
    local idx = hs.fnutils.indexOf(allScreens, currentScreen)
    if not idx then return end
    local nextIndex = idx + 1
    if nextIndex > #allScreens then nextIndex = 1 end
    w:moveToScreen(allScreens[nextIndex])
    local f      = w:frame()
    local sFrame = w:screen():frame()
    windowStates[w:id()].lastUnit = toUnitRect(f, sFrame)
end)

--------------------------------------------------------------------
-- expose disable/enable functions for pointings.lua
--------------------------------------------------------------------
-- Ensure window hotkeys are active on load
_G.toggleHotkeys(_G.allWindowHotkeys, true)
indicator.showIndicator("mode", "🖥️ Window mode")