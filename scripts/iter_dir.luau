
--[[
	iter dir
	recursively iterates over a directory and 
	calls a callback that can then optionally move or change the contents of the file
]]

local get_depth_for_path = require("@scripts/get_depth_for_path")
local read_dir = require("@scripts/read_dir")
local remove = require("@scripts/remove")
local fs = require("@lune/fs")

type BaseFileInfo<N, P> = {
	contents: (string | buffer)?,
	path: P,
	name: N,
}

export type OptionalFileInfo = 
	| BaseFileInfo<string, nil>
	| BaseFileInfo<nil, string>
	| BaseFileInfo<nil, nil>

type IterDirCallback = ((name: string, path: string, contents: string, depth: number) -> (OptionalFileInfo | "break" | "continue")?) |
	((name: string, path: string, contents: string, depth: number) -> ())

type DirInfo = {
	depth: number,
	path: string,
}

local DIRQUEUE = {} :: { DirInfo }

local function iter_dir(path: string, f: IterDirCallback)
	local queue_len = 1
	DIRQUEUE[1] = {
		depth = get_depth_for_path(path),
		path = path,
	}

	while queue_len ~= 0 do
        local dir_info = remove(DIRQUEUE, queue_len)
		local next_depth = dir_info.depth + 1
		local dir_path = dir_info.path
        queue_len -= 1

        for _, entry in read_dir(dir_path) do
            local path = `{dir_path}/{entry}`

			if fs.isFile(path) then
				local contents = fs.readFile(path)
				local result = f(
					string.match(entry, "[^%.]+") or "", 
					path, contents, next_depth
				)

				if result == "break" then
					return
				elseif type(result) == "table" then
					if result.contents then
						contents = result.contents
					end

					if result.name then
						fs.removeFile(path)
						path = `{dir_path}/{result.name}`
					elseif result.path then
						fs.removeFile(path)
						path = result.path
					end

					fs.writeFile(path, contents)
				end
			else
				queue_len += 1
				DIRQUEUE[queue_len] = {
					depth = next_depth,
					path = path,
				}
			end
        end
    end

	table.clear(DIRQUEUE)
end

return iter_dir
