local random = require("@libs/random")
local expression = require("./init")
local testkit = require("@testkit")

local TEST, CASE, CHECK, FINISH = testkit.test()

local function is_close(a: number, b: number): boolean
	return math.abs(a - b) <= math.max(1e-09 * math.max(math.abs(a), math.abs(b)), 0)
end

local function base_equation_case(
	equation: string,
	checker: (result: number, expected: number) -> boolean,
	expected_result: { number } | number,
	swap_decimal_and_comma: boolean?
)

	CASE(equation)
	local result = expression.evaluate(equation, if type(expected_result) == "table" then 20 else (nil :: any) :: number, swap_decimal_and_comma)
	local success = false

	if result.error then
		print(result.error)
		error("error occured, check previous print for details")
	end

	if type(expected_result) == "number" then
		success = checker(result.result, expected_result)
	else
		print(result)
		for index, number in result.result do
			local expected = expected_result[index]

			if checker(number, expected) then
				success = true
			else
				success = false
				break
			end
		end
	end

	if not success then
		warn(
			`'{equation}' error:\n\texpected: {if type(expected_result) == "table"
				then `\{{table.concat(expected_result, ", ")}\}`
				else expected_result}\n\terror_msg:`,
			result
		)
	end

	CHECK(success)
end

local function EQUATION_CASE_EQUAL(equation: string, expected_result: { number } | number, swap_decimal_and_comma: boolean?)
	base_equation_case(equation, function(result, expected)
		return result == expected or is_close(result, expected)
	end, expected_result, swap_decimal_and_comma)
end


local function EQUATION_CASE_NOT_EQUAL(equation: string, expected_result: { number } | number, swap_decimal_and_comma: boolean?)
	base_equation_case(equation, function(result, expected)
		return result ~= expected
	end, expected_result, swap_decimal_and_comma)
end

TEST("expression", function()
	EQUATION_CASE_EQUAL(" .10 + 2, 0, 0", { 2.1, 0, 0 })
	EQUATION_CASE_EQUAL("sin(0)2", 0)
	EQUATION_CASE_EQUAL("max(1,(2*2),3)2", 8)
	EQUATION_CASE_EQUAL("2(3)4, |-5|5, 1+1", { 24, 25, 2 })
	EQUATION_CASE_EQUAL("min(|-5, 2^2", 4)
	EQUATION_CASE_EQUAL("1 + 2 * 3", 7)
	--TEST("sin(|-5,-2|)+2") currently errors correctly, keeping for when i get to doing better errors
	EQUATION_CASE_EQUAL("min(-5,2)", -5)
	EQUATION_CASE_EQUAL("max(-5,lerp(10, 20, .5))", 15)
	EQUATION_CASE_EQUAL("min((abs(-10), 5)", 5)
	EQUATION_CASE_EQUAL("2 %%%% % 10", 0.00000002)
	EQUATION_CASE_EQUAL("10%", 0.1)
	EQUATION_CASE_EQUAL("%%%%2", 0.00000002)
	EQUATION_CASE_EQUAL("%%%%2 % 10", 0.00000002)

	EQUATION_CASE_EQUAL("rngint()", random.integer())
	EQUATION_CASE_EQUAL("max(-|rngint(), 10)", 10)
	EQUATION_CASE_EQUAL("max(10, -|rngint(", 10)
	EQUATION_CASE_EQUAL("max(10, -|rngint), 5", {10, 5})
	EQUATION_CASE_EQUAL("ln 10)", math.log10(10))
	EQUATION_CASE_EQUAL("min(ln 10, 11)", math.log10(10))
	-- error case: EQUATION_CASE_EQUAL("min(ln 10), 11)", math.log10(10))
	EQUATION_CASE_EQUAL(",8. 2", {.8, 2}, true)

end)
