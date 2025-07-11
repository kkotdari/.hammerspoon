local hotkey, window, screen, fnutils, wfilter =
      hs.hotkey, hs.window, hs.screen, hs.fnutils, hs.window.filter

hs.window.animationDuration = 0

-- keypad keycodes
local PAD_PLUS, PAD_MINUS = 69, 78
local PAD1, PAD2, PAD3    = 83, 84, 85
local PAD4, PAD5, PAD6    = 86, 87, 88
local PAD7, PAD8, PAD9    = 89, 91, 92
local PAD_DIV, PAD_MUL    = 75, 67
local PAD_DOT, PAD_ENTER  = 65, "padenter"
local MODS                = { "cmd", "ctrl" }

----------------------------------------------------------------------
-- ignore-depth guard (중첩 보호)
----------------------------------------------------------------------
local ignoreDepth = 0
local function beginIgnore() ignoreDepth = ignoreDepth + 1 end
local function endIgnore()   ignoreDepth = math.max(0, ignoreDepth - 1) end
local function ignoring()    return ignoreDepth > 0 end
local function atomic(fn)    beginIgnore(); fn(); endIgnore() end

----------------------------------------------------------------------
-- per-window store
----------------------------------------------------------------------
local windowStates = {}

local function activeWindow()
    return window.focusedWindow() or window.frontmostWindow()
end

local function unitFromUsableFrame(win)
    local f, sf = win:frame(), win:screen():frame()
    return { x=(f.x-sf.x)/sf.w, y=(f.y-sf.y)/sf.h, w=f.w/sf.w, h=f.h/sf.h }
end

local function ensureWindowState(win)
    local id = win:id()
    if not windowStates[id] then
        local u = unitFromUsableFrame(win)
        windowStates[id] = {
            originalUnit = u,
            relPos       = { x=u.x, y=u.y },
            rateW        = u.w,
            rateH        = u.h,
            resizeIndex  = 1,
            screenID     = win:screen():id(),
        }
    end
    return windowStates[id]
end

----------------------------------------------------------------------
-- manual move sync (스크린 변경 시 무시)
----------------------------------------------------------------------
local wf = wfilter.new(true):setDefaultFilter()
wf:subscribe(wfilter.windowMoved, function(win)
    if ignoring() then return end
    local st = windowStates[win:id()] if not st then return end
    if win:screen():id() ~= st.screenID then return end -- skip cross-display
    local u = unitFromUsableFrame(win)
    st.relPos  = { x=u.x, y=u.y }
    st.rateW, st.rateH = u.w, u.h
end)

----------------------------------------------------------------------
-- apply store
----------------------------------------------------------------------
local function applyStored(win)
    local st = ensureWindowState(win)
    local sf = win:screen():frame()
    local frame = {
        x = sf.x + st.relPos.x * sf.w,
        y = sf.y + st.relPos.y * sf.h,
        w = st.rateW * sf.w,
        h = st.rateH * sf.h,
    }
    beginIgnore()
    win:setFrame(frame, 0)
    hs.timer.doAfter(0, endIgnore)
end

----------------------------------------------------------------------
-- key binding helper
----------------------------------------------------------------------
local function bind(mods, key, fn)
    hotkey.new(mods, key, function() atomic(fn) end):enable()
end

----------------------------------------------------------------------
-- size presets (area-based)
----------------------------------------------------------------------
local resizeStates = {
    {1,1}, {1.5,1}, {2,1}, {3,1}, {2,2}, {3,2}
}
local ratioChars   = { "1", "⅔", "½", "⅓", "¼", "⅙" }
local function area(idx) local a,b=table.unpack(resizeStates[idx]); return 1/(a*b) end
local function nearest(cur, bigger)
    local bestDiff, best = nil, nil
    for i=1,#resizeStates do
        local ar = area(i)
        if (bigger and ar>cur) or (not bigger and ar<cur) then
            local d = math.abs(ar-cur)
            if not bestDiff or d<bestDiff then bestDiff,best=d,i end
        end
    end
    return best
end

-- shrink
bind(MODS, PAD_MINUS, function()
    local w=activeWindow() if not w then return end
    local st=ensureWindowState(w)
    local idx=nearest(st.rateW*st.rateH, false)
    if not idx then toast.showToast("Min") return end
    st.resizeIndex=idx
    local a,b=table.unpack(resizeStates[idx])
    st.rateW,st.rateH=1/a,1/b
    st.relPos={ x=(1-st.rateW)/2, y=(1-st.rateH)/2 }
    toast.showToast(ratioChars[idx]); applyStored(w)
end)

-- enlarge
bind(MODS, PAD_PLUS, function()
    local w=activeWindow() if not w then return end
    local st=ensureWindowState(w)
    local idx=nearest(st.rateW*st.rateH, true)
    if not idx then toast.showToast("Max") return end
    st.resizeIndex=idx
    local a,b=table.unpack(resizeStates[idx])
    st.rateW,st.rateH=1/a,1/b
    st.relPos={ x=(1-st.rateW)/2, y=(1-st.rateH)/2 }
    toast.showToast(ratioChars[idx]); applyStored(w)
end)

----------------------------------------------------------------------
-- quick center / restore / fullscreen
----------------------------------------------------------------------
bind(MODS, PAD5, function()
    local w=activeWindow() if not w then return end
    local st=ensureWindowState(w)
    st.relPos={ x=(1-st.rateW)/2, y=(1-st.rateH)/2 }
    toast.showToast("Centered"); applyStored(w)
end)

bind(MODS, PAD_DOT, function()
    local w=activeWindow() if not w then return end
    local st=ensureWindowState(w); local u=st.originalUnit
    st.rateW,st.rateH=u.w,u.h; st.relPos={x=u.x,y=u.y}; st.resizeIndex=1
    toast.showToast("Restored"); applyStored(w)
end)

bind(MODS, PAD_ENTER, function()
    local w=activeWindow() if not w then return end
    local st=ensureWindowState(w)
    st.rateW,st.rateH=1,1; st.relPos={x=0,y=0}; st.resizeIndex=1
    toast.showToast("Fullscreen"); applyStored(w)
end)

----------------------------------------------------------------------
-- directional anchors
----------------------------------------------------------------------
local dirMap     = { ["1"]={0,1},["2"]={0.5,1},["3"]={1,1},["4"]={0,0.5},
                     ["6"]={1,0.5},["7"]={0,0},["8"]={0.5,0},["9"]={1,0} }
local dirArrows  = { [1]="↙",[2]="↓",[3]="↘",[4]="←",[6]="→",[7]="↖",[8]="↑",[9]="↗" }

for dir, key in pairs({ ["1"]=PAD1,["2"]=PAD2,["3"]=PAD3,["4"]=PAD4,
                         ["6"]=PAD6,["7"]=PAD7,["8"]=PAD8,["9"]=PAD9 }) do
    bind(MODS, key, function()
        local w=activeWindow() if not w then return end
        local st=ensureWindowState(w)
        local ux,uy=table.unpack(dirMap[dir])
        st.relPos={ x=ux*(1-st.rateW), y=uy*(1-st.rateH) }
        toast.showToast(dirArrows[tonumber(dir)]); applyStored(w)
    end)
end

----------------------------------------------------------------------
-- display move (▭←▭ / ▭→▭)
----------------------------------------------------------------------
local function moveToDisplay(offset, banner)
    atomic(function()
        local w=activeWindow() if not w then return end
        local st=ensureWindowState(w)
        local scrs=screen.allScreens(); local i=fnutils.indexOf(scrs, w:screen())
        local target=scrs[(i-1+offset)%#scrs+1]
        w:moveToScreen(target)
        st.screenID = target:id()
        applyStored(w)
    end)
    toast.showToast(banner)
end

bind(MODS, PAD_DIV, function() moveToDisplay(-1, "←←") end)
bind(MODS, PAD_MUL, function() moveToDisplay(1,  "→→") end)