
--[[
	deep iter scripts
	recursively iterates over every luau file in a directory
	and calls a callback that can then optionally overwrite the file
]]

local deep_iter_dir = require("@scripts/deep_iter_dir")

type IterScriptsCallback = ((path: string, src: string, depth: number) -> string?) |
	((path: string, src: string, depth: number) -> ())

local function deep_iter_scripts(dir: string, f: IterScriptsCallback)
	deep_iter_dir(dir, function(_, path, content, depth)
		if string.sub(path, 1, #path - 5) == ".luau" then
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

return deep_iter_scripts
