--------------------------------------------------------------------
-- Import modules
--------------------------------------------------------------------
local hotkey     = hs.hotkey
hotkey.setLogLevel('warning')
local timer      = hs.timer
local eventtap   = hs.eventtap
local screen     = hs.screen
local canvas     = hs.canvas
local pasteboard = hs.pasteboard
local fs         = require("hs.fs")
local image      = hs.image
local ax         = require("hs.axuielement")

--------------------------------------------------------------------
-- Ensure screenshot directory exists
-- Set editorApp to Preview for image editing
--------------------------------------------------------------------
local screenshotDir = os.getenv("HOME") .. "/Documents/screenshots"
fs.mkdir(screenshotDir)

local editorApp = "Shottr"

--------------------------------------------------------------------
-- Internal state
--------------------------------------------------------------------
local lastCaptureArgs = nil
local RunCapture	  = false
local captureTask     = nil
local previewCanvas   = nil
local lastImage       = nil
local previewCanvas = nil

--------------------------------------------------------------------
-- Helper functions
--------------------------------------------------------------------
local function nowTimestamp()
	return os.date("%Y%m%d%H%M%S")
end

local function generateFilename()
	return string.format("%s.png", nowTimestamp())
end

local function saveImageFull(img)
	local fname = generateFilename()
	local path  = screenshotDir .. "/" .. fname
	img:saveToFile(path)
	return fname
end

--------------------------------------------------------------------
-- Preview display
--------------------------------------------------------------------
local function showPreview(img)
	if not img then
		toast.showToast("⚠️ No captured image", 0.5)
		return
	end
	if previewCanvas then
		previewCanvas:delete()
	end
    
    -- build all layers as canvas elements
    local elements = {}
	local sz              = img:size()
	local maxSize         = 1200
	local scale           = math.min(1, maxSize / math.max(sz.w, sz.h))
	local w, h            = sz.w * scale, sz.h * scale
	local fr              = screen.primaryScreen():frame()
	local x, y            = fr.x + (fr.w - w) / 2, fr.y + (fr.h - h) / 2
    local maxShadowOffset = 8
    local minReflOffset   = -1
    local frame           = { x=x+minReflOffset, y=y+minReflOffset, w=w+maxShadowOffset-minReflOffset, h=h+maxShadowOffset-minReflOffset }
    local x0, y0          = -minReflOffset, -minReflOffset
    local cornerRadius    = 12
    
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
            roundedRectRadii = { xRadius = cornerRadius, yRadius = cornerRadius },
            frame             = { x=x0+i*shadowOffsetStep, y=y0+i*shadowOffsetStep, w=w, h=h }
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
            roundedRectRadii = { xRadius = cornerRadius, yRadius = cornerRadius },
            frame             = { x=x0+i*refOffsetStep, y=y0+i*refOffsetStep, w=w, h=h }
        })
    end
    
	table.insert(elements, {
        type             = "rectangle",
        action           = "clip",
        frame            = { x=x0, y=y0, w=w, h =h },
        roundedRectRadii = { xRadius = cornerRadius, yRadius = cornerRadius }
    })

	table.insert(elements, {
        type         = "image",
        image        = img,
        imageScaling = "scaleToFit",
        frame        = { x=x0, y=y0, w=w, h =h }
    })
    
    previewCanvas = canvas.new(frame)
    previewCanvas:appendElements(elements)
	previewCanvas:level(canvas.windowLevels.overlay)
	previewCanvas:behavior({ "canJoinAllSpaces", "stationary" })
	previewCanvas:show()
    lastImage = img
end

--------------------------------------------------------------------
-- hidePreview: animate fade-out then delete canvas
--------------------------------------------------------------------
local function hidePreview()
    if not previewCanvas then return end

    local fadeTime = 0.2
    local step     = 0.01
    local steps    = math.floor(fadeTime / step)
    local count    = 0
    -- create a one-off fade timer
    local fadeTimer = nil
    fadeTimer = timer.doEvery(step, function()
        count = count + 1
        local alpha = 1 - (count / steps)
        previewCanvas:alpha(alpha)
        if count >= steps then
            fadeTimer:stop()
            previewCanvas:delete()
            previewCanvas = nil
            lastImage     = nil   
        end
    end)
end

--------------------------------------------------------------------
-- helpers to stop any pending capture / click-watcher
--------------------------------------------------------------------
local function stopScreencapture()
    if captureTask then
        captureTask:terminate()
        captureTask = nil
    end
    RunCapture = false
end

local function stopClickWatcher()
    if _G.clickWatcher then
        _G.clickWatcher:stop()
        _G.clickWatcher = nil
    end
end

local function stopAllCapture()
    stopScreencapture()   -- kills screencapture process, resets flags
    stopClickWatcher()    -- kills window-click watcher
end

--------------------------------------------------------------------
-- Preview keybindings (c / s / a / e / Esc)
--------------------------------------------------------------------
_G.keyAfterCapturePreview = eventtap.new(
    { eventtap.event.types.keyDown },
    function(e)
        if not previewCanvas then return false end

        local flags = e:getFlags()
        local kc = e:getKeyCode()

        -- cmd + c: copy
        if kc == hs.keycodes.map.c and flags.cmd and lastImage then
            pasteboard.clearContents()
            pasteboard.writeObjects({ lastImage })
            toast.showToast("📋 Copied", 0.5)
            hidePreview()
            stopScreencapture()
            return true
        end

        -- cmd + s: save
        if kc == hs.keycodes.map.s and flags.cmd and lastImage then
            local fname = saveImageFull(lastImage)
            toast.showToast("📁 Saved as " .. fname, 0.5)
            hs.execute('open "'..screenshotDir..'"')
            hidePreview()
            stopScreencapture()
            return true
        end

        -- cmd + a: copy + save
        if kc == hs.keycodes.map.a and flags.cmd and lastImage then
            pasteboard.clearContents()
            pasteboard.writeObjects({ lastImage })
            local fname = saveImageFull(lastImage)
            toast.showToast("📋 Copied & 📁 Saved as " .. fname, 0.5)
            hs.execute('open "'..screenshotDir..'"')
            hidePreview()
            stopScreencapture()
            return true
        end

        -- cmd + e: save + open in Preview
        if kc == hs.keycodes.map.e and flags.cmd and lastImage then
            local fname = saveImageFull(lastImage)
            local fullpath = screenshotDir .. "/" .. fname
            toast.showToast("✏️ Open in " .. editorApp, 0.5)
            hs.execute(string.format('open -a "%s" "%s"', editorApp, fullpath))
            hidePreview()
            stopScreencapture()
            return true
        end

        -- Esc: just dismiss
        if kc == hs.keycodes.map.escape then
            toast.showToast("🗑️ Preview deleted", 0.5)
            hidePreview()
            stopScreencapture()
            return true
        end

        return false
    end
)
_G.keyAfterCapturePreview:start()

--------------------------------------------------------------------
-- Core capture function (show preview immediately)
--------------------------------------------------------------------
local function runScreencapture(args)
    lastCaptureArgs = args
    RunCapture      = true

    local pos = hs.mouse.absolutePosition()
    hs.mouse.setAbsolutePosition({ x = pos.x + 1, y = pos.y })
    hs.timer.usleep(10000)
    hs.mouse.setAbsolutePosition(pos)

	local tmp = screenshotDir .. "/capture_tmp.png"
	local cmd = string.format('screencapture %s -x "%s"', args, tmp)

    captureTask = hs.task.new("/bin/sh", function()
        if fs.attributes(tmp) then
            local img = image.imageFromPath(tmp)
            os.remove(tmp)
            if img then
                showPreview(img)
				toast.showToast("✅ Capture done", 0.5)
            else
                toast.showToast("❎ Capture failed", 0.5)
            end
        end
        stopScreencapture()
    end, { "-c", cmd })
	
	captureTask:start()
end

--------------------------------------------------------------------
-- RunCapture keybindings (r: recapture, Esc: cancel before snapshot)
--------------------------------------------------------------------
_G.keyWhileRunCapture = eventtap.new(
    { eventtap.event.types.keyDown },
    function(e)
        if not RunCapture then return false end

        local kc = e:getKeyCode()

        -- r: trigger recapture immediately
        if kc == hs.keycodes.map.r and lastCaptureArgs == "-i" then
            toast.showToast("🔄 Capture restarted", 0.5)
            stopAllCapture()
			runScreencapture(lastCaptureArgs)
            return true
        end

        -- Esc: cancel this pending capture
        if kc == hs.keycodes.map.escape then
            toast.showToast("⛔️ Capture cancelled", 0.5)
			stopAllCapture()
            return false
        end

        return false
    end
)
_G.keyWhileRunCapture:start()

--------------------------------------------------------------------
-- Hotkey bindings
--------------------------------------------------------------------
hotkey.bind({ "cmd"}, "f1", function()
	-- if there's already a pending task, kill it first
    if captureTask then
        stopAllCapture()
    end
	toast.showToast("↖️ Drag to capture...", 0.5)
	runScreencapture("-i")
end)

-- --------------------------------------------------------------------
-- -- Scroll-shot  ⌘⌃F13
-- --------------------------------------------------------------------
-- local function captureScroll(win, contentH, step, delay)
--     step  = step  or 400
--     delay = (delay or 100) / 1000  -- ms ➜ 초

--     local pieces, w = {}, win:frame().w
--     hs.mouse.setAbsolutePosition(win:frame().center) -- 커서 이동
--     win:focus(); hs.timer.usleep(40000)              -- 포커스 & 40 ms 대기

--     for y = 0, contentH - 1, step do
--         table.insert(pieces, win:snapshot())
--         hs.eventtap.scrollWheel({0,-step}, {}, 'pixel')
--         hs.timer.usleep(delay * 1e6)
--     end

--     local totalH = #pieces * step
--     local cv = hs.canvas.new{ x = 0, y = 0, w = w, h = totalH }

--     for i,img in ipairs(pieces) do
--         cv:appendElements({
--             type  = 'image',
--             image = img,
--             frame = { x = 0, y = (i-1)*step, w = w, h = step }
--         })
--     end

--     local out = cv:snapshot()  -- 한 장으로 합친다
--     cv:delete()
--     return out
-- end

-- hotkey.bind({ "cmd"}, "f5", function()
--     local win = hs.window.frontmostWindow()
--     if not win then hs.alert.show('⚠️ No window'); return end

--     -- 일단 하드코딩 ➜ 동작 확인 후 prompt 로 변경
--     local H = 3000                     -- 총 스크롤 높이(px)
--     local img = captureScroll(win, H)

--     if img then
--         showPreview(img)
--         toast.showToast('✅ Scroll captured', 0.7)
--     else
--         toast.showToast('❌ Capture failed', 0.7)
--     end
-- end)

hotkey.bind({ "cmd"}, "f2", function()
    -- if there's already a pending task, kill it first
    if captureTask then
        stopAllCapture()
    end
    toast.showToast("☑️ Click any window to capture...", 0.5)

    _G.clickWatcher = eventtap.new(
        { eventtap.event.types.leftMouseDown, eventtap.event.types.keyDown },
        function(e)
            if e:getType() == eventtap.event.types.keyDown
            and  e:getKeyCode() == 53 then
                toast.showToast("⛔️ Capture cancelled", 0.5)
				_G.clickWatcher:stop()
				_G.clickWatcher = nil
                return true
            end

            if e:getType() == eventtap.event.types.leftMouseDown then
                local pt   = hs.mouse.absolutePosition()
                local sys  = ax.systemWideElement()
                local elem = sys:elementAtPosition(pt.x, pt.y)
                local wElem  = elem and elem:attributeValue("AXWindow")
                local hsWin  = wElem and wElem:asHSWindow()

                if hsWin then
                    local img = hsWin:snapshot()
                    showPreview(img)
                else
                    toast.showToast("⚠️ No window here", 0.5)
                end

				_G.clickWatcher:stop()
				_G.clickWatcher = nil
                return true
            end

            return false
        end
    )

    clickWatcher:start()
end)

hotkey.bind({ "cmd"}, "f3", function()
    -- if there's already a pending task, kill it first
    if captureTask then
        stopAllCapture()
    end
	local fr     = screen.primaryScreen():fullFrame()
	local region = string.format("-R%d,%d,%d,%d", fr.x, fr.y, fr.w, fr.h)
	runScreencapture(region)
end)

hotkey.bind({ "cmd"}, "f4", function()
    -- if there's already a pending task, kill it first
    if captureTask then
        stopAllCapture()
    end
	runScreencapture("")
end)