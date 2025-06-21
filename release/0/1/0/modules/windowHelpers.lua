-- NOTE: this is a helper module to be required in main script

local toast = require('toast')

local AreaChangeDescriber = {}

local arrows = {
    up    = "↑",
    down  = "↓",
    left  = "←",
    right = "→",
    upLeft    = "↖",
    upRight   = "↗",
    downLeft  = "↙",
    downRight = "↘",
    none = "➝",
}

local function direction(from, to)
    local dx = to.x - from.x
    local dy = to.y - from.y
    local threshold = 0.005
    local horiz = math.abs(dx) > threshold and (dx > 0 and "right" or "left") or ""
    local vert  = math.abs(dy) > threshold and (dy > 0 and "down"  or "up")   or ""

    if vert ~= "" and horiz ~= "" then
        return arrows[vert .. horiz:sub(1,1):upper() .. horiz:sub(2)]
    elseif vert ~= "" then
        return arrows[vert]
    elseif horiz ~= "" then
        return arrows[horiz]
    else
        return arrows.none
    end
end

local function round2(n)
    return math.floor(n * 100 + 0.5) / 100
end

local function describeChange(prevUnit, newUnit)
    local prevArea = round2(prevUnit.w * prevUnit.h)
    local newArea  = round2(newUnit.w * newUnit.h)
    local ratio = round2(newArea / prevArea)
    local arrow = direction(prevUnit, newUnit)
    if ratio == 1 then
        return arrow
    elseif ratio == 0.25 then
        return arrow .. "×¼"
    elseif ratio == 0.33 then
        return arrow .. "×⅓"
    elseif ratio == 0.5 then
        return arrow .. "×½"
    elseif ratio == 0.66 then
        return arrow .. "×⅔"
    elseif ratio == 0.75 then
        return arrow .. "×¾"
    elseif ratio == 2 then
        return arrow .. "×2"
    elseif ratio == 3 then
        return arrow .. "×3"
    else
        return arrow .. string.format("×%.2f", ratio)
    end
end

function AreaChangeDescriber.showToastIfChanged(prevUnit, newUnit)
    local msg = describeChange(prevUnit, newUnit)
    toast.show(msg, 0.75)
end

return AreaChangeDescriber
