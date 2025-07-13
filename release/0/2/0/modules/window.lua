-- window.lua

local hotkey = hs.hotkey
local window = hs.window
local screen = hs.screen
local fnutils = hs.fnutils

hs.window.animationDuration = 0

-- Keypad key codes
local PAD1, PAD2, PAD3 = 83, 84, 85
local PAD4, PAD5, PAD6 = 86, 87, 88
local PAD7, PAD8, PAD9 = 89, 91, 92
local PAD_DIV, PAD_MUL = 75, 67
local PAD_DOT         = 65
local PAD_ENTER       = 76

-- Modifier sets
local MOVE_MODS = {"cmd", "ctrl"}
local SIZE_MODS = {"cmd", "shift"}

-- Per-window state
local windowStates = {}

-- Convert pixel frame to unit rect
local function toUnitRect(f, sf)
    return { x=(f.x - sf.x)/sf.w, y=(f.y - sf.y)/sf.h, w=f.w/sf.w, h=f.h/sf.h }
end

-- Clamp a frame within bounds
local function clampFrame(frame, uf)
    frame.x = math.max(uf.x, math.min(frame.x, uf.x + uf.w - frame.w))
    frame.y = math.max(uf.y, math.min(frame.y, uf.y + uf.h - frame.h))
    return frame
end

-- Get active window
local function activeWindow()
    return window.focusedWindow() or window.frontmostWindow()
end

-- Size steps and labels
local sizeSteps = {1, 2/3, 1/2, 1/3, 1/6}
local sizeChars = {"1", "⅔", "½", "⅓", "⅙"}

-- Find nearest step index
local function findStepIndex(val)
    local bestIdx, bestDiff
    for i, s in ipairs(sizeSteps) do
        local diff = math.abs(s - val)
        if not bestDiff or diff < bestDiff then
            bestDiff, bestIdx = diff, i
        end
    end
    return bestIdx or 1
end

-- Initialize or retrieve window state
local function ensureWindowState(win)
    local id = win:id()
    if not windowStates[id] then
        local f = win:frame()
        local sf = win:screen():frame()
        local u = toUnitRect(f, sf)
        windowStates[id] = {
            originalUnit = u,
            lastUnit     = u,
            lastDir      = "5",
            idxW         = findStepIndex(u.w),
            idxH         = findStepIndex(u.h),
            screenID     = win:screen():id(),
        }
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

-- Compute position by direction
local function getPositionByDir(dir, wf, hf)
    local map = {
        ["1"] = {0,       1 - hf},
        ["2"] = {(1 - wf)/2, 1 - hf},
        ["3"] = {1 - wf,  1 - hf},
        ["4"] = {0,       (1 - hf)/2},
        ["5"] = {(1 - wf)/2, (1 - hf)/2},
        ["6"] = {1 - wf,  (1 - hf)/2},
        ["7"] = {0,       0},
        ["8"] = {(1 - wf)/2, 0},
        ["9"] = {1 - wf,  0},
    }
    return table.unpack(map[dir] or map["5"])
end

-- Move across displays with clamp
local function moveToDisplay(offset, sym)
    local w = activeWindow() if not w then return end
    local f = w:frame()
    local sf = w:screen():frame()
    local unit = toUnitRect(f, sf)
    local scr = screen.allScreens()
    local idx = fnutils.indexOf(scr, w:screen())
    local tgt = scr[(idx - 1 + offset) % #scr + 1]
    w:moveToScreen(tgt)
    w:moveToUnit(unit, 0)
    local f2 = w:frame()
    local uf = tgt:frame()
    w:setFrame(clampFrame(f2, uf), 0)
    local st = ensureWindowState(w)
    st.lastUnit = toUnitRect(w:frame(), uf)
    toast.showToast(sym)
end
bindHotkey(MOVE_MODS, PAD_DIV, function() moveToDisplay(-1, "←") end)
bindHotkey(MOVE_MODS, PAD_MUL, function() moveToDisplay(1,  "→") end)

-- Directional move and center with clamp
local dirArrows = {
    ["1"] = "↙", ["2"] = "↓", ["3"] = "↘",
    ["4"] = "←", ["5"] = "Centre", ["6"] = "→",
    ["7"] = "↖", ["8"] = "↑", ["9"] = "↗",
}
local function moveWindow(dir)
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    st.lastDir = dir
    local u = st.lastUnit
    local unit
    if dir == "5" then
        unit = { x=(1-u.w)/2, y=(1-u.h)/2, w=u.w, h=u.h }
    else
        local x, y = getPositionByDir(dir, u.w, u.h)
        unit = { x=x, y=y, w=u.w, h=u.h }
    end
    w:moveToUnit(unit, 0)
    toast.showToast(dirArrows[dir])
    local f2 = w:frame()
    local uf = w:screen():usableFrame() -- or :frame()
    w:setFrame(clampFrame(f2, uf), 0)
    local sf2 = w:screen():frame()
    st.lastUnit = toUnitRect(w:frame(), sf2)
end
for dir, key in pairs({
    ["1"]=PAD1, ["2"]=PAD2, ["3"]=PAD3,
    ["4"]=PAD4, ["5"]=PAD5, ["6"]=PAD6,
    ["7"]=PAD7, ["8"]=PAD8, ["9"]=PAD9,
}) do
    bindHotkey(MOVE_MODS, key, function() moveWindow(dir) end)
end

-- Restore original size
bindHotkey(SIZE_MODS, PAD_DOT, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    w:moveToUnit(st.originalUnit, 0)
    toast.showToast("Restore")
    st.lastUnit = st.originalUnit
end)

-- Fullscreen
bindHotkey(SIZE_MODS, PAD_ENTER, function()
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)
    local unit = { x=0, y=0, w=1, h=1 }
    w:moveToUnit(unit, 0)
    toast.showToast("Fullscreen")
    st.lastUnit = unit
end)

-- Size adjust: cmd+shift + (2·4·6·8)
local function sizeAdjust(dir)
    local w = activeWindow() if not w then return end
    local st = ensureWindowState(w)

    -- if window is centered and key is 5, shrink both axes
    if dir == "5" and st.lastDir == "5" then
        st.idxW = st.idxW or findStepIndex(st.lastUnit.w)
        st.idxH = st.idxH or findStepIndex(st.lastUnit.h)
        -- shrink both
        local newW = math.min(#sizeSteps, st.idxW + 1)
        local newH = math.min(#sizeSteps, st.idxH + 1)
        local wf, hf = sizeSteps[newW], sizeSteps[newH]
        local x, y   = getPositionByDir(st.lastDir, wf, hf)
        local unit   = { x = x, y = y, w = wf, h = hf }
        w:moveToUnit(unit, 0)
        toast.showToast(sizeChars[newW].."×"..sizeChars[newH])
        -- clamp
        local f2 = w:frame()
        local sf = w:screen():frame()
        w:setFrame(clampFrame(f2, sf), 0)
        -- update state
        st.lastUnit, st.idxW, st.idxH = toUnitRect(w:frame(), sf), newW, newH
        return
    end

    -- use lastDir to decide which edges it's "touching"
    local d = st.lastDir
    local top    = (d=="7" or d=="8" or d=="9")
    local bottom = (d=="1" or d=="2" or d=="3")
    local left   = (d=="1" or d=="4" or d=="7")
    local right  = (d=="3" or d=="6" or d=="9")

    -- build allowed mappings
    local vMap, hMap = {}, {}
    if top then
        vMap["2"], vMap["8"] = "enlarge", "shrink"
    end
    if bottom then
        vMap["8"], vMap["2"] = "enlarge", "shrink"
    end
    if left then
        hMap["6"], hMap["4"] = "enlarge", "shrink"
    end
    if right then
        hMap["4"], hMap["6"] = "enlarge", "shrink"
    end
    if not left and not right then
        hMap["4"], hMap["6"], hMap["5"] = "enlarge", "enlarge", "shrink"
    end
    if not top and not bottom then
        vMap["8"], vMap["2"], vMap["5"] = "enlarge", "enlarge", "shrink"
    end

    -- current step indices
    local curW = st.idxW or findStepIndex(st.lastUnit.w)
    local curH = st.idxH or findStepIndex(st.lastUnit.h)

    -- pick action for this key
    local actionW = hMap[dir]
    local actionH = vMap[dir]

    -- compute new indices
    local function adj(idx, act)
        if act=="enlarge" then return math.max(1, idx-1)
        elseif act=="shrink" then return math.min(#sizeSteps, idx+1)
        else return idx end
    end
    local newW = adj(curW, actionW)
    local newH = adj(curH, actionH)

    -- apply new size
    local wf, hf = sizeSteps[newW], sizeSteps[newH]
    local x, y    = getPositionByDir(st.lastDir, wf, hf)
    w:moveToUnit({ x=x, y=y, w=wf, h=hf }, 0)
    toast.showToast(sizeChars[newW] .. "×" .. sizeChars[newH])

    -- clamp within screen frame
    local f2 = w:frame()
    local sf = w:screen():frame()
    w:setFrame(clampFrame(f2, sf), 0)

    -- update state
    st.lastUnit = toUnitRect(w:frame(), sf)
    st.idxW, st.idxH = newW, newH
end
for dir, key in pairs({["1"]=PAD1,["2"]=PAD2,["3"]=PAD3,["4"]=PAD4,["5"]=PAD5,["6"]=PAD6,["7"]=PAD7,["8"]=PAD8,["9"]=PAD9}) do
    bindHotkey(SIZE_MODS, key, function() sizeAdjust(dir) end)
end