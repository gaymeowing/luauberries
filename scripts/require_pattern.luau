
--[[
	require pattern
	module for storing require pattern info, and provides a create function for making a require pattern
]]

local START = "local%s*%w+%s*=%s*require%s*%([\"'`]"
local ENDING = "[\"'`]%)"

local function CREATE(path_pattern: string?): string
	return `{START}{path_pattern or "(.-)"}{ENDING}`
end

return table.freeze({
	libs_alias = CREATE("@libs/(%w+).-"),
	create = CREATE,
	ending = ENDING,
	start = START,
})
