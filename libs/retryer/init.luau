--!native

--[[
	Retryer
	Utility for retrying functions easily
]]

local cross = require("@libs/cross")

local WAIT = cross.wait

local retryer = {}

--[[
	Retries the function with the given arguments `...` using [pcall](https://luau.org/library#global-functions)
	until it no-longer errors, or if `max_retries` has been hit.

	If the function succeeds, returns true and the results of the function.
	If the function still raises an error after `max_retries` was hit, returns false and the error string.
]]
function retryer.retry<A..., R...>(
	max_retries: number,
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
		until success or attempts == max_retries
	end
	return success, table.unpack(results, 2)
end

--[[
	Retries the function with the given arguments `...` using [pcall](https://luau.org/library#global-functions)
	until it no-longer errors indefinitely.
	With a `delay` between retries.

	Returns the results of the function.
]]
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
	return table.unpack(results, 2)
end

--[[
	Retries the function with the given arguments `...` using [pcall](https://luau.org/library#global-functions)
	until it no-longer errors, or if `max_retries` has been hit.
	With a `delay` between retries that exponentially increases by `delay_exponent` each retry.

	Returns the results of the function.
]]
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
	return table.unpack(results, 2)
end

--[[
	Retries the function with the given arguments `...` using [pcall](https://luau.org/library#global-functions)
	until it no-longer errors, or if `max_retries` has been hit.
	With a `delay` between retries.

	If the function succeeds, returns true and the results of the function.
	If the function still raises an error after `max_retries` was hit, returns false and the error string.
]]
function retryer.delay<A..., R...>(
	delay: number,
	max_retries: number,
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
		until success or attempts == max_retries
	end
	return success, table.unpack(results, 2)
end

--[[
	Retries the function with the given arguments `...` using [pcall](https://luau.org/library#global-functions)
	until it no-longer errors, or if `max_retries` has been hit.
	With a `delay` between retries that exponentially increases by `delay_exponent` each retry.

	If the function succeeds, returns true and the results of the function.
	If the function still raises an error after `max_retries` was hit, returns false and the error string.
]]
function retryer.exponent<A..., R...>(
	delay: number,
	delay_exponent: number,
	max_retries: number,
	f: (A...) -> (R...),
	...: A...
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
		until success or attempts == max_retries
	end
	return success, table.unpack(results, 2)
end

--[[
	Retries the function with the given arguments `...` using [pcall](https://luau.org/library#global-functions)
	until it no-longer errors indefinitely.

	Returns the results of the function.
]]
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
	return table.unpack(results, 2)
end

return table.freeze(retryer)
