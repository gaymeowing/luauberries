
-- release
-- makes new releases for each lib thats changed

local first_release_time = require("@self/first_release_time")
local pull_requests = require("@self/pull_requests")
local diff_reader = require("../diff_reader")
local DateTime = require("@lune/DateTime")
local process = require("@lune/process")
local serde = require("@lune/serde")
local packager = require("@self/packager")
local summon = require("../summon")
local libinfo = require("@self/libinfo")
local gitlog = require("@self/gitlog")
local fs = require("@lune/fs")

type ReleaseLibInfo = {
	prs: { pull_requests.PullRequestInfo },
	latest_release_time: number,
	commits: { gitlog.Commit },
	name: string,
}

local BASE_REPO_URL = "https://github.com/gaymeowing/luauberries"
local BASE_COMMIT_URL = `{BASE_REPO_URL}/commits/`
local BASE_PULL_URL = `{BASE_REPO_URL}/pull/`

local function CLONE<V>(t: { V }): { V }
	local clone = {}

	for key, value in t do
		clone[key] = value
	end
	return clone
end

local RELEASES = summon("gh", "release list --repo gaymeowing/luauberries --limit 500")
local LIBS_CHANGED = diff_reader.libs()
local ARGS = CLONE(process.args)

local LIB_LIST: { string } = if ARGS[1] == "all" then
		fs.readDir("libs")
	elseif #ARGS ~= 0 then
		table.move(ARGS, 1, #ARGS, #LIBS_CHANGED + 1, LIBS_CHANGED)
	else
		LIBS_CHANGED
local RELEASE_LIBS = table.create(#LIB_LIST) :: { ReleaseLibInfo }

local GMATCH = string.gmatch

local function write_and_insert(t: { string }, path: string, contents: string | buffer)
	fs.writeFile(path, contents)
	table.insert(t, path)
end

for index, lib in LIB_LIST do
	local pattern = `{lib} v%d+%.%d+%.%d+\t([^\t]-)\t{lib}@%d+%.%d+%.%d+\t(%S+)`
	local latest_release_time = first_release_time

	for type, iso in GMATCH(RELEASES, pattern) do
		if type ~= "Draft" then
			local date = DateTime.fromIsoDate(iso).unixTimestamp

			if latest_release_time < date then
				latest_release_time = date
			end
		end
	end
	
	RELEASE_LIBS[index] = {
		prs = pull_requests.get_after_time(lib, latest_release_time),
		latest_release_time = latest_release_time,
		commits = gitlog(lib, latest_release_time),
		name = lib,
	}
end

for _, release_libinfo in RELEASE_LIBS do
	local lib = release_libinfo.name
	local package_libinfo = packager.package(lib)
	local base_file_name = package_libinfo.base_file_name
	local libinfo = libinfo(lib)
	local version = libinfo.version
	local release_tag = `{lib}@{version}`
	local release_files = {}
	local notes = {}

	for _, pr in release_libinfo.prs do
		table.insert(notes, `* {pr.title} by @{pr.author} in {BASE_PULL_URL}{pr.num}`)
	end

	for _, commit in release_libinfo.commits do
		local hash = commit.hash
		table.insert(notes, `* {commit.title} by @{commit.author} in [{hash}]({BASE_COMMIT_URL}{hash})`)
	end

	if #notes ~= 0 then
		table.insert(notes, 1, "## Whats changed")
	else
		table.insert(notes, 1, "")
	end

	fs.writeDir("dist")
	write_and_insert(release_files, `./dist/{base_file_name}.zip`, package_libinfo.zipped)
	write_and_insert(release_files, `./dist/{base_file_name}.rbxm`, package_libinfo.rbxm)

	if package_libinfo.has_deps then
		local base_deps_file_name = package_libinfo.base_file_name_with_deps

		write_and_insert(release_files, `./dist/{base_deps_file_name}.zip`, package_libinfo.zipped_with_deps)
		write_and_insert(release_files, `./dist/{base_deps_file_name}.rbxm`, package_libinfo.rbxm_with_deps)
	end

	summon("gh", `release create {release_tag} --title "{lib} v{version}" --notes "{table.concat(notes, "\n")}" --draft`)

	for _, path in release_files do
		summon("gh", `release upload {release_tag} {path} --clobber`)
	end

	local release_url = serde.decode("json", summon("gh", `release view {release_tag} --json url`)).url
	print(`{lib} release: {release_url}`)
	fs.removeDir("dist")
end
fs.removeDir("libs_copy")
process.exit()
