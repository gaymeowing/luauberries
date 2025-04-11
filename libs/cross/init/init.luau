--!nocheck
--!nolint

--[[
	cross
	basic cross runtime utility, covering the bear nessisities
]]

local cross_task = require("@self/task")
local cross_warn = require("@self/warn")

type Runtime = "Roblox" | "Lune" | "Unknown" | "Lute"

local RUNTIME: Runtime = if game and workspace then
		"Roblox"
	elseif string.find(_VERSION, "Lute") then
		"Lute"
	elseif string.find(_VERSION, "Lune") then
		"Lune"
	else
		"Unknown"

local STD_TASK_EXISTS, STD_TASK = pcall(require, "@std/task")
local WARN: typeof(cross_warn) = warn or cross_warn
local TASK: typeof(cross_task) = if task then 
		task 
	elseif STD_TASK_EXISTS then
		STD_TASK
	elseif RUNTIME == "Lune" then 
		(require)("@lune/task") 
	else 
		cross_task

do

	local function SET_G(key: string, value: unknown)
		if not _G[key] then
			_G[key] = value
		end
	end

	if not _RUNTIME then
		SET_G("_RUNTIME", RUNTIME)
		_RUNTIME = RUNTIME
	end

	if not warn then
		SET_G("warn", WARN)
		warn = WARN
	end

	if not task then
		SET_G("task", TASK)
		task = TASK
	end

end

return table.freeze({
	cancel = TASK.cancel,
	spawn = TASK.spawn,
	defer = TASK.defer,
	delay = TASK.delay,
	runtime = RUNTIME,
	wait = TASK.wait,
	warn = WARN,
})