
--[[
	libs changed
	map of each library thats changed based on if it has a release for its latest version or not
]]

local get_latest_commit = require("@scripts/get_latest_commit")
local richterm = require("@scripts/richterm")
local read_dir = require("@scripts/read_dir")
local libinfo = require("@scripts/libinfo")
local summon = require("@scripts/summon")

local LIBS_CHANGED = {} :: { string }

for _, lib in read_dir("libs") do
	local latest_commit = get_latest_commit(`libs/{lib}`)

	-- lib isn't in the main branch (ie not released)
	if not latest_commit then
		continue
	elseif summon(`git tag -n {lib}@{libinfo(lib).version}`) == "" then
		table.insert(LIBS_CHANGED, lib)
	end
end

table.sort(LIBS_CHANGED)
print(
	richterm.bold(richterm.bgGreen("LIBRARIES CHANGED")) .. "\n" 
	.. table.concat(LIBS_CHANGED, "\n")
)

return table.freeze(LIBS_CHANGED)
