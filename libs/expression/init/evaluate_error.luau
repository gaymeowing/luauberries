
-- error
-- exists to use instead of the normal error global for evaluate
-- because i want types with error_info

local types = require("./types")

local function evaluate_error<T>(type: T & types.ErrorType, error_info: types.GetErrorForErrorType<T>): never
	(error_info :: any).type = type
	error(table.freeze((error_info)), 2)
end

return evaluate_error
