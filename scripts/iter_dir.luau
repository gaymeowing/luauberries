
--[[
	iter dir
	recursively iterates over a directory and 
	calls a callback that can then optionally move or change the contents of the file
]]

local read_dir = require("@scripts/read_dir")
local remove = require("@scripts/remove")
local fs = require("@lune/fs")

type BaseFileInfo<N, P, C = (string | buffer)?> = {
	contents: C,
	path: P,
	name: N,
}

export type OptionalFileInfo = 
	| BaseFileInfo<string, nil>
	| BaseFileInfo<nil, string>
	| BaseFileInfo<nil, nil>

type IterDirCallback = ((name: string, path: string, contents: string) -> (OptionalFileInfo | "break" | "continue")?) |
	((name: string, path: string, contents: string) -> ())

local DIRQUEUE = {}

local function iter_dir(dir: string, f: IterDirCallback)
	local queue_len = 1
	DIRQUEUE[1] = dir

	while queue_len ~= 0 do
        local dir = remove(DIRQUEUE, queue_len)
        queue_len -= 1

        for _, entry in read_dir(dir) do
            local path = `{dir}/{entry}`

			if fs.isFile(path) then
				local contents = fs.readFile(path)
				local result = f(
					string.match(entry, "[^%.]+") or "", 
					path, contents
				)

				if result == "break" then
					return
				elseif type(result) == "table" then
					if result.contents then
						contents = result.contents
					end

					if result.name then
						fs.removeFile(path)
						fs.writeFile(`{dir}/{result.name}`, contents)
					elseif result.path then
						fs.removeFile(path)
						fs.writeFile(result.path, contents)
					end
				end
			else
				queue_len += 1
				DIRQUEUE[queue_len] = path
			end
        end
    end

	table.clear(DIRQUEUE)
end

return iter_dir
