
--[[
	release
	makes releases for libraries
]]

local deep_iter_scripts = require("@scripts/deep_iter_scripts")
local require_pattern = require("@scripts/require_pattern")
local pull_requests = require("@scripts/pull_requests")
local libs_changed = require("@scripts/libs_changed")
local modulify = require("@scripts/modulify")
local depgraph = require("@scripts/depgraph")
local license = require("@scripts/license")
local libinfo = require("@scripts/libinfo")
local summon = require("@scripts/summon")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local zip = require("@scripts/zip")
local fs = require("@lune/fs")

local FILE_NEW_LINE_CHAR = if process.os == "windows" then "\r\n" else "\n"
local HEADER_PATTERN = `^%s*%-%-%[%[([%w%s%p]+)%]%]{FILE_NEW_LINE_CHAR}`
local LIB_REQUIRE_LINE_PATTERN = require_pattern.create("@libs/.-")
local GIT_LOG_HASHES_ARGS = "--author-date-order --pretty=format:%H"
local BASE_REPO_URL = "https://github.com/gaymeowing/luauberries"
local HOT_COMMENT_PATTERN = `%-%-!.-{FILE_NEW_LINE_CHAR}`
local BASE_COMMIT_URL = `{BASE_REPO_URL}/commits/`
local LICENSE = string.sub(license, 5, #license)
local BASE_PULL_URL = `{BASE_REPO_URL}/pull/`
local RELEASE_DIR = "RELEASE"
local DIST_DIR = "DIST"

local function get_unreleased_commits(lib: string, last_commit_time: number): { string }
	return string.split(
		summon(`git log --after {last_commit_time} --no-merges {GIT_LOG_HASHES_ARGS} libs/{lib}`),
		"\n"
	)
end

local function upload_to_release(tag: string, file_name: string, content: string)
	file_name = `{DIST_DIR}/{file_name}`
	fs.writeFile(file_name, content)
	summon(`gh release upload {tag} {file_name} --clobber`)
end

local function REMOVE_FILE_IF_EXISTS(path: string)
	if fs.isFile(path) then
		fs.removeFile(path)
	end
end

local function REMOVE_DIR_IF_EXISTS(path: string)
	if fs.isDir(path) then
		fs.removeDir(path)
	end
end

local function COPY_LIB_FOR_RELEASE(lib: string, to: string)
	fs.copy(`libs/{lib}`, to, true)
	REMOVE_FILE_IF_EXISTS(`{to}/LIBRARY.toml`)
	REMOVE_FILE_IF_EXISTS(`{to}/README.md`)
	REMOVE_FILE_IF_EXISTS(`{to}/test.luau`)
	REMOVE_DIR_IF_EXISTS(`{to}/test`)

	deep_iter_scripts(to, function(_, src, depth) 
		depth -= 2
		local depth_even_half = depth // 2
		local hot_comments = {}
		local header

		src = string.gsub(src, LIB_REQUIRE_LINE_PATTERN, function(line)
			local inner = string.rep("../", depth_even_half)

			if depth % 2 ~= 0 then
				inner ..= string.rep("./", depth - (depth_even_half * 2))
			end

			return string.match(line, require_pattern.start) .. inner 
				.. string.match(line, require_pattern.libs_alias) 
				.. string.match(line, require_pattern.ending)
		end)
		src = string.gsub(src, HOT_COMMENT_PATTERN, function(hot_comment)
			table.insert(hot_comments, hot_comment)
			return ""
		end)
		src = string.gsub(src, HEADER_PATTERN, function(header_body)
			header = `--[[{header_body}`
			return ""
		end)

		if not header then
			error(`library '{lib}' does not have a header comment`, 5)
		end

		return `{table.concat(hot_comments) or ""}\n{header or ""}{LICENSE}\n{src}`
	end)
end

-- this exists because git appends a newline character to the end 😭
local function get_commit_from_tag(tag: string): string
	local result = summon(`git show-ref --hash {tag}`)
	return string.sub(result, 1, #result - 2)
end

local function get_last_unreleased_commit_time(lib: string): number
	local tags = summon(`git tag --sort=-creatordate -n {lib}@*`)
	local last_tag = string.match(tags, "(%w+@.-)%s")
	local last_commit = if last_tag then
			get_commit_from_tag(last_tag)
		else
			string.match(
				summon(`git log {GIT_LOG_HASHES_ARGS} libs/{lib}`), 
				"\n(%x*)$"
			) :: string

	return tonumber(string.match(
		summon(`git show --pretty=format:%ad --date=unix {last_commit}`), 
		"^(%d+)\n"
	)) :: any
end

local function author_fix(author: string): string
    if author == "kalrnlo" or author == "witchiest" then
        return "gaymeowing"
    else
        return author
    end
end

local function reverse<V>(t: { V }): { V }
	for index = 1, #t // 2 do
		local swap_index = (#t - index) + 1
		local value = t[index]
		t[index] = t[swap_index]
		t[swap_index] = value
	end
	return t
end

fs.writeDir(DIST_DIR)

for _, lib in libs_changed do
	COPY_LIB_FOR_RELEASE(lib, `{RELEASE_DIR}/{lib}/alone`)
end

for _, lib in libs_changed do
	local last_commit_time = get_last_unreleased_commit_time(lib)
	local commits = reverse(get_unreleased_commits(lib, last_commit_time))
	local copy_path = `{RELEASE_DIR}/{lib}`
	local alone_path = `{copy_path}/alone`
	local version = libinfo(lib).version
	local module =  modulify(alone_path)
	local rbxm = roblox.serializeModel({ module })
	local zipped = zip(alone_path)
	local depinfo = depgraph[lib]
	local zipped_with_deps: any
	local rbxm_with_deps: any
	local notes = {
		"## Whats changed",
		"",
	}

	if depinfo.has_deps then
		local modules = table.create(#depinfo.deep + 1) :: any
		local deps_path = `{copy_path}/deps`

		fs.copy(alone_path, `{deps_path}/{lib}`, true)
		modules[1] = module

		for index, dep in depinfo.deep do
			local dep_path = `{RELEASE_DIR}/{dep}/alone`

			if not fs.isDir(dep_path) then
				COPY_LIB_FOR_RELEASE(dep, dep_path)
				modules[index + 1] = modulify(dep_path)
			end

			fs.copy(dep_path, `{deps_path}/{dep}`, true)
		end

		rbxm_with_deps = roblox.serializeModel(modules)
		zipped_with_deps = zip(deps_path)
		fs.removeDir(deps_path)
	end

	for _, pr in pull_requests.get_after_time(lib, last_commit_time) do
		table.insert(notes, `* {pr.title} by @{author_fix(pr.author)} in {BASE_PULL_URL}{pr.number}`)
	end

	for _, commit in commits do
		local author, title = string.match(
			summon(`git show -s --format='%an %f' {commit}`), "(%w+) ([%w%p]+)\n"
		)
		title = string.gsub(title :: any, "%-", " ")

		table.insert(notes, `* {title} by @{author_fix(author :: any)} in [{commit}]({BASE_COMMIT_URL}{commit})`)
	end

	local release_tag = `{lib}@{version}`
	local upload_name = `{lib}-{version}`

	summon(`gh release create {release_tag} --title "{lib} v{version}" --notes "{table.concat(notes, "\n")}" --draft`)
	upload_to_release(release_tag, `{upload_name}.zip`, zipped)
	upload_to_release(release_tag, `{upload_name}.rbxm`, rbxm)

	if zipped_with_deps then
		local upload_name_deps = `{upload_name}-deps`
		upload_to_release(release_tag, `{upload_name_deps}.zip`, zipped_with_deps :: any)
		upload_to_release(release_tag, `{upload_name_deps}.rbxm`, rbxm_with_deps)
	end

	local url = string.match(summon(`gh release view {release_tag} --json url`), ":\"(.*)\"")
	print(`{lib} release: {url}`)
end

fs.removeDir(RELEASE_DIR)
fs.removeDir(DIST_DIR)
