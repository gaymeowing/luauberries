
--[[
	task
	a good enough pure luau version of roblox's task lib
	that doesn't require wrapping ur whole script in a
	task.spawn or anything
]]

local function SPAWN<A..., R...>(
	thread_or_func: thread | (A...) -> R...,
	...: A...
): thread
	if type(thread_or_func) == "thread" then
		coroutine.resume(thread_or_func, ...)
		return thread_or_func
	else
		local thread = coroutine.create(thread_or_func)
		coroutine.resume(thread, ...)
		return thread
	end
end

local function WAIT(seconds: number?): number
	local start_time = os.clock()
	local end_time = start_time + (seconds or 1)
	local clock_time: number

	repeat
		clock_time = os.clock()
	until clock_time >= end_time
	return clock_time - start_time
end

local task = {
	defer = SPAWN,
	spawn = SPAWN,
	wait = WAIT,
}

function task.cancel(thread: thread)
	local success = coroutine.close(thread)

	if not success then
		error(debug.traceback(thread, "[TASK]: could not cancel thread"))
	end
end

function task.delay<A..., R...>(
	seconds: number,
	thread_or_func: thread | (A...) -> R...,
	...: A...
): thread
	return SPAWN(function(
		seconds: number,
		thread_or_func: thread | (A...) -> R...,
		...: A...
	)
		WAIT(seconds)

		if type(thread_or_func) == "thread" then
			coroutine.resume(thread_or_func, ...)
		else
			thread_or_func(...)
		end
	end, seconds, thread_or_func, ...)
end

return table.freeze(task)
