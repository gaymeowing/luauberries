
--[[
	zip
	utility for zipping folders within lune
]]

local summon = require("@scripts/summon")
local process = require("@lune/process")
local fs = require("@lune/fs")

local IS_WINDOWS = process.os == "windows"
local WIN_OUTPUT = "RESULT.zip"

local function zip(input: string): string
	if IS_WINDOWS then
		summon(`Compress-Archive {input} -DestinationPath {WIN_OUTPUT} -CompressionLevel Optimal`)
		local zipped = fs.readFile(WIN_OUTPUT)
		fs.removeFile(WIN_OUTPUT)
		return zipped
	else
		return summon(`zip -9 -r -{input}`)
	end
end

return zip
