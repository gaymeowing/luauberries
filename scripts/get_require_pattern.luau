
--[[
	get require pattern
	function for getting a require pattern with a specific pattern for the inner path optionally
]]

local START = "local%s*%w+%s*=%s*require%s*%([\"'`]"
local ENDING = "[\"'`]%)"

local function get_require_pattern(path_pattern: string?): string
	return `{START}{path_pattern or "(.-)"}{ENDING}`
end

return get_require_pattern
