
--[[
	release
	makes releases for libraries
]]

local deep_iter_scripts = require("@scripts/deep_iter_scripts")
local require_pattern = require("@scripts/require_pattern")
local libs_changed = require("@scripts/libs_changed")
local depgraph = require("@scripts/depgraph")
local read_dir = require("@scripts/read_dir")
local license = require("@scripts/license")
local libinfo = require("@scripts/libinfo")
local summon = require("@scripts/summon")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local zip = require("@scripts/zip")
local fs = require("@lune/fs")

local FILE_NEW_LINE_CHAR = if process.os == "windows" then "\r\n" else "\n"
local HEADER_PATTERN = `^%s-%-%-%[%[([%w%s]+)%]%]{FILE_NEW_LINE_CHAR}`
local LIB_REQUIRE_LINE_PATTERN = require_pattern.create("@libs/.-")
local LIB_TO_INSTANCE = {} :: { [string]: roblox.Instance }
local HOT_COMMENT_PATTERN = `%-%-!.-{FILE_NEW_LINE_CHAR}`
local LICENSE = string.sub(license, 5, #license)
local RELEASE_DIR = "RELEASE"

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
end

local function FIXUP_LIB(lib: string, path: string)
	deep_iter_scripts(path, function(_, src, depth) 
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
local function get_last_tag_commit(last_tag: string): string
	local result = summon(`git show-ref --hash {last_tag}`)
	return string.sub(result, 1, #result - 2)
end

local function author_fix(author: string): string
    if author == "kalrnlo" then
        return "gaymeowing"
    else
        return author
    end
end

for _, lib in libs_changed do
	local copy_path = `{RELEASE_DIR}/{lib}`
	local alone_copy_path = `{copy_path}/alone`
	COPY_LIB_FOR_RELEASE(lib, alone_copy_path)
	FIXUP_LIB(lib, alone_copy_path)
end

for _, lib in libs_changed do
	local copy_path = `{RELEASE_DIR}/{lib}`
	local alone_copy_path = `{copy_path}/alone`
	local depinfo = depgraph[lib]

	if depinfo.has_deps then
		local deps_copy_path = `{copy_path}/deps`
		fs.copy(alone_copy_path, `{deps_copy_path}/{lib}`, true)

		for _, dep in depinfo.deep do
			local dep_copy_path = `{RELEASE_DIR}/{dep}/alone`

			if not fs.isDir(dep_copy_path) then
				COPY_LIB_FOR_RELEASE(dep, dep_copy_path)
				FIXUP_LIB(dep, dep_copy_path)
			end

			fs.copy(dep_copy_path, `{deps_copy_path}/{dep}`, true)
		end
	end
end

-- setting up stuff
for _, lib in libs_changed do
	local tags = summon(`git tag --sort=-creatordate -n {lib}@*`)
	local last_tag = string.match(tags, "(%w+@.-)%s")
	local changed = {} :: { string }

	if last_tag then
		local last_tag_commit = get_last_tag_commit(last_tag)
		print(last_tag_commit)
	end
end

if true then
	return
end

fs.removeDir(RELEASE_DIR)

