local M = {}

function M.saveDesktopLayout(filePath)
  local layout = {}
  for _, win in ipairs(hs.window.visibleWindows()) do
    local app = win:application():bundleID()
    local title = win:title()
    local frame = win:frame()
    local space = hs.spaces.windowSpaces(win)[1]
    table.insert(layout, {
      app     = app,
      title   = title,
      frame   = {x=frame.x,y=frame.y,w=frame.w,h=frame.h},
      spaceID = space,
    })
  end
  hs.json.writeToFile(layout, filePath or "~/.hammerspoon/desktopLayout.json")
end

function M.restoreDesktopLayout(filePath)
  local path = filePath or "~/.hammerspoon/desktopLayout.json"
  local layout = hs.json.readFromFile(path)
  for _, item in ipairs(layout) do
    hs.application.launchOrFocusByBundleID(item.app)
    hs.timer.waitUntil(
      function() 
        local wins = hs.window.filter.new(false):getWindows()
        for _, w in ipairs(wins) do
          if w:application():bundleID()==item.app and w:title()==item.title then return w end
        end
        return false
      end,
      function(win)
        -- move to correct space
        hs.spaces.moveWindowToSpace(win, item.spaceID)
        -- restore frame
        win:setFrame(item.frame, 0)
      end,
      0.1, 30
    )
  end
end

M._watcher = hs.caffeinate.watcher.new(function(evt)
  if evt == hs.caffeinate.watcher.systemWillPowerOff then
    M.saveDesktopLayout()
  end
end):start()

return M