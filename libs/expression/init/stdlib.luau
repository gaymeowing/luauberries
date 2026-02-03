--[[
	stdlib
	collects math methods and constants
]]

local random = require("@libs/random")

export type MathMethod = (...number) -> number

local METHOD_TO_REQUIRED_ARGUMENTS: { [string]: number } = {
	randominteger = 0,
	randomint = 0,
	rngint = 0,
	random = 0,
	rng = 0,
	ln = 1,
}
local METHODS: { [string]: MathMethod } = {
	randominteger = random.integer :: any,
	randomint = random.integer :: any,
	rngint = random.integer :: any,
	random = random.float :: any,
	rng = random.float :: any,
	ln = math.log10 :: any,
}

local CONSTANTS: { [string]: number? } = {
	infinity = math.huge,
	tau = math.pi * 2,
	inf = math.huge,
	e = math.exp(1),
}

local HIGHEST_ARGUMENT_COUNT = 0
local arguments = table.create(4)

for name, value in math :: { [string]: MathMethod | number } do
	-- ignoring any entry with a digit in its name, because we cant use it
	if string.find(name, "%d", 1) then
		continue
	-- ignoring random methods
	elseif string.find(name, "random", 1, true) then
		continue
	end

	if type(value) == "number" then
		CONSTANTS[name] = value
		continue
	end

	local argument_count = 0
	local success, result = pcall(value :: any)

	if not success then
		while not success do
			argument_count += 1
			arguments[argument_count] = 1
			success, result = pcall(value :: any, table.unpack(arguments))
		end
		table.clear(arguments)
	end

	-- we don't allow methods that don't return a number
	if type(result) ~= "number" then
		continue
	end

	METHOD_TO_REQUIRED_ARGUMENTS[name] = argument_count
	METHODS[name] = value

	if argument_count > HIGHEST_ARGUMENT_COUNT then
		HIGHEST_ARGUMENT_COUNT = argument_count
	end
end

return table.freeze({
	METHOD_TO_REQUIRED_ARGUMENTS = table.freeze(METHOD_TO_REQUIRED_ARGUMENTS),
	HIGHEST_ARGUMENT_COUNT = HIGHEST_ARGUMENT_COUNT,
	CONSTANTS = table.freeze(CONSTANTS),
	METHODS = table.freeze(METHODS),
})
