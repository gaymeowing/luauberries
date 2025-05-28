
--[[
	libs changed
	map of each library thats changed based on if it has a release for its latest version or not
]]

local richterm = require("@scripts/richterm")
local read_dir = require("@scripts/read_dir")
local libinfo = require("@scripts/libinfo")
local summon = require("@scripts/summon")

local HAS_CHANGED = {} :: { [string]: boolean? }
local OUTPUT_LIBS = {} :: { string }

for _, lib in read_dir("libs") do
	local latest_commit = summon(
		`git log -n 1 --pretty=format:%H libs/{lib}`, nil, true :: true
	)

	-- lib isn't in the main branch (ie not released)
	if not latest_commit then
		continue
	elseif summon(`git tag -n {lib}@{libinfo(lib).version}`) == "" then
		table.insert(OUTPUT_LIBS, lib)
		HAS_CHANGED[lib] = true
	end
end

table.sort(OUTPUT_LIBS)
print(
	richterm.bold(richterm.bgBrightGreen("LIBRARIES CHANGED")) .. "\n" 
	.. table.concat(OUTPUT_LIBS, "\n")
)

return table.freeze(HAS_CHANGED)
