
--[[
	license
	gives the license file as a code comment
]]

local process = require("@lune/process")
local fs = require("@lune/fs")

local new_line_char = if process.os == "windows" then "\r\n" else "\n"
local tabbed_license = string.gsub(fs.readFile("LICENSE"), new_line_char, "\n\t")

return `--[[\n\t{string.sub(tabbed_license, 1, #tabbed_license - 1)}]]`
