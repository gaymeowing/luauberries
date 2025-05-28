
--[[
	test runner
	script for running tests for ci
]]

local libs_changed = require("@scripts/libs_changed")
local read_dir = require("@scripts/read_dir")
local depgraph = require("@scripts/depgraph")
local libinfo = require("@scripts/libinfo")
local process = require("@lune/process")
local fs = require("@lune/fs")

local function GET_LIBS_TO_TEST(): { string }
	if process.args[1] == "all" then
		return read_dir("libs")
	end
	local libs_to_test

	if #process.args ~= 0 then
		libs_to_test = {}

		for _, lib in process.args do
			local lib_path = `libs/{lib}`

			if fs.isFile(`{lib_path}/test.luau`) or fs.isDir(`{lib_path}/test`)  then
				table.insert(libs_to_test, lib)
			else
				error(`library {lib} doesn't exist or doesnt have a subdir named 'test' or a 'test.luau' file`)
			end
		end
	else
		libs_to_test = table.clone(libs_changed)
	end

	for lib, info in depgraph do
		for _, lib_dep in info.deep do
			if table.find(libs_to_test, lib_dep) then
				table.insert(libs_to_test, lib)
				break
			end
		end
	end

	return libs_to_test
end


--mock_roblox()

for _, lib in GET_LIBS_TO_TEST() do
	--TODO: make me not skip roblox libraries, via switching to using the open cloud execution api stuffs
	local libinfo = libinfo(lib)

	if libinfo.runtime and libinfo.runtime.main == "roblox" then
		continue
	end

	local path = `libs/{lib}/test`
	local file_path = `{path}.luau`
	local real_path: string
	local contents: string

	if fs.isDir(path) then
		local init_path = `{path}/init.luau`

		if fs.isFile(init_path) then
			contents = fs.readFile(init_path)
			real_path = init_path
		else
			error(`library {lib} has a test dir with no init.luau file`)
		end
	elseif fs.isFile(file_path) then
		contents = fs.readFile(file_path)
		real_path = file_path
	else
		continue
	end

	-- test not implemented and its just a placeholder as a reminder
	if #contents == 0 then
		continue
	end

	fs.writeFile(real_path, `{contents}\n\nassert(FINISH())\nprint()`)
	-- require is no longer relative if its called within a pcall??
	;(require)(`@libs/{lib}/test`)
	fs.writeFile(real_path, contents)
end

process.exit(0)
