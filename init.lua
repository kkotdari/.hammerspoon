local versionEls = { "0", "2", "0" }
local versionPath = table.concat(versionEls, "/")

local path = "release/" .. versionPath

require(path .. "/init")