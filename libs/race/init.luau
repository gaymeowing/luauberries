
--[[
	race
	a function for getting the first return out of a vararg of functions
]]

local cross = require("@libs/cross")

local function callback_handler<A..., R...>(
	f: (A...) -> R..., threads: { thread }, 
	main_thread: thread, ...: A...
)
	local callback_thread = coroutine.running()
	local results = { f(...) }

	for _, thread in threads do
		if thread ~= callback_thread then
			local success = coroutine.close(thread)

			if not success then
				warn(debug.traceback(thread, "[RACE] an error occured whilst trying to close thread"))
			end
		end
	end
	
	cross.spawn(main_thread, table.unpack(results, 1))
end

local function race<A..., R...>(callbacks: { (A...) -> R... }, ...: A...): R...
	local threads = table.create(#callbacks) :: { thread }
	local main_thread = coroutine.running()

	for index, f in callbacks do
		threads[index] = cross.spawn(callback_handler, f, threads, main_thread, ...)
	end

	return coroutine.yield()
end

return race
