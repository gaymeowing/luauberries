
--[[
	libs changed
	map of each library thats changed based on if it has a release for its latest version or not
]]

local richterm = require("@scripts/richterm")
local read_dir = require("@scripts/read_dir")
local libinfo = require("@scripts/libinfo")
local summon = require("@scripts/summon")

local LIBS_CHANGED = {} :: { string }

for _, lib in read_dir("libs") do
	local latest_commit = summon(
		`git log -n 1 --pretty=format:%H libs/{lib}`, nil, true :: true
	)

	-- lib isn't in the main branch (ie not released)
	if not latest_commit then
		continue
	elseif summon(`git tag -n {lib}@{libinfo(lib).version}`) == "" then
		table.insert(LIBS_CHANGED, lib)
	end
end

table.sort(LIBS_CHANGED)
print(
	richterm.bold(richterm.bgBrightGreen("LIBRARIES CHANGED")) .. "\n" 
	.. table.concat(LIBS_CHANGED, "\n")
)

return table.freeze(LIBS_CHANGED)
