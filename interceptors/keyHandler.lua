--------------------------------------------------------------------
-- imports
--------------------------------------------------------------------
local eventtap = hs.eventtap
local hotkey   = hs.hotkey
hotkey.setLogLevel('warning')

--------------------------------------------------------------------
-- state
--------------------------------------------------------------------
local keyLogEnabled = true   -- start with logging ON

--------------------------------------------------------------------
-- Build a reverse lookup: keyCode → keyName
--------------------------------------------------------------------
local codeToKey = {}
for name, code in pairs(hs.keycodes.map) do
	codeToKey[code] = name
end

--------------------------------------------------------------------
-- helper: stringify modifiers (including fn unless suppressed)
--------------------------------------------------------------------
local function flagStr(flags)
	local parts = {}
	if flags.cmd   then table.insert(parts, "cmd")   end
	if flags.ctrl  then table.insert(parts, "ctrl")  end
	if flags.alt   then table.insert(parts, "alt")   end
	if flags.shift then table.insert(parts, "shift") end
	if flags.fn    then table.insert(parts, "fn")    end
	return (#parts > 0) and table.concat(parts, " + ") or "none"
end

--------------------------------------------------------------------
-- special keyCodes for which we drop the 'fn' flag entirely
--------------------------------------------------------------------
local ignoreFnFor = {
    [123] = true,  -- left arrow
    [124] = true,  -- right arrow
    [125] = true,  -- down arrow
    [126] = true,  -- up arrow
    [115] = true,  -- home
    [119] = true,  -- end
    [116] = true,  -- pageup
    [121] = true,  -- pagedown
    [117] = true,  -- forwarddelete
    [114] = true,  -- help
    [71]  = true,  -- padclear
    [122] = true,  -- F1
    [120] = true,  -- F2
    [99]  = true,  -- F3
    [118] = true,  -- F4
    [96]  = true,  -- F5
    [97]  = true,  -- F6
    [98]  = true,  -- F7
    [100] = true,  -- F8
    [101] = true,  -- F9
    [109] = true,  -- F10
    [103] = true,  -- F11
    [111] = true,  -- F12
    [105] = true,  -- F13
    [107] = true,  -- F14
    [113] = true,  -- F15
}

--------------------------------------------------------------------
-- NumPad keyCodes to patch (with comments)
--------------------------------------------------------------------
local padCodes = {
    [65] = true,  -- NumPad .
    [69] = true,  -- NumPad +
    [76] = true,  -- NumPad enter
    [78] = true,  -- NumPad -
    [83] = true,  -- NumPad 1
    [84] = true,  -- NumPad 2
    [85] = true,  -- NumPad 3
    [82] = true,  -- NumPad 0
    [86] = true,  -- NumPad 4
    [87] = true,  -- NumPad 5
    [88] = true,  -- NumPad 6
    [89] = true,  -- NumPad 7
    [91] = true,  -- NumPad 8
    [92] = true,  -- NumPad 9
}

--------------------------------------------------------------------
-- Build reverse lookup: eventTypeCode → eventTypeName
--------------------------------------------------------------------
local eventTypeNames = {}
for name, code in pairs(hs.eventtap.event.types) do
    eventTypeNames[code] = name
end

--------------------------------------------------------------------
-- logKey: log key events with type, code, and flags
--------------------------------------------------------------------

local function logKey(e)
	if keyLogEnabled then
		local t       = e:getType()
    local tName = eventTypeNames[t] or tostring(t)

		local code    = e:getKeyCode()
    local keyName = codeToKey[code] or tostring(code)

		local rawF    = e:getFlags()

    local f = { cmd=rawF.cmd, ctrl=rawF.ctrl, alt=rawF.alt, shift=rawF.shift, fn=rawF.fn }
    if ignoreFnFor[keyName] then
        f.fn = false
    end

    local mods = flagStr(f)

    if mods == "none" then
      print(string.format("[INFO] Key event: %s (%s)", keyName, tName))
    else
      print(string.format("[INFO] Key event: %s + %s (%s)", mods, keyName, tName))
    end
	end
end

--------------------------------------------------------------------
-- global event tap: capture keyDown, keyUp, flagsChanged
--------------------------------------------------------------------
local currentMods = {}

_G.handleFlagChange = eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(e)
  local f = e:getFlags()
    
  currentMods.cmd   = f.cmd
  currentMods.ctrl  = f.ctrl
  currentMods.alt   = f.alt
  currentMods.shift = f.shift
    
  if not (currentMods.cmd and currentMods.ctrl) then
    store.seqMode = false
  end

    return false
end)
_G.handleFlagChange:start()

_G.handleKeyInput = eventtap.new(
  { eventtap.event.types.keyDown,
  eventtap.event.types.keyUp,
  eventtap.event.types.keyRepeat },
	function(e)
    local code = e:getKeyCode()
    if not padCodes[code] then return false end

		local phys  = eventtap.checkKeyboardModifiers()
		local flags = e:getFlags()
    
		for k, v in pairs(currentMods) do
      if flags[k] ~= v then
        flags[k] = v
      end
    end

    e:setFlags(flags)

		logKey(e)
		return false
	end
)
_G.handleKeyInput:start()

--------------------------------------------------------------------
-- F12 toggles debug ON/OFF
--------------------------------------------------------------------
hotkey.bind({"cmd", "ctrl"}, "f12", function()
	keyLogEnabled = not keyLogEnabled
	toast.showToast(keyLogEnabled and "🟢 Key log on" or "⛔️ Key log off", 1.0)
end)