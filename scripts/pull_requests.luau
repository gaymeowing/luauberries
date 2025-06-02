
--[[
	pull requests
	gets pull requests after a given unix timestamp
]]

local read_dir = require("@scripts/read_dir")
local datetime = require("@lune/datetime")
local summon = require("@scripts/summon")
local serde = require("@lune/serde")

export type PullRequestInfo = {
	merged_at: number,
	number: number,
	author: string,
	title: string,
	url: string,
}

local LIBS_TO_PRS = {} :: { [string]: { PullRequestInfo } }

local function get_after_time(
	lib: string, prs: { PullRequestInfo }, time: number
): { PullRequestInfo }
	local prs_after_time = {}

	for _, pr in prs do
		if pr.merged_at > time then
			table.insert(prs_after_time, pr)
		end
	end
	return table.freeze(prs_after_time)
end

local pull_requests = {}

function pull_requests.get_all_after_time(time: number): { [string]: { PullRequestInfo }? }
	local libs_to_prs_after_time = {}

	for lib, prs in LIBS_TO_PRS do
		local prs_after_time = get_after_time(lib, prs, time)

		if #prs_after_time ~= 0 then
			libs_to_prs_after_time[lib] = prs_after_time
		end
	end
	return table.freeze(libs_to_prs_after_time)
end

function pull_requests.get_after_time(lib: string, time: number): { PullRequestInfo }
	return (get_after_time(lib, LIBS_TO_PRS[lib], time))
end

do

	local pull_requests = serde.decode(
		"json", 
		summon("gh pr list --json author,mergedAt,files,title,number,url --limit 100 --state merged")
	)

	for _, lib in read_dir("libs") do
		LIBS_TO_PRS[lib] = {}
	end

	for _, pr in pull_requests do
		for _, file in pr.files do
			local lib = string.match(file.path, "^libs/([^/]+)") or 
				string.match(file.path, "^docs/([^/%.]+)")
	
			if lib then
				local prs = LIBS_TO_PRS[lib]

				if prs then
					table.insert(prs, {
						merged_at = datetime.fromIsoDate(pr.mergedAt).unixTimestamp,
						author = pr.author.login,
						number = pr.number,
						title = pr.title,
						url = pr.url,
					})
				end
			end
		end
	end

end

return table.freeze(pull_requests)
