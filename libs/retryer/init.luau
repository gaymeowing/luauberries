--!native

--[[
	retryer
	utility module for retrying functions easily
]]

local cross = require("@libs/cross")

local WAIT = cross.wait

local retryer = {}

function retryer.create<A..., R...>(
	max_attempts: number,
	f: (A...) -> (R...),
	...: A...
): (boolean, R...)
	local results: { any } = { pcall(f, ...) }
	local success = results[1]

	if not success then
		local attempts = 1

		repeat
			WAIT()
			results = { pcall(f, ...) }
			success = results[1]
			attempts += 1
		until success or attempts == max_attempts
	end
	return success, table.unpack(results, 2)
end

function retryer.infinite_delay<A..., R...>(delay: number, f: (A...) -> (R...), ...: A...): R...
	local results: { any } = { pcall(f, ...) }
	local success = results[1]

	if not success then
		repeat
			WAIT(delay)
			results = { pcall(f, ...) }
			success = results[1]
		until success
	end
	return unpack(results, 2)
end

function retryer.infinite_exponent<A..., R...>(
	delay: number,
	delay_exponent: number,
	f: (A...) -> (R...),
	...: A...
): R...
	local results: { any } = { pcall(f, ...) }
	local success = results[1]

	if not success then
		local attempts = 1

		repeat
			WAIT(delay + (delay_exponent ^ attempts))
			results = { pcall(f, ...) }
			success = results[1]
			attempts += 1
		until success
	end
	return unpack(results, 2)
end

function retryer.delay<A..., R...>(
	delay: number,
	max_attempts: number,
	f: (A...) -> (R...),
	...: A...
): (boolean, R...)
	local results: { any } = { pcall(f, ...) }
	local success = results[1]

	if not results[1] then
		local attempts = 1

		repeat
			WAIT(delay)
			results = { pcall(f, ...) }
			success = results[1]
			attempts += 1
		until success or attempts == max_attempts
	end
	return success, unpack(results, 2)
end

function retryer.exponent<A..., R...>(
	delay: number,
	delay_exponent: number,
	max_attempts: number,
	f: (A...) -> (R...), ...: A...
): (boolean, R...)
	local results: { any } = { pcall(f, ...) }
	local success = results[1]

	if not results[1] then
		local attempts = 1

		repeat
			WAIT(delay + (delay_exponent ^ attempts))
			results = { pcall(f, ...) }
			success = results[1]
			attempts += 1
		until success or attempts == max_attempts
	end
	return success, unpack(results, 2)
end

function retryer.infinite<A..., R...>(f: (A...) -> (R...), ...: A...): R...
	local results: { any } = { pcall(f, ...) }
	local success = results[1]

	if not success then
		repeat
			WAIT()
			results = { pcall(f, ...) }
			success = results[1]
		until success
	end
	return unpack(results, 2)
end

return table.freeze(retryer)
