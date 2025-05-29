
--[[
	get latest commit
	gets the latest commit for a path
]]

local summon = require("@scripts/summon")

local function get_latest_commit(path: string): string?
	-- https://stackoverflow.com/questions/25921757/how-to-get-last-commit-date-inside-a-folder-directory-in-github-repo
	return summon(`git log -n 1 --pretty=format:%H {path}`, nil, true :: true)
end

return get_latest_commit
