
--[[
	summon
	small wrapper around lunes process.spawn, that makes it actually error
	and sets the shell to the default shell of the os
]]

local process = require("@lune/process")

local function CLONE<V>(t: { V }): { V }
	local clone = {}

	for key, value in t do
		clone[key] = value
	end
	return clone
end

local OPTS = {
	shell = if process.os == "windows" then "powershell" else "bash",
	env = CLONE(process.env :: any)
}

local function summon(program: string, args: string?): string
	local result = process.create(program, { args or "" }, OPTS)

	if not result:status().ok then
		error(result.stderr, 2)
	end
	return result.stdout:readToEnd()
end

return summon
