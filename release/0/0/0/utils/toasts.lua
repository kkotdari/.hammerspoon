local canvas   = hs.canvas
local drawing  = hs.drawing
local timer    = hs.timer
local screen   = hs.screen
local geometry = hs.geometry

--------------------------------------------------------------------
-- Active toasts store (each with its own objects & timers)
--------------------------------------------------------------------
local activeToasts = {}

--------------------------------------------------------------------
-- A single global queue and a flag to track animation in progress
--------------------------------------------------------------------
local pushQueue   = {}
local isAnimating = false

--------------------------------------------------------------------
-- settings
--------------------------------------------------------------------
local fontName = 
    "Apple SD 산돌고딕 Neo"
    -- "D2Coding"
    -- "Helvetica"
    -- "NanumGothic"

--------------------------------------------------------------------
-- getMaxPtToPx(px, message)
--   Returns largest pt size so text height ≤ px
--------------------------------------------------------------------
local function getMaxPtToPx(px, message)
    local maxPt, minPt = 40, 4
    for size = maxPt, minPt, -1 do
        local ts = drawing.getTextDrawingSize(message, { font = fontName, size = size })
        if ts.h <= px then return size end
    end
    return minPt
end

--------------------------------------------------------------------
-- drawToast(message, duration)
--   Creates and shows a single toast; returns its entry
--------------------------------------------------------------------
local function drawToast(message, duration)
    local entry = { objects = {} }
    
    local holdTime    = duration or 0.5
    local fadeTime    = 0.2
    local fixedHeight = 50
    local paddingH    = 24
    local paddingV    = 18
    local maxTextW    = 2000
    
    -- font sizing
    local usableH     = fixedHeight - paddingV*2
    local maxPt       = getMaxPtToPx(usableH, message)
    local sizeMax     = drawing.getTextDrawingSize(message, { font = fontName, size = maxPt })
    local fontSize    = maxPt
    if sizeMax.w > maxTextW then
        local scaleW = maxTextW / sizeMax.w
        fontSize     = math.floor(sizeMax.h * scaleW)
    end
    local sizeFinal   = drawing.getTextDrawingSize(message, { font = fontName, size = fontSize })
    
    -- bg dimensions
    local textW, textH = sizeFinal.w, sizeFinal.h
    local bgW, bgH     = textW + paddingH*2, fixedHeight
    local sf           = screen.primaryScreen():fullFrame()
    local x            = sf.w/2 - bgW/2
    local y            = sf.h*2/3 + bgH/2
    
    -- outer frame
    local maxShadowOffset = 8
    local minReflOffset   = -1
    local outerFrame      = { x=x+minReflOffset, y=y+minReflOffset, w=bgW+maxShadowOffset-minReflOffset, h=bgH+maxShadowOffset-minReflOffset }
    local x0, y0          = -minReflOffset, -minReflOffset
    local cornerRadius    = 12
    
    -- build all layers as canvas elements
    local elements = {}
    
    -- shadows
    local shadowOffsetStep = 0.5
    local shadowBaseAlpha  = 0.08
    local shadowAlphaLevels = math.floor(maxShadowOffset / shadowOffsetStep)
    if shadowAlphaLevels < 1 then
        shadowAlphaLevels = 1
    end
    local shadowAlphaStep  = shadowBaseAlpha / shadowAlphaLevels
    for i = 1, shadowAlphaLevels, 1 do
        local a = shadowBaseAlpha - (i-1)*shadowAlphaStep
        table.insert(elements, {
            type              = "rectangle",
            action            = "fill",
            fillColor         = { red=0, green=0, blue=0, alpha=a },
            roundedRectRadii  = { xRadius = cornerRadius, yRadius = cornerRadius },
            frame             = { x=x0+i*shadowOffsetStep, y=y0+i*shadowOffsetStep, w=bgW, h=bgH }
        })
    end
    
    -- reflections
    local refOffsetStep  = -0.5
    local reflBaseAlpha  = 0.08
    local reflAlphaLevels = math.floor(minReflOffset / refOffsetStep)
    if reflAlphaLevels < 1 then
        reflAlphaLevels = 1
    end
    local reflAlphaStep  = reflBaseAlpha / reflAlphaLevels
    for i = 1, reflAlphaLevels, 1 do
        local a = reflBaseAlpha - (i-1)*reflAlphaStep
        table.insert(elements, {
            type              = "rectangle",
            action            = "fill",
            fillColor         = { red=0, green=0, blue=0, alpha=a },
            roundedRectRadii  = { xRadius = cornerRadius, yRadius = cornerRadius },
            frame             = { x=x0+i*refOffsetStep, y=y0+i*refOffsetStep, w=bgW, h=bgH }
        })
    end
    
    -- white background
    table.insert(elements, {
        type              = "rectangle",
        action            = "fill",
        fillColor         = { red=1, green=1, blue=1, alpha=1 },
        roundedRectRadii  = { xRadius = cornerRadius, yRadius = cornerRadius },
        frame             = { x=x0, y=y0, w=bgW, h=bgH }
    })
    
    -- text
    table.insert(elements, {
        type          = "text",
        text          = message,
        textFont      = fontName,
        textSize      = fontSize,
        textColor     = { red=0, green=0, blue=0, alpha=1 },
        textAlignment = "center",
        frame         = { x=x0, y=y0+paddingV, w=bgW, h=bgH }
    })
    
    -- create and show the canvas
    local toastCanvas = canvas.new(outerFrame)
    toastCanvas:appendElements(elements)
    toastCanvas:level(canvas.windowLevels.overlay + 1)
    toastCanvas:behavior({ "canJoinAllSpaces", "stationary" })
    toastCanvas:show()

    entry.toastCanvas = toastCanvas

    -- hold then fade-out the toast bg, fade-in the menubar text
    entry.holdTimer = timer.doAfter(holdTime, function()
        local tC = entry.toastCanvas

        local step  = 0.01
        local steps = math.floor(fadeTime / step)
        local cnt   = 0
        
        entry.fadeTimer = timer.doEvery(step, function()
            cnt = cnt + 1
            local tA = 1 - (cnt/steps)
            local mA =     (cnt/steps)
            tC:alpha(tA)

            if cnt >= steps then
                entry.fadeTimer:stop()
                for i, e in ipairs(activeToasts) do
                    if e == entry then
                        table.remove(activeToasts, i)
                        break
                    end
                end
            end
        end)
    end)

    return entry
end

--------------------------------------------------------------------------------
-- Runs the next toast push if not already animating
--------------------------------------------------------------------------------
local function processQueue()
  if isAnimating or #pushQueue == 0 then
    return
  end

  isAnimating = true
  local entry = table.remove(pushQueue, 1)

  local shiftY   = 50 + 8
  local pushTime = 0.2
  local stepTime = 0.01
  local steps    = math.floor(pushTime / stepTime)
  local deltaY   = shiftY / steps
  local count    = 0

  -- Animate existing toasts upward
  local timerRef
  timerRef = timer.doEvery(stepTime, function()
    count = count + 1
    print("[DEBUG] count:", count)
    print("[DEBUG] activeToasts size:", #activeToasts)

    for _, e in ipairs(activeToasts) do
      local c = e.toastCanvas
      if c and type(c.frame) == "function" then
        local f = c:frame()
        c:frame{ x = f.x, y = f.y + deltaY, w = f.w, h = f.h }
      end
    end

    if count >= steps or #activeToasts == 0 then
      timerRef:stop()
      -- Draw the new toast
      local toastEntry = drawToast(entry.message, entry.duration)
      table.insert(activeToasts, toastEntry)
      -- Mark free and process next
      isAnimating = false
      processQueue()
    end
  end)
end

--------------------------------------------------------------------------------
-- pushToast helper
--   Simply enqueue and kick off processQueue
--------------------------------------------------------------------------------
local function pushToast(message, duration)
  table.insert(pushQueue, { message = message, duration = duration })
  processQueue()
end

--------------------------------------------------------------------
-- showToast(message[, duration])
--   1) kick off push-animation in parallel
--   2) draw & track the new toast immediately
--------------------------------------------------------------------
local function showToast(message, duration)
    -- start pushing old toasts upward, non-blocking
    local pushEntry = pushToast(message, duration)
    table.insert(pushQueue, pushEntry)
end

return {
    showToast = showToast
}