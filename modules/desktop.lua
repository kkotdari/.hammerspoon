local application = hs.application
local window      = hs.window
local spaces      = hs.spaces
local timer       = hs.timer
local json        = hs.json
local wfilter     = hs.window.filter

local M = {}

local layoutFile = hs.configdir .. "/desktopLayout.json"

function M.saveDesktopLayout(filePath)
  local path   = filePath or layoutFile
  local layout = {}
  for _, win in ipairs(window.visibleWindows()) do
    local f = win:frame()
    layout[#layout+1] = {
      app     = win:application():bundleID(),
      title   = win:title(),
      frame   = { x = f.x, y = f.y, w = f.w, h = f.h },
      spaceID = spaces.windowSpaces(win)[1],
    }
  end

  local encoded = json.encode(layout)
  local fh, err = io.open(path, "w")
  if not fh then
    print("desktop > failed to open file for write:", err)
    return
  end
  fh:write(encoded)
  fh:close()
  toast.showToast("스페이스 구성 업데이트 완료", 2.0)
end

function M.restoreDesktopLayout(filePath)
  local path = filePath or layoutFile
  local fh, err = io.open(path, "r")
  if not fh then
    toast.showToast("스페이스 구성 없음", 2.0)
    return
  end
  local raw = fh:read("*a")
  fh:close()
  local ok, layout = pcall(json.decode, raw)
  if not ok or type(layout) ~= "table" or #layout == 0 then
    toast.showToast("스페이스 구성 없음", 2.0)
    return
  end

  -- 1) 필요 앱 번들ID 수집
  local neededApps = {}
  for _, item in ipairs(layout) do
    neededApps[item.app] = true
  end
  -- 2) 현재 열린 윈도우에서 존재하는 앱 건너뛰기
  for _, w in ipairs(wfilter.new(false):getWindows()) do
    neededApps[w:application():bundleID()] = nil
  end
  -- 3) 남은 앱만 실행
  for app, _ in pairs(neededApps) do
    application.launchOrFocusByBundleID(app)
  end

  local total = #layout
  local done  = 0

  local function finishOne()
    done = done + 1
    if done == total then
      toast.showToast("스페이스 구성 복구 완료", 2.0)
    end
  end

  for _, item in ipairs(layout) do
    -- 바로 복원 시도
    local restored = false
    for _, w in ipairs(wfilter.new(false):getWindows()) do
      if w:application():bundleID() == item.app
      and  w:title()               == item.title
      then
        spaces.moveWindowToSpace(w, item.spaceID)
        w:setFrame(item.frame, 0)
        restored = true
        finishOne()
        break
      end
    end

    if not restored then
      -- 창이 뜰 때까지 기다렸다가 복원
      timer.waitUntil(
        function()
          for _, w in ipairs(wfilter.new(false):getWindows()) do
            if w:application():bundleID() == item.app
            and  w:title()               == item.title
            then return true end
          end
          return false
        end,
        function()
          for _, w in ipairs(wfilter.new(false):getWindows()) do
            if w:application():bundleID() == item.app
            and  w:title()               == item.title
            then
              spaces.moveWindowToSpace(w, item.spaceID)
              w:setFrame(item.frame, 0)
              break
            end
          end
          finishOne()
        end,
        0.1, 30
      )
    end
  end
end

local wf = wfilter.new()
wf:subscribe({
    wfilter.windowCreated,
    wfilter.windowDestroyed,
    wfilter.windowMoved,
    wfilter.windowResized
  },
  function()
    print("desktop > layout change detected")
    M.saveDesktopLayout()
  end
)

return M