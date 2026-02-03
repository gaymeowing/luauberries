--[[
	expression
	math expression string parsing thingy
]]

local evaluate = require("@self/evaluate")
local stdlib = require("@self/stdlib")

export type SingleEvaluationResult = evaluate.SingleEvaluationResult
export type MultiEvaluationResult = evaluate.MultiEvaluationResult

local expression = {
	highest_argument_count = stdlib.HIGHEST_ARGUMENT_COUNT,
	evaluate = evaluate,
}

--[[
	Gives an array of every constant name
]]
function expression.get_constant_names(): { string }
	local constant_names = {} :: { string }

	for constant_name in stdlib.CONSTANTS do
		if type(constant_name) == "string" then
			table.insert(constant_names, constant_name)
		end
	end
	return constant_names
end

--[[
	Gives an array of every method name
]]
function expression.get_method_names(): { string }
	local method_names = {} :: { string }

	for method_name in stdlib.METHODS do
		table.insert(method_names, method_name)
	end
	return method_names
end

return table.freeze(expression)
