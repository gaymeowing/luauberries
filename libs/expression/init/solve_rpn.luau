
local evaluate_error = require("./evaluate_error")
local stdlib = require("./stdlib")
local types = require("./types")

local METHOD_TO_REQUIRED_ARGUMENTS = stdlib.METHOD_TO_REQUIRED_ARGUMENTS
local HIGHEST_ARGUMENT_COUNT = stdlib.HIGHEST_ARGUMENT_COUNT
local METHOD_ARGUMENTS = table.create(HIGHEST_ARGUMENT_COUNT)
local METHODS = stdlib.METHODS

local function solve_rpn(rpn: types.RPN, solve_stack: { number }): number
	local solve_stack_length = 0

	for _, token in rpn do
		if type(token) == "number" then
			solve_stack_length += 1
			solve_stack[solve_stack_length] = token
		elseif token == "+" then
			local b = solve_stack[solve_stack_length]
			solve_stack_length -= 1
			solve_stack[solve_stack_length] += b
		elseif token == "-" then
			local b = solve_stack[solve_stack_length]
			solve_stack_length -= 1
			solve_stack[solve_stack_length] -= b
		elseif token == "*" then
			local b = solve_stack[solve_stack_length]
			solve_stack_length -= 1
			solve_stack[solve_stack_length] *= b
		elseif token == "/" then
			local b = solve_stack[solve_stack_length]
			solve_stack_length -= 1
			solve_stack[solve_stack_length] /= b
		elseif token == "unary-" then
			solve_stack[solve_stack_length] = -solve_stack[solve_stack_length]
		elseif token == "^" then
			local b = solve_stack[solve_stack_length]
			solve_stack_length -= 1
			solve_stack[solve_stack_length] ^= b
		elseif token == "%of" then
			solve_stack[solve_stack_length] /= 100
		elseif token == "|" then
			solve_stack[solve_stack_length] = math.abs(solve_stack[solve_stack_length])
		elseif token == "%" then
			local b = solve_stack[solve_stack_length]
			solve_stack_length -= 1
			solve_stack[solve_stack_length] %= b
		else -- method
			local method_name = token.name
			local required_arguments = METHOD_TO_REQUIRED_ARGUMENTS[method_name]
			local total_arguments = token.total_arguments

			if total_arguments < required_arguments then
				evaluate_error("NotEnoughArgumentsForMethod", {
					required_argument_amount = required_arguments,
					given_argument_amount = total_arguments,
					offset = token.offset,
					method = method_name,
				})
			end
			local method = METHODS[method_name]

			-- inlining cases for argument counts as it'll be faster than using a table
			if total_arguments == 0 then
				solve_stack_length += 1
				solve_stack[solve_stack_length] = method()
			elseif total_arguments == 1 then
				solve_stack[solve_stack_length] = method(solve_stack[solve_stack_length])
			elseif total_arguments == 2 then
				local b = solve_stack[solve_stack_length]
				solve_stack_length -= 1
				local a = solve_stack[solve_stack_length]
				solve_stack[solve_stack_length] = method(a, b)
			elseif total_arguments == 3 then
				local c = solve_stack[solve_stack_length]
				solve_stack_length -= 1
				local b = solve_stack[solve_stack_length]
				solve_stack_length -= 1
				local a = solve_stack[solve_stack_length]
				solve_stack[solve_stack_length] = method(a, b, c)
			-- the highest amount of used arguments for a method on the math library is currently 4
			elseif total_arguments == 4 then
				local d = solve_stack[solve_stack_length]
				solve_stack_length -= 1
				local c = solve_stack[solve_stack_length]
				solve_stack_length -= 1
				local b = solve_stack[solve_stack_length]
				solve_stack_length -= 1
				local a = solve_stack[solve_stack_length]
				solve_stack[solve_stack_length] = method(a, b, c, d)
			elseif total_arguments <= HIGHEST_ARGUMENT_COUNT then
				-- the first one we don't pop because its more work
				-- because we just immediately push back into the top slot there
				-- so we don't gotta subtract from solve_stack_length
				for index = total_arguments, 2, -1 do
					METHOD_ARGUMENTS[index] = solve_stack[solve_stack_length]
					solve_stack_length -= 1
				end
				METHOD_ARGUMENTS[1] = solve_stack[solve_stack_length]

				solve_stack[solve_stack_length] = method(table.unpack(METHOD_ARGUMENTS))
				table.clear(METHOD_ARGUMENTS)
			else
				local arguments = table.create(total_arguments)

				for index = total_arguments, 2, -1 do
					arguments[index] = solve_stack[solve_stack_length]
					solve_stack_length -= 1
				end
				arguments[1] = solve_stack[solve_stack_length]
				solve_stack[solve_stack_length] = method(table.unpack(arguments))
			end
		end
	end

	if solve_stack_length ~= 1 then
		evaluate_error("SolveStackHasTooManyValuesLeft", {})
	end
	return solve_stack[solve_stack_length]
end

return solve_rpn
