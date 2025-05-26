
--[[
	read dir
	its the same except it removes .DS_Store
]]

local remove = require("@scripts/remove")
local fs = require("@lune/fs")

local function read_dir(path: string): { string }
	local contents = fs.readDir(path)
	local index = table.find(contents, ".DS_Store") 

	if index then
		remove(contents, index)
	end
	return contents
end

return read_dir
