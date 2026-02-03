--!optimize 2

--[[
	evaluate
	processes string math equations
]]

local evaluate_error = require("./evaluate_error")
local solve_rpn = require("./solve_rpn")
local stdlib = require("./stdlib")
local types = require("./types")

type BaseEvaluationResult<R, S, E> = {
	read success: S,
	read result: R,
	read error: E,
}

-- stylua: ignore
export type SingleEvaluationResult =
	| BaseEvaluationResult<number, true, nil>
	| BaseEvaluationResult<nil, false, types.Error>

-- stylua: ignore
export type MultiEvaluationResult =
	| BaseEvaluationResult<{ number }, true, nil>
	| BaseEvaluationResult<nil, false, types.Error>

local CONSTANTS = stdlib.CONSTANTS
local METHODS = stdlib.METHODS

local PAREN_OPENING = string.byte("(")
local PAREN_CLOSING = string.byte(")")
local VERTICAL_LINE = string.byte("|")
local UNDERSCORE = string.byte("_")
local UPPER_B = string.byte("B")
local LOWER_B = string.byte("b")
local UPPER_X = string.byte("X")
local LOWER_X = string.byte("x")
local PERIOD = string.byte(".")
local COMMA = string.byte(",")
local ZERO = string.byte("0")
local ONE = string.byte("1")
local POW = string.byte("^")
local DIV = string.byte("/")
local MUL = string.byte("*")
local SUB = string.byte("-")
local ADD = string.byte("+")
local MOD = string.byte("%")

local STARTING_STACK_ALLOC_SIZE = 20
local MAX_RPN_ALLOC_SIZE = 30
local MAX_DIGITS = 100
local MAX_DIGIT_INDEX = MAX_DIGITS - 1

local POW_PRECEDENCE = 4
local UNARY_PERCENT_OF_PRECEDENCE = 3
local MUL_DIV_MOD_PRECEDENCE = 2
local ADD_SUB_PRECEDENCE = 1

local SOLVE_STACK = table.create(STARTING_STACK_ALLOC_SIZE) :: { number }
local RPN = table.create(MAX_RPN_ALLOC_SIZE) :: { types.RPNValue }
local NUMBER_BUFFER = buffer.create(MAX_DIGITS)
local ABS_AT_DEPTH = {} :: { [number]: true? }
local YARD = {} :: { types.SYValue }
local LOOKBEHIND: types.Token?
local EXPECT_VALUE = true
local EQUATION: string
local YARD_LENGTH = 0
local RPN_LENGTH = 0
local OFFSET = 1
local DEPTH = 0

local function GET_PRECEDENCE(operation: types.Operation): number
	-- stylua: ignore
	return if operation == "+" or operation == "-" then
			ADD_SUB_PRECEDENCE
		elseif operation == "*" or operation == "/" or operation == "%" then
			MUL_DIV_MOD_PRECEDENCE
		elseif operation == "^" then
			POW_PRECEDENCE
		elseif operation == "unary-" or operation == "%of" then
			UNARY_PERCENT_OF_PRECEDENCE
		else
			0
end

local function ASSERT_EXPECT_VALUE(token: types.TokensThatExpectAValue)
	if EXPECT_VALUE then
		evaluate_error("ExpectedValue", {
			expecting_token = LOOKBEHIND :: any,
			given_token = token,
			offset = OFFSET,
		})
	end
end

local function BYTE_AT(position: number): number
	return (string.byte(EQUATION, position, position))
end

local function IS_IN_RANGE(n: number, start: number, stop: number): boolean
	return n >= start and n <= stop
end

local function IS_ALPHANUMERIC(byte: number): boolean
	return IS_IN_RANGE(byte, 97, 122) or IS_IN_RANGE(byte, 65, 90)
end

local function IS_DIGIT(byte: number): boolean
	return IS_IN_RANGE(byte, 48, 57)
end

local function PUSH(v: types.SYValue)
	YARD_LENGTH += 1
	YARD[YARD_LENGTH] = v
end

local function OUT(rpn_value: types.RPNValue)
	RPN_LENGTH += 1
	RPN[RPN_LENGTH] = rpn_value
end

local function process_operation_right_associative(operation: types.Operation, operation_precedence: number)
	while YARD_LENGTH > 0 do
		local token = YARD[YARD_LENGTH]

		if token == "(" or token == "|" or type(token) ~= "string" then
			break
		end

		if GET_PRECEDENCE(token) > operation_precedence then
			OUT(token)
			YARD_LENGTH -= 1
		else
			break
		end
	end
	PUSH(operation)
end

-- non right associative
local function process_operation(operation: types.Operation, operation_precedence: number)
	while YARD_LENGTH > 0 do
		local token = YARD[YARD_LENGTH]

		if token == "(" or token == "|" or type(token) ~= "string" then
			break
		end

		if GET_PRECEDENCE(token) >= operation_precedence then
			OUT(token)
			YARD_LENGTH -= 1
		else
			break
		end
	end
	PUSH(operation)
end

local function process_precedence_2(operation: types.Precedence2Operation)
	ASSERT_EXPECT_VALUE(operation)
	process_operation(operation, MUL_DIV_MOD_PRECEDENCE)
	LOOKBEHIND = operation
	EXPECT_VALUE = true
end

local function DO_IMPLICIT_MULTIPLICATION()
	if not EXPECT_VALUE then
		process_operation("*", MUL_DIV_MOD_PRECEDENCE)
	end
end

local function is_valid_binary(byte: number): boolean
	return byte == ZERO or byte == ONE or byte == UNDERSCORE
end

local function is_valid_hex(byte: number): boolean
	-- stylua: ignore
	return IS_DIGIT(byte)
		or IS_IN_RANGE(byte, 97, 102)
		or IS_IN_RANGE(byte, 65, 70)
		or byte == UNDERSCORE
end

local function is_byte_whitespace(byte: number): boolean
	-- stylua: ignore
	return byte == string.byte(" ")
		or byte == string.byte("\n")
		or byte == 160
		or IS_IN_RANGE(byte, 9, 13)
end

local function is_bracket(byte: number): boolean
	-- stylua: ignore
	return byte == string.byte("{")
		or byte == string.byte("}")
		or byte == string.byte("[")
		or byte == string.byte("]")
end

local function is_codepoint_whitespace_with_first_byte_as_226(codepoint: number): boolean
	-- stylua: ignore
	return IS_IN_RANGE(codepoint, 0x2000, 0x200D)
		or codepoint == 0x2028
		or codepoint == 0x2029
		or codepoint == 0x202F
		or codepoint == 0x205F
end

--- all codepoint whitespace is 3 bytes
local function is_codepoint_whitespace(byte: number, codepoint: number): boolean
	return (byte == 226 and is_codepoint_whitespace_with_first_byte_as_226(codepoint))
		-- codepoints without their first byte as 226
		or (codepoint == 0x3000 or codepoint == 0x180E)
end

--- returns the byte after the skipped ignore characters
local function SKIP_IGNORED_CHARACTERS(): number?
	while OFFSET <= #EQUATION do
		local byte = BYTE_AT(OFFSET)

		if is_byte_whitespace(byte) or is_bracket(byte) then
			OFFSET += 1
		-- all codepoint whitespace is 3 bytes
		elseif is_codepoint_whitespace(byte, utf8.codepoint(EQUATION, OFFSET)) then
			OFFSET += 3
		else
			return byte
		end
	end

	return nil
end

local function close_possible_implicit_method()
	if YARD_LENGTH > 0 then
		local token = YARD[YARD_LENGTH]
		if type(token) == "table" and token.is_implicit then
			token.total_arguments = 1 -- implicit method calls can only have 1 argument
			YARD_LENGTH -= 1
			OUT(token)
		end
	end
end

local function get_is_implicit(): true?
	-- increasing OFFSET if theres a open paren, as we don't want the next token found to be the paren opening
	-- which then throws off the rpn conversion
	if SKIP_IGNORED_CHARACTERS() == PAREN_OPENING then
		OFFSET += 1
		return nil
	end
	return true
end

local function CREATE_METHOD_TOKEN(name: string, start: number, current_byte: number)
	LOOKBEHIND = {
		is_implicit = get_is_implicit(),
		total_arguments = 0,
		offset = start,
		name = name,
	}
	EXPECT_VALUE = true
	DEPTH += 1
	PUSH(LOOKBEHIND)
end

local function parse_constant_or_method(byte: number)
	-- NOTE: do NOT convert abs() calls to | as functions can be called with any amount of arguments
	local start = OFFSET
	OFFSET += 1

	while OFFSET <= #EQUATION do
		byte = BYTE_AT(OFFSET)

		if IS_ALPHANUMERIC(byte) then
			OFFSET += 1
		else
			break
		end
	end
	local identifier = string.sub(EQUATION, start, OFFSET - 1)
	local constant = CONSTANTS[identifier]

	if constant then
		DO_IMPLICIT_MULTIPLICATION()
		EXPECT_VALUE = false
		OUT(constant)
		return
	elseif METHODS[identifier] then
		DO_IMPLICIT_MULTIPLICATION()
		CREATE_METHOD_TOKEN(identifier, start, byte)
		return
	end
	identifier = string.lower(identifier)
	constant = CONSTANTS[identifier]

	if constant then
		DO_IMPLICIT_MULTIPLICATION()
		EXPECT_VALUE = false
		OUT(constant)
		return
	elseif METHODS[identifier] then
		DO_IMPLICIT_MULTIPLICATION()
		CREATE_METHOD_TOKEN(identifier, start, byte)
		return
	else
		evaluate_error("NonExistantConstantOrMethod", {
			provided_constant_or_method = identifier,
			offset = start,
		})
	end
end

local function proccess_closing_abs()
	ASSERT_EXPECT_VALUE("|")
	while YARD_LENGTH > 0 do
		local token = YARD[YARD_LENGTH]
		YARD_LENGTH -= 1

		if token ~= "|" then
			OUT(token :: any)
		else
			break
		end
	end

	ABS_AT_DEPTH[DEPTH] = nil -- need to set before decrementing
	DEPTH -= 1
	OUT("|")
	close_possible_implicit_method()
end

@native
local function add_character_to_number_buffer(start: number, digit_index: number, character: number)
	if digit_index > MAX_DIGIT_INDEX then
		evaluate_error("TooManyDigits", {
			offset = start,
		})
	end
	buffer.writeu8(NUMBER_BUFFER, digit_index, character)
end

@native
local function parse_format_number(validator: (byte: number) -> boolean, base: number): number
	local real_start = OFFSET
	OFFSET += 1
	local start = OFFSET
	local digit_index = 0

	while OFFSET <= #EQUATION do
		local next_byte = BYTE_AT(OFFSET)

		if validator(next_byte) then
			add_character_to_number_buffer(start, digit_index, next_byte)
			digit_index += 1
		elseif next_byte ~= UNDERSCORE then
			break
		end
		OFFSET += 1
	end

	-- erroring if the number is literally just 0x or 0b
	if start == OFFSET then
		evaluate_error("MalformedNumber", {
			offset = real_start,
		})
	end
	return tonumber(buffer.readstring(NUMBER_BUFFER, 0, digit_index), base) :: any
end

@native
local function parse_normal_number(byte: number, has_decimal: boolean, decimal_byte: number): number
	local digit_index = 1
	local start = OFFSET
	OFFSET += 1

	-- don't remove this, we need to write the first byte manually because the loop won't do it
	-- this note exists because im stupid and forgot this lol
	buffer.writeu8(NUMBER_BUFFER, 0, byte)

	while OFFSET <= #EQUATION do
		local next_byte = BYTE_AT(OFFSET)

		if IS_DIGIT(next_byte) then
			add_character_to_number_buffer(start, digit_index, next_byte)
			digit_index += 1
		elseif next_byte == decimal_byte then
			if not has_decimal then
				add_character_to_number_buffer(start, digit_index, PERIOD)
				digit_index += 1
				has_decimal = true
			else
				evaluate_error("MoreThanOneDecimalPoint", {
					offset = start,
				})
			end
		elseif next_byte ~= UNDERSCORE then
			break
		end

		OFFSET += 1
	end

	return tonumber(buffer.readstring(NUMBER_BUFFER, 0, digit_index)) :: number
end

local function process_number(n: number)
	DO_IMPLICIT_MULTIPLICATION()
	EXPECT_VALUE = false
	LOOKBEHIND = n
	OUT(n)
	close_possible_implicit_method()
end

-- parses "10%"
local function parse_percentage_after_number(decimal_byte: number, n: number)
	local byte = SKIP_IGNORED_CHARACTERS()

	while OFFSET <= #EQUATION do
		if byte ~= MOD then
			break
		end
		OFFSET += 1
		byte = SKIP_IGNORED_CHARACTERS()

		if
			byte
			and (
				IS_DIGIT(byte)
				or byte == decimal_byte
				or byte == PAREN_OPENING
				or (byte == VERTICAL_LINE and not ABS_AT_DEPTH[DEPTH])
				or (IS_ALPHANUMERIC(byte))
			)
		then
			DO_IMPLICIT_MULTIPLICATION()
			OUT(n)
			process_operation("%", MUL_DIV_MOD_PRECEDENCE)
			EXPECT_VALUE = true
			LOOKBEHIND = "%"
			return
		end

		n /= 100
		byte = SKIP_IGNORED_CHARACTERS()
	end
	process_number(n)
end

local function process_comma()
	ASSERT_EXPECT_VALUE(",")

	if ABS_AT_DEPTH[DEPTH] then
		ABS_AT_DEPTH[DEPTH] = nil
		DEPTH -= 1
	end
	EXPECT_VALUE = true
	LOOKBEHIND = ","

	-- method argument comma
	while YARD_LENGTH > 0 do
		local token = YARD[YARD_LENGTH]

		if token == "(" then
			for index = YARD_LENGTH, 1, -1 do
				local token = YARD[index]

				if type(token) == "table" then
					token.total_arguments += 1
					return
				end
			end
			return
		elseif type(token) == "table" then
			token.total_arguments += 1
			return
		end
		YARD_LENGTH -= 1
		OUT(token)
	end

	evaluate_error("NonTopLevelCommaNotInMethod", { offset = OFFSET - 1 })
end

local function parse_paren_closing()
	if DEPTH == 0 then
		evaluate_error("InvalidClosingParenthese", { offset = OFFSET })
	elseif EXPECT_VALUE and type(YARD[YARD_LENGTH]) ~= "table" then
		evaluate_error("ExpectedValue", {
			expecting_token = "(" :: any,
			given_token = ")" :: any,
			offset = OFFSET,
		})
	end
	OFFSET += 1

	if ABS_AT_DEPTH[DEPTH] then
		ABS_AT_DEPTH[DEPTH] = nil
		DEPTH -= 2
	else
		DEPTH -= 1
	end

	-- Pop operators until we hit (
	while YARD_LENGTH > 0 do
		local token = YARD[YARD_LENGTH]
		YARD_LENGTH -= 1

		if token == "(" then
			break
		elseif type(token) == "table" then
			if LOOKBEHIND ~= token and LOOKBEHIND ~= ")" then
				token.total_arguments += 1
			end
			OUT(token)

			-- Increment parent method if we find one
			for index = YARD_LENGTH, 1, -1 do
				local parent_token = YARD[index]

				if parent_token == "(" or parent_token == "|" then
					break
				elseif type(parent_token) == "table" then
					parent_token.total_arguments += 1
					break
				end
			end
			break
		end
		OUT(token)
	end
	EXPECT_VALUE = false
	LOOKBEHIND = ")"
end

local function parse_percent_ofs(decimal_byte: number)
	PUSH("%of")
	local byte = SKIP_IGNORED_CHARACTERS()

	while byte == MOD and OFFSET <= #EQUATION do
		PUSH("%of")
		OFFSET += 1
		byte = SKIP_IGNORED_CHARACTERS()

		if
			byte
			and (
				IS_DIGIT(byte)
				or byte == decimal_byte
				or byte == PAREN_OPENING
				or (byte == VERTICAL_LINE and not ABS_AT_DEPTH[DEPTH])
				or (IS_ALPHANUMERIC(byte))
			)
		then
			break
		end
		byte = SKIP_IGNORED_CHARACTERS()
	end
	EXPECT_VALUE = true
end

-- argument_separator
local function parse_into_rpn(argument_separator_byte: number, decimal_byte: number): boolean
	local has_more = false

	while OFFSET <= #EQUATION do
		local byte = BYTE_AT(OFFSET)

		if byte == ADD then
			if not EXPECT_VALUE then
				process_operation("+", ADD_SUB_PRECEDENCE)
				EXPECT_VALUE = true
			end
			LOOKBEHIND = "+"
			OFFSET += 1
		elseif byte == SUB then
			if EXPECT_VALUE then
				PUSH("unary-")
			else
				process_operation("-", ADD_SUB_PRECEDENCE)
				EXPECT_VALUE = true
			end
			LOOKBEHIND = "-"
			OFFSET += 1
		-- supporting using x for multiplication, because 3 yr olds might need it idk
		elseif byte == MUL or ((byte == LOWER_X or byte == UPPER_X) and not IS_ALPHANUMERIC(BYTE_AT(OFFSET + 1))) then
			process_precedence_2("*")
			OFFSET += 1
		elseif byte == DIV then
			process_precedence_2("/")
			OFFSET += 1
		elseif byte == PAREN_OPENING then
			DO_IMPLICIT_MULTIPLICATION()
			EXPECT_VALUE = true
			LOOKBEHIND = "("
			DEPTH += 1
			PUSH("(")
			OFFSET += 1
		elseif byte == PAREN_CLOSING then
			parse_paren_closing()
		elseif byte == decimal_byte then
			if OFFSET == #EQUATION then
				OFFSET += 1
				break
			end
			parse_percentage_after_number(decimal_byte, parse_normal_number(PERIOD, true, decimal_byte))
		elseif IS_DIGIT(byte) then
			if OFFSET == #EQUATION then
				LOOKBEHIND = tonumber(string.sub(EQUATION, #EQUATION, #EQUATION)) :: number
				process_number(LOOKBEHIND :: any)
				OFFSET += 1
				break
			elseif byte == ZERO then
				local format_specifier = BYTE_AT(OFFSET + 1)

				if format_specifier == LOWER_X or format_specifier == UPPER_X then
					parse_percentage_after_number(decimal_byte, parse_format_number(is_valid_hex, 16))
					continue
				elseif format_specifier == LOWER_B or format_specifier == UPPER_B then
					parse_percentage_after_number(decimal_byte, parse_format_number(is_valid_binary, 2))
					continue
				end
			end
			parse_percentage_after_number(decimal_byte, parse_normal_number(byte, false, decimal_byte))
		elseif is_byte_whitespace(byte) then
			OFFSET += 1
			continue
		elseif byte == POW then
			ASSERT_EXPECT_VALUE("^")
			OFFSET += 1
			process_operation_right_associative("^", POW_PRECEDENCE)
			EXPECT_VALUE = true
			LOOKBEHIND = "^"
		elseif byte == MOD then
			OFFSET += 1
			if
				LOOKBEHIND == ")"
				or (LOOKBEHIND == VERTICAL_LINE and not ABS_AT_DEPTH[DEPTH])
				or type(LOOKBEHIND) == "number"
			then
				process_precedence_2("%")
			else -- some weirdos around the world decide to write percentages like "%10"
				parse_percent_ofs(decimal_byte)
			end
			LOOKBEHIND = "%"
		elseif byte == argument_separator_byte then
			-- breaking for top level commas
			-- so if someone wanted to use expression for like parsing a CFrame property "{1, 2, 3}, {1, 2, 3}"
			-- expression wont give 36, and will instead give {1, 2, 3, 1, 2, 3}
			OFFSET += 1
			if DEPTH == 0 then
				has_more = true
				break
			end
			process_comma()
		elseif IS_ALPHANUMERIC(byte) then
			parse_constant_or_method(byte)
		elseif byte == VERTICAL_LINE then
			local has_abs_at_paren_depth = ABS_AT_DEPTH[DEPTH]

			if has_abs_at_paren_depth then -- closing abs bar
				proccess_closing_abs()
			else -- opening abs bar
				DO_IMPLICIT_MULTIPLICATION()
				DEPTH += 1 -- need to increase before setting ABS_AT_DEPTH
				ABS_AT_DEPTH[DEPTH] = true
				EXPECT_VALUE = true
				PUSH("|")
			end
			LOOKBEHIND = "|"
			OFFSET += 1
		-- we allow brackets as they're kinda meaningless and roblox studio uses them for CFrames in the properties widget
		elseif is_bracket(byte) then
			OFFSET += 1
			continue
		else
			local codepoint = utf8.codepoint(EQUATION, OFFSET)

			if is_codepoint_whitespace(byte, codepoint) then
				OFFSET += 3
				continue
			end
			evaluate_error("InvalidCodepoint", { offset = OFFSET })
		end
	end

	for index = YARD_LENGTH, 1, -1 do
		local token = YARD[index]

		if token ~= "(" then
			if type(token) == "table" and LOOKBEHIND ~= "," and LOOKBEHIND ~= token then
				token.total_arguments += 1
			end
			OUT(token)
		end
	end
	return has_more
end

local function get_argument_seperator_and_decimal(swap_decimal_and_comma: boolean?): (number, number)
	if swap_decimal_and_comma then
		return PERIOD, COMMA
	end
	return COMMA, PERIOD
end

local function clear_state()
	EXPECT_VALUE = true
	LOOKBEHIND = nil
	YARD_LENGTH = 0
	RPN_LENGTH = 0
	DEPTH = 0
end

local function clear_rpn()
	if RPN_LENGTH > MAX_RPN_ALLOC_SIZE then
		RPN = table.create(MAX_RPN_ALLOC_SIZE) :: typeof(RPN)
	else
		table.clear(RPN)
	end
	RPN_LENGTH = 0
end

local function multiple(max_results: number, swap_decimal_and_comma: boolean?)
	local argument_separator_byte, decimal_byte = get_argument_seperator_and_decimal(swap_decimal_and_comma)
	local results = table.create(max_results)
	local should_allocate_rpn = false
	local results_index = 0
	local has_more = true

	while has_more and results_index < max_results do
		clear_state()
		has_more = parse_into_rpn(argument_separator_byte, decimal_byte)
		results_index += 1
		results[results_index] = solve_rpn(RPN, SOLVE_STACK)

		if RPN_LENGTH > MAX_RPN_ALLOC_SIZE then
			should_allocate_rpn = true
		end
		table.clear(RPN)
	end

	if should_allocate_rpn then
		RPN = table.create(MAX_RPN_ALLOC_SIZE) :: typeof(RPN)
		RPN_LENGTH = 0
	end
	return results
end

local function single(swap_decimal_and_comma: boolean?)
	clear_state()
	parse_into_rpn(get_argument_seperator_and_decimal(swap_decimal_and_comma))
	local result = solve_rpn(RPN, SOLVE_STACK)
	clear_rpn()
	return result
end

local function handle_error(error_info: types.Error): types.Error
	return error_info
end

local function evaluate(
	equation: string,
	max_results: number?,
	swap_decimal_and_comma: boolean?
): MultiEvaluationResult | SingleEvaluationResult
	EQUATION = equation
	OFFSET = 1

	local success, result

	if max_results then
		if max_results < 1 then
			error("[EVALUATE]: max_results cannot be less than 1 if provided")
		end
		success, result = xpcall(multiple, handle_error, max_results, swap_decimal_and_comma)
	else
		success, result = xpcall(single, handle_error, swap_decimal_and_comma)
	end

	if success then
		return table.freeze({
			result = result :: any,
			success = true,
		}) :: any
	end

	clear_rpn()
	return table.freeze({
		error = result :: any,
		success = false,
	}) :: any
end

--stylua: ignore
return evaluate :: ((equation: string, max_results: nil, swap_decimal_and_comma: boolean?) -> SingleEvaluationResult)
	& ((equation: string, max_results: number, swap_decimal_and_comma: boolean?) -> MultiEvaluationResult)
