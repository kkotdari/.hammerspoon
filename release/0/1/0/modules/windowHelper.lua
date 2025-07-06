local hs_screen = hs.screen

local M = {}

local gridW, gridH = 49, 13
local baseChar = " "
local arrowMapping = {
    up        = "↑", down      = "↓",
    left      = "←", right     = "→",
    upLeft    = "↖", upRight   = "↗",
    downLeft  = "↙", downRight = "↘",
}

local function clamp(val, minv, maxv)
    if val < minv then return minv end
    if val > maxv then return maxv end
    return val
end

local function getScreenFrame()
    local screenObj = hs_screen.mainScreen()
    if not screenObj then
        local all = hs_screen.allScreens()
        screenObj = all and all[1]
    end
    if not screenObj then return nil end
    local ok, vf = pcall(function() return screenObj:visibleFrame() end)
    if ok and vf then return vf end
    return screenObj:frame()
end

local function cellIndexForPoint(x, y, screenFrame)
    local cw, ch = screenFrame.w / gridW, screenFrame.h / gridH
    local col = math.floor((x - screenFrame.x) / cw)
    local row = math.floor((y - screenFrame.y) / ch)
    return clamp(row, 0, gridH-1), clamp(col, 0, gridW-1)
end

local function cellRangeForRect(rect, screenFrame)
    local cw, ch = screenFrame.w / gridW, screenFrame.h / gridH
    local c1 = math.floor((rect.x - screenFrame.x) / cw)
    local c2 = math.floor(((rect.x + rect.w) - screenFrame.x) / cw)
    local r1 = math.floor((rect.y - screenFrame.y) / ch)
    local r2 = math.floor(((rect.y + rect.h) - screenFrame.y) / ch)
    return clamp(r1,0,gridH-1), clamp(r2,0,gridH-1), clamp(c1,0,gridW-1), clamp(c2,0,gridW-1)
end

function M.showToast(prevUnit, newUnit)
    local screenFrame = getScreenFrame()
    if not screenFrame then return end

    local px = screenFrame.x + prevUnit.x * screenFrame.w
    local py = screenFrame.y + prevUnit.y * screenFrame.h
    local pw = prevUnit.w * screenFrame.w
    local ph = prevUnit.h * screenFrame.h
    local nx = screenFrame.x + newUnit.x * screenFrame.w
    local ny = screenFrame.y + newUnit.y * screenFrame.h
    local nw = newUnit.w * screenFrame.w
    local nh = newUnit.h * screenFrame.h

    local prevRect = { x=px, y=py, w=pw, h=ph }
    local newRect  = { x=nx, y=ny, w=nw, h=nh }

    local grid, weight = {}, {}
    for r=1,gridH do
        grid[r], weight[r] = {}, {}
        for c=1,gridW do
            grid[r][c] = baseChar
            weight[r][c] = 0
        end
    end

    local cornersPrev = {{x=px,y=py},{x=px+pw,y=py},{x=px+pw,y=py+ph},{x=px,y=py+ph}}
    local cornersNew  = {{x=nx,y=ny},{x=nx+nw,y=ny},{x=nx+nw,y=ny+nh},{x=nx,y=ny+nh}}

    -- for i=1,4 do
    --     local cp, cn = cornersPrev[i], cornersNew[i]
    --     local dx, dy = cn.x - cp.x, cn.y - cp.y
    --     local prow, pcol = cellIndexForPoint(cp.x, cp.y, screenFrame)
    --     if dx ~= 0 or dy ~= 0 then
    --         local dcol = dx > 0 and 1 or dx < 0 and -1 or 0
    --         local drow = dy > 0 and 1 or dy < 0 and -1 or 0
    --         local hor = dcol > 0 and "right" or dcol < 0 and "left" or ""
    --         local ver = drow > 0 and "down" or drow < 0 and "up" or ""
    --         local key = (ver ~= "" and hor ~= "") and (ver..hor:sub(1,1):upper()..hor:sub(2)) or (hor ~= "" and hor) or ver
    --         local achar = arrowMapping[key]
    --         if achar then
    --             local ar = clamp(prow + drow, 0, gridH-1)
    --             local ac = clamp(pcol + dcol, 0, gridW-1)
    --             grid[ar+1][ac+1] = achar
    --             weight[ar+1][ac+1] = 3
    --         end
    --     end
    -- end

    local pr1,pr2,pc1,pc2 = cellRangeForRect(prevRect, screenFrame)
    for c = pc1, pc2 do
        if weight[pr1+1][c+1] < 1 then grid[pr1+1][c+1] = "╌"; weight[pr1+1][c+1] = 1 end
        if weight[pr2+1][c+1] < 1 then grid[pr2+1][c+1] = "╌"; weight[pr2+1][c+1] = 1 end
    end
    for r = pr1, pr2 do
        if weight[r+1][pc1+1] < 1 then grid[r+1][pc1+1] = "╎"; weight[r+1][pc1+1] = 1 end
        if weight[r+1][pc2+1] < 1 then grid[r+1][pc2+1] = "╎"; weight[r+1][pc2+1] = 1 end
    end

    for i=1,4 do
        local cp = cornersPrev[i]
        local r,c = cellIndexForPoint(cp.x, cp.y, screenFrame)
        if weight[r+1][c+1] < 2 then
            grid[r+1][c+1] = "▫"
            weight[r+1][c+1] = 2
        end
    end

    local nr1,nr2,nc1,nc2 = cellRangeForRect(newRect, screenFrame)
    for c = nc1, nc2 do
        if weight[nr1+1][c+1] < 3 then grid[nr1+1][c+1] = "─"; weight[nr1+1][c+1] = 3 end
        if weight[nr2+1][c+1] < 3 then grid[nr2+1][c+1] = "─"; weight[nr2+1][c+1] = 3 end
    end
    for r = nr1, nr2 do
        if weight[r+1][nc1+1] < 3 then grid[r+1][nc1+1] = "│"; weight[r+1][nc1+1] = 3 end
        if weight[r+1][nc2+1] < 3 then grid[r+1][nc2+1] = "│"; weight[r+1][nc2+1] = 3 end
    end


    for i=1,4 do
        local cn = cornersNew[i]
        local r,c = cellIndexForPoint(cn.x, cn.y, screenFrame)
        if weight[r+1][c+1] < 5 then
            grid[r+1][c+1] = "▪"
            weight[r+1][c+1] = 4
        end
    end

    for r=1,gridH do
        for c=1,gridW do
            if weight[r][c] > 0 then goto continue end

            local isTop = r == 1
            local isBottom = r == gridH
            local isLeft = c == 1
            local isRight = c == gridW

            if isTop and isLeft then
                grid[r][c] = "·"
            elseif isTop and isRight then
                grid[r][c] = "·"
            elseif isBottom and isLeft then
                grid[r][c] = "·"
            elseif isBottom and isRight then
                grid[r][c] = "·"
            elseif isTop or isBottom then
                grid[r][c] = "·"
            elseif isLeft or isRight then
                grid[r][c] = "·"
            end
            -- if isTop and isLeft then
            --     grid[r][c] = "┌"
            -- elseif isTop and isRight then
            --     grid[r][c] = "┐"
            -- elseif isBottom and isLeft then
            --     grid[r][c] = "└"
            -- elseif isBottom and isRight then
            --     grid[r][c] = "┘"
            -- elseif isTop or isBottom then
            --     grid[r][c] = "─"
            -- elseif isLeft or isRight then
            --     grid[r][c] = "│"
            -- end

            ::continue::
        end
    end

    lines = {}
    for r=1,gridH do
        lines[#lines+1] = table.concat(grid[r])
    end

    toast.showToast(table.concat(lines, "\n"), 1.25, { name="D2Coding", size=8, lineHeightMultiple = 0.925 })
end

return M