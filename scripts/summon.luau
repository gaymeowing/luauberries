
--[[
	summon
	small wrapper around lunes process.spawn, that makes it actually error
	and sets the shell to the default shell of the os (except macos because it still has bash and bash works fine enough)
]]

local process = require("@lune/process")

local SHELL = if process.os == "windows" then "powershell" else "bash"
local ENV = {}
local OPTS = {
	shell = SHELL,
	env = ENV
}

local function summon(program: string, env: { [string]: string }?): string
	local result = process.exec(
		program, nil, (if env then { shell = SHELL, env = env } else OPTS) :: any
	)

	if result.ok then
		return result.stdout
	else
		error(result.stderr, 2)
	end
end

do

	for key, value in process.env do
		ENV[key] = value
	end

end

return summon
