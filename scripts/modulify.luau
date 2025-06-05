
--[[
	modulify
	converts a folder to a module script
]]

local read_dir = require("@scripts/read_dir")
local remove = require("@scripts/remove")
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

type ModuleScript = roblox.Instance & {
	Source: string,
}

type DirInfo = {
	instance: roblox.Instance,
	path: string,
}

local CACHED_MODULES = {} :: { [string]: ModuleScript? }
local CREATE_INSTANCE = roblox.Instance.new
local DIRQUEUE = {} :: { DirInfo }

local function CREATE_MODULE_SCRIPT(name: string, source: string, p: roblox.Instance?): ModuleScript
	local module = CREATE_INSTANCE("ModuleScript") :: ModuleScript
	module.Source = source
	module.Name = name
	module.Parent = p
	return module
end

local function CREATE_FOLDER(name: string, p: roblox.Instance?): roblox.Instance
	local folder = CREATE_INSTANCE("Folder")
	folder.Name = name
	folder.Parent = p
	return folder
end

local function MODULIFY_ITER_DIR(
	queue_len: number, path: string, parent: roblox.Instance
): number
	for _, sub_name in read_dir(path) do
		local sub_path = `{path}/{sub_name}`

		if fs.isDir(sub_path) then
			local init_path = `{sub_path}/init.luau`
			local instance = if fs.isFile(init_path) then
					CREATE_MODULE_SCRIPT(sub_name, fs.readFile(sub_path), parent)
				else
					CREATE_FOLDER(sub_name, parent)
			queue_len += 1

			DIRQUEUE[queue_len] = {
				instance = instance,
				path = sub_path,
			}
		elseif sub_name ~= "init.luau" then
			CREATE_MODULE_SCRIPT(sub_name, fs.readFile(sub_path), parent)
		end
	end

	return queue_len
end

local function modulify(lib: string, path: string, ignore_cache: boolean?): ModuleScript
	if not ignore_cache then
		local module = CACHED_MODULES[lib]
		
		if module then
			return module
		end
	end

	local module = CREATE_MODULE_SCRIPT(lib, fs.readFile(`{path}/init.luau`))
	local queue_len = 0

	queue_len = MODULIFY_ITER_DIR(queue_len, path, module)

	while #DIRQUEUE ~= 0 do
		local dir_info = remove(DIRQUEUE)

		queue_len = MODULIFY_ITER_DIR(
			queue_len, dir_info.path, dir_info.instance
		)
	end

	CACHED_MODULES[path] = module
	table.clear(DIRQUEUE)
	return module
end

return modulify
