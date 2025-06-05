
--[[
	zip
	utility for zipping folders within lune
]]

local summon = require("@scripts/summon")

local function zip(path: string): string
	return summon(`tar -c -z --exclude *.DS_Store {path} `)
end

return zip
