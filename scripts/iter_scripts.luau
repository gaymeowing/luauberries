
--[[
	iter scripts
	recursively iterates over every luau file in a directory
	and calls a callback that can then optionally overwrite the file
]]

local ends_with = require("@scripts/ends_with")
local iter_dir = require("@scripts/iter_dir")

type IterScriptsCallback = ((path: string, src: string, depth: number) -> string?) |
	((path: string, src: string, depth: number) -> ())

local function iter_scripts(dir: string, f: IterScriptsCallback)
	iter_dir(dir, function(_, path, content, depth)
		if ends_with(path, ".luau") then
			local new_src = f(path, content, depth)

			if new_src then
				return {
					contents = new_src
				}
			end
		end
		return nil :: any
	end :: any)
end

return iter_scripts
