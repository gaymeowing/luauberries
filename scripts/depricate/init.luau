
--[[
	depricate
	makes a library depricated
]]

local process = require("@lune/process")
local fs = require("@lune/fs")

local ARGS = process.args
local ALT_FORMAT = fs.readFile("scripts/depricate/ALT_FORMAT.md")
local FORMAT = fs.readFile("scripts/depricate/FORMAT.md")
local LIB = ARGS[1]
local INSTEAD

for index, arg in ARGS do
	if arg == "--instead" or arg == "--i" then
		if index == 1 then 
			LIB = ARGS[3]
		end

		INSTEAD = ARGS[index + 1]
		break
	end
end

local readme = if INSTEAD then
		string.format(ALT_FORMAT, INSTEAD, INSTEAD, LIB)
	else
		string.format(FORMAT, LIB)

fs.writeFile(`libs/{LIB}/README.md`, readme)
