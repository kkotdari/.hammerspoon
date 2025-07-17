-- modules/desktop.lua
local application = hs.application
local window      = hs.window
local screen      = hs.screen
local spaces      = hs.spaces
local timer       = hs.timer
local json        = hs.json
local hotkey      = hs.hotkey
local fnutils     = hs.fnutils

local M = {}

----------------------------------------------------------------
-- 설정
----------------------------------------------------------------
local layoutFile           = hs.configdir .. "/desktopLayout.json"
local SAVE_DWELL_SEC       = 0.35    -- 스페이스 전환 후 안정화 대기
local RESTORE_DWELL_SEC    = 0.60    -- 앱 기동/스페이스 전환 후 안정화
local KILL_APPS_ON_RESTORE = false   -- true 로 바꾸면 복원 전 앱 종료 시도

----------------------------------------------------------------
-- 유틸
----------------------------------------------------------------
local function screenUUID(scr)
  return scr and scr:getUUID() or "unknown"
end

local function spaceSequence()
  -- 반환: { {sid=spaceID, screen=scr, screenUUID=uuid, index=i}, ... } 정렬: 화면 순(좌->우), 인덱스 오름차순
  local seq = {}
  local screens = screen.allScreens()
  table.sort(screens, function(a, b) return a:frame().x < b:frame().x end)
  local all = spaces.allSpaces()
  for _, scr in ipairs(screens) do
    local uuid = screenUUID(scr)
    local list = all[uuid] or {}
    for i, sid in ipairs(list) do
      seq[#seq + 1] = { sid = sid, screen = scr, screenUUID = uuid, index = i }
    end
  end
  return seq
end

local function gotoSpaceBlocking(sid, dwellSec, cb)
  spaces.gotoSpace(sid)
  timer.doAfter(dwellSec or SAVE_DWELL_SEC, cb)
end

local function windowRecord(win)
  local f = win:frame()
  return {
    app   = (win:application() and win:application():bundleID()) or "",
    title = win:title() or "",
    frame = { x = f.x, y = f.y, w = f.w, h = f.h }
  }
end

----------------------------------------------------------------
-- 저장: 모든 스페이스를 돌며 창 수집
-- (파일 포맷 변경: { meta={active={scrUUID={spaceID=,spaceIndex=},...}}, spaces=[ ... ] })
----------------------------------------------------------------
function M.saveDesktopLayout(path)
  local target = path or layoutFile
  local seq = spaceSequence()
  local result = {}
  local i = 0

  -- 저장 시작 시 각 디스플레이별 활성 스페이스 기억
  local origActive = spaces.activeSpaces()  -- { [screenUUID] = spaceID }
  local allSpacesMap = spaces.allSpaces()   -- 활성 인덱스 계산용
  local activeMeta = {}
  for suuid, sid in pairs(origActive) do
    local idx = nil
    local list = allSpacesMap[suuid] or {}
    for j, s in ipairs(list) do
      if s == sid then idx = j break end
    end
    activeMeta[suuid] = { spaceID = sid, spaceIndex = idx }
  end

  -- 나중에 원래 스페이스들로 복귀
  local origSids = {}
  for _, sid in pairs(origActive) do
    origSids[#origSids + 1] = sid
  end

  local function finish()
    local payload = {
      meta   = { active = activeMeta },
      spaces = result
    }
    local encoded = json.encode(payload)
    local fh, err = io.open(target, "w")
    if not fh then
      print("desktop > save write error:", err)
      return
    end
    fh:write(encoded)
    fh:close()

    -- 원래 스페이스들로 복귀
    for _, sid in ipairs(origSids) do
      spaces.gotoSpace(sid)
    end

    toast.showToast("스페이스 구성 업데이트 완료", 2.0)
  end

  local function step()
    i = i + 1
    local entry = seq[i]
    if not entry then
      finish()
      return
    end
    gotoSpaceBlocking(entry.sid, SAVE_DWELL_SEC, function()
      local wins = window.visibleWindows()
      local recs = {}
      for _, win in ipairs(wins) do
        if win:isStandard() then
          recs[#recs + 1] = windowRecord(win)
        end
      end
      result[#result + 1] = {
        screenUUID = entry.screenUUID,
        spaceIndex = entry.index,
        windows    = recs
      }
      step()
    end)
  end

  step()
end

----------------------------------------------------------------
-- 현재 화면별 스페이스 목록과 빠른 인덱스
----------------------------------------------------------------
local function currentSpacesIndex()
  local m = {}
  local all = spaces.allSpaces()
  for scrUUID, list in pairs(all) do
    local idx = {}
    for i, sid in ipairs(list) do idx[sid] = i end
    m[scrUUID] = { list = list, idx = idx }
  end
  return m
end

----------------------------------------------------------------
-- 스크린 UUID 로 screen 찾기 (없으면 primary)
----------------------------------------------------------------
local function screenForUUID(uuid)
  for _, scr in ipairs(screen.allScreens()) do
    if scr:getUUID() == uuid then return scr end
  end
  return screen.primaryScreen()
end

----------------------------------------------------------------
-- 필요한 스페이스 수 확보/정렬
-- 반환: 대상 화면에서 사용할 spaceID 배열(저장된 spaceCount 만큼)
----------------------------------------------------------------
local function ensureSpacesForScreen(scr, wantedCount)
  local uuid = screenUUID(scr)
  local curList = spaces.spacesForScreen(scr) or {}
  local curCount = #curList

  -- 부족하면 추가
  while curCount < wantedCount do
    local ok, sid = pcall(spaces.addSpaceToScreen, scr)
    if ok and sid then
      curList = spaces.spacesForScreen(scr) or curList
      curCount = #curList
    else
      print("desktop > addSpace fail for screen", uuid)
      break
    end
  end

  -- 많으면 뒤에서 제거
  while curCount > wantedCount do
    local sid = curList[#curList]
    local ok = pcall(spaces.removeSpace, sid)
    if not ok then
      print("desktop > removeSpace fail, sid=", sid)
      break
    end
    curList = spaces.spacesForScreen(scr) or curList
    curCount = #curList
  end

  return spaces.spacesForScreen(scr) or curList
end

----------------------------------------------------------------
-- 앱 실행 여부
----------------------------------------------------------------
local function isBundleRunning(bundleID)
  local t = application.applicationsForBundleID(bundleID)
  return t and #t > 0
end

----------------------------------------------------------------
-- 번들ID로 앱 실행(한번만)
----------------------------------------------------------------
local launchedCache = {}
local function ensureAppLaunched(bundleID)
  if not bundleID or bundleID == "" then return end
  if launchedCache[bundleID] then return end
  if not isBundleRunning(bundleID) then
    application.launchOrFocusByBundleID(bundleID)
  end
  launchedCache[bundleID] = true
end

----------------------------------------------------------------
-- 번들ID+타이틀로 창 찾기 (현재 시스템 전체)
----------------------------------------------------------------
local function findWindow(bundleID, title)
  if not bundleID then return nil end
  for _, appObj in ipairs(application.applicationsForBundleID(bundleID) or {}) do
    for _, win in ipairs(appObj:allWindows()) do
      if win:isStandard() and (win:title() or "") == (title or "") then
        return win
      end
    end
  end
  return nil
end

----------------------------------------------------------------
-- 프레임 적용
----------------------------------------------------------------
local function applyFrame(win, frame)
  if not (win and frame) then return end
  win:setFrame(frame, 0)
end

----------------------------------------------------------------
-- 복원: 저장파일에 *있던* 스페이스만 순환하며 복구
-- 저장 파일 포맷 변경 대응 (신/구 포맷 모두 허용)
----------------------------------------------------------------
function M.restoreDesktopLayout(path)
  print("desktop > restoreDesktopLayout called")
  local target = path or layoutFile
  local fh = io.open(target, "r")
  if not fh then
    toast.showToast("스페이스 구성 없음", 2.0)
    return
  end
  local raw = fh:read("*a")
  fh:close()
  local ok, data = pcall(json.decode, raw)
  if not ok or type(data) ~= "table" then
    toast.showToast("스페이스 구성 없음", 2.0)
    return
  end

  -- 새 포맷/구 포맷 구분
  local activeMeta
  local savedSpaces
  if data.meta and data.spaces then
    activeMeta  = data.meta.active or {}
    savedSpaces = data.spaces
  else
    activeMeta  = nil
    savedSpaces = data
  end

  if type(savedSpaces) ~= "table" or #savedSpaces == 0 then
    toast.showToast("스페이스 구성 없음", 2.0)
    return
  end

  -- screenUUID별 그룹화
  local grouped = {}
  for _, sp in ipairs(savedSpaces) do
    grouped[sp.screenUUID] = grouped[sp.screenUUID] or {}
    table.insert(grouped[sp.screenUUID], sp)
  end
  -- 각 화면 내 spaceIndex 순으로 정렬
  for _, arr in pairs(grouped) do
    table.sort(arr, function(a, b) return (a.spaceIndex or 1) < (b.spaceIndex or 1) end)
  end

  -- (옵션) 모든 앱 종료
  if KILL_APPS_ON_RESTORE then
    for _, appObj in ipairs(application.runningApplications()) do
      local bid = appObj:bundleIdentifier()
      if bid ~= "org.hammerspoon.Hammerspoon" then
        appObj:kill()
      end
    end
    hs.timer.usleep(500000) -- 0.5s
  end

  launchedCache = {}

  -- 화면 순회(저장된 화면들만)
  local screensOrder = {}
  for scrUUID, _ in pairs(grouped) do
    screensOrder[#screensOrder + 1] = scrUUID
  end
  table.sort(screensOrder, function(a, b)
    local sa = screenForUUID(a):frame().x
    local sb = screenForUUID(b):frame().x
    return sa < sb
  end)

  -- 복구 완료 후 이동할 대상 스페이스 선계산
  local focusSIDs = {}
  if activeMeta then
    local curMap = currentSpacesIndex()
    for suuid, meta in pairs(activeMeta) do
      local entry = curMap[suuid]
      if entry then
        local sid = meta.spaceID
        if not entry.idx[sid] and meta.spaceIndex and entry.list[meta.spaceIndex] then
          sid = entry.list[meta.spaceIndex]
        end
        if sid then focusSIDs[#focusSIDs + 1] = sid end
      end
    end
  end

  local sIdx = 0
  local function stepScreen()
    sIdx = sIdx + 1
    local suuid = screensOrder[sIdx]
    if not suuid then
      -- 저장 당시 활성 스페이스로 복귀 (가능하면)
      if #focusSIDs > 0 then
        for _, sid in ipairs(focusSIDs) do
          spaces.gotoSpace(sid)
        end
      end
      toast.showToast("스페이스 구성 복구 완료", 2.0)
      return
    end
    local scr = screenForUUID(suuid)
    local savedSpacesForScreen = grouped[suuid]
    local wantedCount = #savedSpacesForScreen
    local curList = ensureSpacesForScreen(scr, wantedCount)

    local spIdx = 0
    local function stepSpace()
      spIdx = spIdx + 1
      local savedSpace = savedSpacesForScreen[spIdx]
      if not savedSpace then
        stepScreen()
        return
      end

      local targetSID = curList[spIdx] or curList[#curList]
      spaces.gotoSpace(targetSID)
      timer.doAfter(RESTORE_DWELL_SEC, function()
        -- 필요 앱 기동
        for _, winSpec in ipairs(savedSpace.windows or {}) do
          ensureAppLaunched(winSpec.app)
        end
        -- 앱이 뜨는 시간 후 프레임 적용
        timer.doAfter(RESTORE_DWELL_SEC, function()
          for _, winSpec in ipairs(savedSpace.windows or {}) do
            local w = findWindow(winSpec.app, winSpec.title)
            if w then
              applyFrame(w, winSpec.frame)
            end
          end
          stepSpace()
        end)
      end)
    end

    stepSpace()
  end

  stepScreen()
end

----------------------------------------------------------------
-- 시스템 준비 체크 (필요시 사용)
----------------------------------------------------------------
local function _readyForRestore()
  local finder = application.get("Finder")
  if not finder then return false end
  local all = spaces.allSpaces()
  if not all or next(all) == nil then return false end
  return true
end

-- 지연 복구: ready 될 때까지 폴링
function M.deferRestore(path, opts)
  opts = opts or {}
  local interval = opts.interval or 0.5
  local timeout  = opts.timeout  or 30
  local waited   = 0
  timer.doUntil(
    function()
      if _readyForRestore() then
        M.restoreDesktopLayout(path)
        return true
      end
      waited = waited + interval
      if waited >= timeout then
        print("desktop > deferRestore timeout; skipping auto-restore")
        return true
      end
      return false
    end,
    interval
  )
end

----------------------------------------------------------------
-- 수동 저장: cmd+ctrl+Insert (keycode 114)
----------------------------------------------------------------
hotkey.bind({ "cmd", "ctrl" }, 114, function()
  M.saveDesktopLayout()
end)

return M