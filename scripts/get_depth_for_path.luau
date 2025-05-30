
--[[
	get depth for path
	gives how deep a path is (the amount of backslashes it has)
]]

local function get_depth_for_path(path: string)
	return #string.split(path, "/")
end

return get_depth_for_path
