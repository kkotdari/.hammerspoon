-- window.lua

local hotkey = hs.hotkey
local window = hs.window
local screen = hs.screen
local fnutils = hs.fnutils

hs.window.animationDuration = 0

-- Keypad key codes
local PAD_PLUS, PAD_MINUS = 69, 78
local PAD1, PAD2, PAD3    = 83, 84, 85
local PAD4, PAD5, PAD6    = 86, 87, 88
local PAD7, PAD8, PAD9    = 89, 91, 92
local PAD_DIV, PAD_MUL    = 75, 67   -- '/' and '*'
local PAD_DOT             = 65       -- '.'
local PAD_ENTER           = 76       -- Enter

local MODS = {"cmd", "ctrl"}
local windowStates = {}

-- Convert pixel frame to unit rect
local function toUnitRect(f, sf)
    return { x=(f.x-sf.x)/sf.w, y=(f.y-sf.y)/sf.h, w=f.w/sf.w, h=f.h/sf.h }
end

-- Get active window
local function activeWindow()
    return window.focusedWindow() or window.frontmostWindow()
end

-- Initialize or retrieve window state
local function ensureWindowState(win)
    local id = win:id()
    if not windowStates[id] then
        local f, sf = win:frame(), win:screen():frame()
        windowStates[id] = { originalUnit=toUnitRect(f,sf), lastUnit=toUnitRect(f,sf), resizeIndex=nil, lastDir="5" }
    end
    return windowStates[id]
end

-- Bind a hotkey
local function bindHotkey(mods, key, fn)
    local hk = hotkey.new(mods, key, function() if not _G.pointingsOn then fn() end end)
    table.insert(_G.allWindowHotkeys, hk)
    hk:enable()
    return hk
end

-- Resize presets and labels
local resizeStates = {{1,1}, {1.5,1}, {2,1}, {3,1}, {1,1.5}, {1.5,1.5}, {2,1.5}, {3,1.5}, {1,2}, {1.5,2}, {2,2}, {3,2}, {1,3}, {1.5,3}, {2,3}, {3,3}, {8,4}}
local ratioChars   = {"1×1","⅔×1","½×1","⅓×1","1×⅔","⅔×⅔","½×⅔","⅓×⅔","1×½","⅔×½","½×½","⅓×½","1×⅓","⅔×⅓","½×⅓","⅓×⅓","⅛×¼"}

-- Compute position by direction
local function getPositionByDir(dir, wf, hf)
    local map = { ["1"]={0,1-hf}, ["2"]={(1-wf)/2,1-hf}, ["3"]={1-wf,1-hf}, ["4"]={0,(1-hf)/2}, ["5"]={(1-wf)/2,(1-hf)/2}, ["6"]={1-wf,(1-hf)/2}, ["7"]={0,0}, ["8"]={(1-wf)/2,0}, ["9"]={1-wf,0} }
    return table.unpack(map[dir] or map["5"])
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

-- Unified resize logic
local function resizeWindow(isShrink)
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local area = st.lastUnit.w * st.lastUnit.h
    local baseIdx = st.resizeIndex or findClosestIndex(area, isShrink)
    local newIdx  = isShrink and baseIdx+1 or baseIdx-1
    if newIdx<1 or newIdx>#resizeStates then toast.showToast("Cannot change") return end
    local ab = resizeStates[newIdx]
    local wf, hf = 1/ab[1], 1/ab[2]
    local x,y = getPositionByDir(st.lastDir, wf, hf)
    local unit = { x=x, y=y, w=wf, h=hf }
    w:moveToUnit(unit,0); toast.showToast(ratioChars[newIdx])
    st.lastUnit, st.resizeIndex = unit, newIdx
end
bindHotkey(MODS, PAD_MINUS, function() resizeWindow(true) end)
bindHotkey(MODS, PAD_PLUS,  function() resizeWindow(false) end)

-- Center window position
bindHotkey(MODS, PAD5, function()
    local w=activeWindow() if not w then return end
    local st=ensureWindowState(w)
    local u=st.lastUnit
    local unit={x=(1-u.w)/2,y=(1-u.h)/2,w=u.w,h=u.h}
    w:moveToUnit(unit,0); toast.showToast("Center")
    st.lastUnit, st.lastDir = unit, "5"
end)

-- Restore original size
bindHotkey(MODS, PAD_DOT, function()
    local w=activeWindow() if not w then return end
    local st=ensureWindowState(w)
    local unit=st.originalUnit
    w:moveToUnit(unit,0); toast.showToast("Restore")
    st.lastUnit, st.resizeIndex = unit, nil
end)

-- Fullscreen
bindHotkey(MODS, PAD_ENTER, function()
    local w=activeWindow() if not w then return end
    local st=ensureWindowState(w)
    local unit={x=0,y=0,w=1,h=1}
    w:moveToUnit(unit,0); toast.showToast("Fullscreen")
    st.lastUnit, st.resizeIndex = unit, 1
end)

-- Move across displays with clamp
local function moveToDisplay(offset, sym)
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local f, sf = w:frame(), w:screen():frame()
    local unit = toUnitRect(f, sf)
    local scr = screen.allScreens()
    local i = fnutils.indexOf(scr, w:screen())
    local tgt = scr[(i - 1 + offset) % #scr + 1]
    w:moveToScreen(tgt)
    w:moveToUnit(unit, 0)
    -- clamp to usableFrame
    local f2 = w:frame()
    local uf = tgt:usableFrame()
    local cx = math.max(uf.x, math.min(f2.x, uf.x + uf.w - f2.w))
    local cy = math.max(uf.y, math.min(f2.y, uf.y + uf.h - f2.h))
    w:setFrame({ x = cx, y = cy, w = f2.w, h = f2.h }, 0)
    -- update state
    local newSF = w:screen():frame()
    st.lastUnit = toUnitRect(w:frame(), newSF)
    toast.showToast(sym)
end
bindHotkey(MODS, PAD_DIV, function() moveToDisplay(-1, "←") end)
bindHotkey(MODS, PAD_MUL, function() moveToDisplay(1,  "→") end)
bindHotkey(MODS, PAD_MUL, function() moveToDisplay(1,  "→") end)

-- Directional move with clamp
local dirArrows = { [1]="↙", [2]="↓", [3]="↘", [4]="←", [6]="→", [7]="↖", [8]="↑", [9]="↗" }
local function moveDirection(dir)
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    st.lastDir = dir
    local u = st.lastUnit
    local wf, hf = u.w, u.h
    -- compute and apply move
    local x, y = getPositionByDir(dir, wf, hf)
    w:moveToUnit({ x = x, y = y, w = wf, h = hf }, 0)
    toast.showToast(dirArrows[tonumber(dir)])
    -- clamp to usable frame
    local f2 = w:frame()
    local uf = w:screen():usableFrame()
    local cx = math.max(uf.x, math.min(f2.x, uf.x + uf.w - f2.w))
    local cy = math.max(uf.y, math.min(f2.y, uf.y + uf.h - f2.h))
    w:setFrame({ x = cx, y = cy, w = f2.w, h = f2.h }, 0)
end
for dir, key in pairs({ ["1"]=PAD1, ["2"]=PAD2, ["3"]=PAD3, ["4"]=PAD4, ["6"]=PAD6, ["7"]=PAD7, ["8"]=PAD8, ["9"]=PAD9 }) do
    bindHotkey(MODS, key, function() moveDirection(dir) end)
end