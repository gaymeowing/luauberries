
--[[
	ends with
	utility func for checking if a string ends with a diffrent string
]]

local function ends_with(s: string, ends_with: string): boolean
	return string.sub(s, #s - (#ends_with - 1)) == ends_with
end

return ends_with
