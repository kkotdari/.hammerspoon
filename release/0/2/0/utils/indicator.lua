local hs = hs
local M = {}
M.items   = {}
M._timers = {}

--------------------------------------------------------------------------------
-- Internal: get or create a menubar item by key
--------------------------------------------------------------------------------
local function getItem(name)
	if type(name) ~= "string" or #name == 0 then
		error("Indicator name must be non-empty string")
	end
	if M.items[name] then
		return M.items[name]
	end
	local item = hs.menubar.new()
	item:setTitle("")
	M.items[name] = item
	return item
end

--------------------------------------------------------------------------------
-- Display text persistently until changed
-- name: key, text: string to show ("" or nil clears)
--------------------------------------------------------------------------------
function M.showIndicator(name, text)
	local item = getItem(name)
	text = tostring(text or "")
	-- cancel any pending temporary timer
	if M._timers[name] then
		M._timers[name]:stop()
		M._timers[name] = nil
	end
	item:setTitle(text)
end

--------------------------------------------------------------------------------
-- Clear indicator immediately
--------------------------------------------------------------------------------
function M.clearIndicator(name)
	if type(name) ~= "string" or #name == 0 then return end
	local item = M.items[name]
	if item then
		item:setTitle("")
	end
	if M._timers[name] then
		M._timers[name]:stop()
		M._timers[name] = nil
	end
end

--------------------------------------------------------------------------------
-- Show text temporarily, then clear after duration seconds
-- name: key, text: shown string, duration: seconds (default 1.5)
--------------------------------------------------------------------------------
function M.showTemporaryIndicator(name, text, duration)
	duration = tonumber(duration) or 1.5
	-- cancel previous timer if exists
	if M._timers[name] then
		M._timers[name]:stop()
		M._timers[name] = nil
	end
	local item = getItem(name)
	item:setTitle(tostring(text or ""))
	-- schedule clear
	M._timers[name] = hs.timer.doAfter(duration, function()
		item:setTitle("")
		M._timers[name] = nil
	end)
end

--------------------------------------------------------------------------------
-- Set tooltip for an indicator
--------------------------------------------------------------------------------
function M.setTooltip(name, tip)
	if type(name) ~= "string" or #name == 0 then return end
	local item = getItem(name)
	if tip then
		item:setTooltip(tostring(tip))
	else
		item:setTooltip(nil)
	end
end

--------------------------------------------------------------------------------
-- Set click menu for an indicator
--------------------------------------------------------------------------------
function M.setMenu(name, menuTable)
	if type(name) ~= "string" or #name == 0 then return end
	if type(menuTable) ~= "table" then return end
	local item = getItem(name)
	item:setMenu(menuTable)
end

--------------------------------------------------------------------------------
-- Delete a single indicator
--------------------------------------------------------------------------------
function M.delete(name)
	if type(name) ~= "string" or #name == 0 then return end
	local item = M.items[name]
	if item then
		item:delete()
		M.items[name] = nil
	end
	if M._timers[name] then
		M._timers[name]:stop()
		M._timers[name] = nil
	end
end

--------------------------------------------------------------------------------
-- Delete all indicators (e.g. on reload)
--------------------------------------------------------------------------------
function M.deleteAll()
	for name, item in pairs(M.items) do
		item:delete()
		M.items[name] = nil
	end
	for name, t in pairs(M._timers) do
		t:stop()
		M._timers[name] = nil
	end
end

--------------------------------------------------------------------------------
-- Convenience: toggle mode indicator
-- name: key, active: boolean, label: text when active
--------------------------------------------------------------------------------
function M.toggleMode(name, active, label)
	if active then
		M.showIndicator(name, label or name)
	else
		M.clearIndicator(name)
	end
end

return M