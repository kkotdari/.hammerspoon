-- window.lua

local hotkey   = hs.hotkey
local window   = hs.window
local screen   = hs.screen
local fnutils  = hs.fnutils

hs.window.animationDuration = 0

-- keypad keycodes
local PAD_PLUS, PAD_MINUS = 69, 78
local PAD1, PAD2, PAD3    = 83, 84, 85
local PAD4, PAD5, PAD6    = 86, 87, 88
local PAD7, PAD8, PAD9    = 89, 91, 92
local PAD_DIV, PAD_MUL    = 75, 67
local PAD_DOT             = 65
local PAD_ENTER           = 76

local MODS     = {"cmd", "ctrl"}
local clampFrame
local applyAndClamp
local windowStates = {}

-- Convert frame to unit rect
local function toUnitRect(f, sf)
    return {
        x = (f.x - sf.x)/sf.w,
        y = (f.y - sf.y)/sf.h,
        w = f.w/sf.w,
        h = f.h/sf.h,
    }
end

-- Clamp a frame within usableFrame
clampFrame = function(f, uf)
    f.x = math.max(uf.x, math.min(f.x, uf.x + uf.w - f.w))
    f.y = math.max(uf.y, math.min(f.y, uf.y + uf.h - f.h))
    return f
end

-- Helper: move window to unit rect then clamp
applyAndClamp = function(win, unit)
    win:moveToUnit(unit, 0)
    local f2 = win:frame()
    local uf = win:screen():frame()
    win:setFrame(clampFrame(f2, uf), 0)
end

local function activeWindow()
    return window.focusedWindow() or window.frontmostWindow()
end

-- resize presets
local resizeStates = { {1,1},{1.5,1},{2,1},{3,1},{1,1.5},{1.5,1.5},{2,1.5},{3,1.5},{1,2},{1.5,2},{2,2},{3,2},{1,3},{1.5,3},{2,3},{3,3},{8,4} }
local ratioChars   = { "1×1","⅔×1","½×1","⅓×1","1×⅔","⅔×⅔","½×⅔","⅓×⅔","1×½","⅔×½","½×½","⅓×½","1×⅓","⅔×⅓","½×⅓","⅓×⅓","⅛×¼" }

local EPS = 1e-6

local function ensureWindowState(win)
    local id = win:id()
    if not windowStates[id] then
        local f, sf = win:frame(), win:screen():frame()
        -- unit rect
        local u = toUnitRect(f, sf)

        -- 1) edge-touch detection for lastDir
        local top    = math.abs(f.y - sf.y) < EPS
        local bottom = math.abs((f.y + f.h) - (sf.y + sf.h)) < EPS
        local left   = math.abs(f.x - sf.x) < EPS
        local right  = math.abs((f.x + f.w) - (sf.x + sf.w)) < EPS

        local lastDir
        if     top   and left  then lastDir = "7"
        elseif top   and not(left or right) then lastDir = "8"
        elseif top   and right then lastDir = "9"
        elseif bottom and left  then lastDir = "1"
        elseif bottom and not(left or right) then lastDir = "2"
        elseif bottom and right then lastDir = "3"
        elseif not(top or bottom) and left  then lastDir = "4"
        elseif not(top or bottom) and right then lastDir = "6"
        else  lastDir = "5" end

        -- 2) ratio-based detection for resizeIndex
        local bestIdx, bestDiff = 1, math.huge
        for i, ab in ipairs(resizeStates) do
            local a, b = ab[1], ab[2]
            local targetW, targetH = 1/a, 1/b
            local diff = math.abs(u.w - targetW) + math.abs(u.h - targetH)
            if diff < bestDiff then
                bestDiff, bestIdx = diff, i
            end
        end

        -- 만약 너무 차이가 크면(프리셋과 맞지 않으면) 센터로 초기화
        if bestDiff > 0.01 then
            u.x = 0.5 - u.w/2
            u.y = 0.5 - u.h/2
            bestIdx = 1
        end

        windowStates[id] = {
            originalUnit = u,
            lastUnit     = u,
            resizeIndex  = bestIdx,
            lastDir      = lastDir,
        }
    end
    return windowStates[id]
end

local function bindHotkey(mods, key, fn)
    local hk = hotkey.new(mods, key, fn)
    table.insert(store.allWindowHotkeys, hk)
    hk:enable()
    return hk
end

-- Find closest resize index
local function findClosestIndex(area, preferHigher)
    local bestIdx, bestDiff
    for i, ab in ipairs(resizeStates) do
        local ar = 1/(ab[1]*ab[2])
        local diff = math.abs(ar-area)
        if not bestDiff or diff<bestDiff or (diff==bestDiff and ((preferHigher and i>bestIdx) or (not preferHigher and i<bestIdx))) then
            bestDiff, bestIdx = diff, i
        end
    end
    return bestIdx
end

local function getPositionByDir(dir, wf, hf)
    if dir=="1" then return 0,1-hf
    elseif dir=="2" then return (1-wf)/2,1-hf
    elseif dir=="3" then return 1-wf,1-hf
    elseif dir=="4" then return 0,(1-hf)/2
    elseif dir=="5" then return (1-wf)/2,(1-hf)/2
    elseif dir=="6" then return 1-wf,(1-hf)/2
    elseif dir=="7" then return 0,0
    elseif dir=="8" then return (1-wf)/2,0
    elseif dir=="9" then return 1-wf,0
    end
    return (1-wf)/2,(1-hf)/2
end

-- Unified resize logic (no more findClosestIndex)
local function resizeWindow(isShrink)
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local baseIdx = st.resizeIndex or 1
    local newIdx  = isShrink and (baseIdx + 1) or (baseIdx - 1)
    if newIdx < 1 or newIdx > #resizeStates then
        toast.showToast("Cannot change")
        return
    end
    local ab = resizeStates[newIdx]
    local wf, hf = 1/ab[1], 1/ab[2]
    local x, y   = getPositionByDir(st.lastDir, wf, hf)
    local unit   = { x = x, y = y, w = wf, h = hf }
    applyAndClamp(w, unit)
    toast.showToast(ratioChars[newIdx])
    st.lastUnit, st.resizeIndex = unit, newIdx
end

bindHotkey(MODS, PAD_MINUS, function() resizeWindow(true)  end)
bindHotkey(MODS, PAD_PLUS,  function() resizeWindow(false) end)
bindHotkey(MODS, PAD_MINUS, function() resizeWindow(true) end)
bindHotkey(MODS, PAD_PLUS,  function() resizeWindow(false) end)

-- center
bindHotkey(MODS, PAD5, function()
    local w=activeWindow() if not w then return end
    local st=ensureWindowState(w)
    local u=st.lastUnit
    local unit={x=(1-u.w)/2,y=(1-u.h)/2,w=u.w,h=u.h}
    applyAndClamp(w, unit)
    toast.showToast("가운데로")
    st.lastUnit, st.lastDir = unit,"5"
end)

-- restore
bindHotkey(MODS, PAD_DOT, function()
    local w=activeWindow() if not w then return end
    local st=ensureWindowState(w)
    local unit=st.originalUnit
    applyAndClamp(w, unit)
    toast.showToast("처음으로")
    st.lastUnit, st.resizeIndex, st.lastDir = unit,1,"5"
end)

-- fullscreen
bindHotkey(MODS, PAD_ENTER, function()
    local w=activeWindow() if not w then return end
    local st=ensureWindowState(w)
    local unit={x=0,y=0,w=1,h=1}
    applyAndClamp(w, unit)
    toast.showToast("가장 크게")
    st.lastUnit, st.resizeIndex, st.lastDir = unit,1,"5"
end)

-- move one screen to the left
bindHotkey(MODS, PAD_DIV, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local unit = toUnitRect(w:frame(), w:screen():frame())
    local all  = screen.allScreens()
    local i    = fnutils.indexOf(all, w:screen())
    -- wrap to previous screen:
    local tgt  = all[((i - 2) % #all) + 1]
    w:moveToScreen(tgt)
    applyAndClamp(w, unit)
    toast.showToast("←")
    st.lastUnit = unit
end)

-- move one screen to the right
bindHotkey(MODS, PAD_MUL, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local unit = toUnitRect(w:frame(), w:screen():frame())
    local all  = screen.allScreens()
    local i    = fnutils.indexOf(all, w:screen())
    -- wrap to next screen:
    local tgt  = all[(i % #all) + 1]
    w:moveToScreen(tgt)
    applyAndClamp(w, unit)
    toast.showToast("→")
    st.lastUnit = unit
end)

-- directional move
local dirArrows={[1]="↙",[2]="↓",[3]="↘",[4]="←",[6]="→",[7]="↖",[8]="↑",[9]="↗"}
for dir,key in pairs({["1"]=PAD1,["2"]=PAD2,["3"]=PAD3,["4"]=PAD4,["6"]=PAD6,["7"]=PAD7,["8"]=PAD8,["9"]=PAD9}) do
    bindHotkey(MODS, key, function()
        local w=activeWindow() if not w then return end
        local st=ensureWindowState(w)
        st.lastDir=dir
        local u=st.lastUnit
        local wf, hf = u.w,u.h
        local x,y = getPositionByDir(dir,wf,hf)
        local unit={x=x,y=y,w=wf,h=hf}
        applyAndClamp(w, unit)
        toast.showToast(dirArrows[tonumber(dir)])
        st.lastUnit = unit
    end)
end