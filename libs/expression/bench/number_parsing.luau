--[[
This file is for use by Benchmarker (https://boatbomber.itch.io/benchmarker)

|WARNING| THIS RUNS IN YOUR REAL ENVIRONMENT. |WARNING|
--]]

--!optimize 2

local function IS_IN_RANGE(n: number, start: number, stop: number): boolean
	return n >= start and n <= stop
end

local function BYTE_AT(s: string, position: number): number
	return (string.byte(s, position, position))
end

local function IS_DIGIT(byte: number): boolean
	return IS_IN_RANGE(byte, 47, 57)
end

local UNDERSCORE = string.byte("_")
local UPPER_B = string.byte("B")
local LOWER_B = string.byte("b")
local UPPER_X = string.byte("X")
local LOWER_X = string.byte("x")
local PERIOD = string.byte(".")
local ZERO = string.byte("0")
local ONE = string.byte("1")
local EQUATION: string
local OFFSET = 0

local function is_valid_binary(byte: number): boolean
	return byte == ZERO or byte == ONE
end

local function is_valid_hex(byte: number): boolean
	-- stylua: ignore
	return IS_DIGIT(byte)
		or IS_IN_RANGE(byte, 97, 102)
		or IS_IN_RANGE(byte, 65, 70)
end

local NUMBER_SEGMENTS = table.create(10) :: { string }

local function parse_number_concat(byte: number): number
	local number_segment_count = 0

	if byte == ZERO then
		local format_specifier = BYTE_AT(EQUATION, OFFSET + 1)

		if format_specifier == LOWER_X or format_specifier == UPPER_X then
			OFFSET += 2
			local next_start = OFFSET
			local start = OFFSET

			while OFFSET <= #EQUATION do
				local next_byte = BYTE_AT(EQUATION, OFFSET)

				if is_valid_hex(next_byte) then
					OFFSET += 1
				elseif next_byte == UNDERSCORE then
					number_segment_count += 1
					NUMBER_SEGMENTS[number_segment_count] = string.sub(EQUATION, next_start, OFFSET)
					OFFSET += 1
					next_start = OFFSET
				else
					break
				end
			end

			-- erroring if the "number" is literally just 0x
			if start == OFFSET then
				error("malformed number")
			end

			number_segment_count += 1
			NUMBER_SEGMENTS[number_segment_count] = string.sub(EQUATION, next_start, OFFSET - 1)

			local result = tonumber(table.concat(NUMBER_SEGMENTS), 16) :: number
			table.clear(NUMBER_SEGMENTS)
			return result
		elseif format_specifier == LOWER_B or format_specifier == UPPER_B then
			OFFSET += 2
			local next_start = OFFSET
			local start = OFFSET

			while OFFSET <= #EQUATION do
				local next_byte = BYTE_AT(EQUATION, OFFSET)

				if is_valid_binary(next_byte) then
					OFFSET += 1
				elseif next_byte == UNDERSCORE then
					number_segment_count += 1
					NUMBER_SEGMENTS[number_segment_count] = string.sub(EQUATION, next_start, OFFSET)
					OFFSET += 1
					next_start = OFFSET
				else
					break
				end
				OFFSET += 1
			end

			-- erroring if the "number" is literally just 0b
			if start == OFFSET then
				error("malformed number")
			end

			number_segment_count += 1
			NUMBER_SEGMENTS[number_segment_count] = string.sub(EQUATION, next_start, OFFSET - 1)

			local result = tonumber(table.concat(NUMBER_SEGMENTS), 2) :: number
			table.clear(NUMBER_SEGMENTS)
			return result
		end
	end
	local has_decimal = byte == PERIOD
	local next_start = OFFSET
	OFFSET += 1

	while OFFSET <= #EQUATION do
		local next_byte = BYTE_AT(EQUATION, OFFSET)

		if IS_DIGIT(next_byte) then
			OFFSET += 1
		elseif next_byte == UNDERSCORE then
			number_segment_count += 1
			NUMBER_SEGMENTS[number_segment_count] = string.sub(EQUATION, next_start, OFFSET)
			OFFSET += 1
			next_start = OFFSET
		elseif next_byte == PERIOD then
			if not has_decimal then
				has_decimal = true
				OFFSET += 1
			else
				error("Cannot have more than 1 decimal point in a number")
			end
		else
			break
		end
	end

	local result = tonumber(table.concat(NUMBER_SEGMENTS)) :: number
	table.clear(NUMBER_SEGMENTS)
	return result
end

local MAX_DIGITS = 500
local MAX_DIGIT_INDEX = MAX_DIGITS - 1
local NUMBER_BUFFER = buffer.create(MAX_DIGITS)

local function parse_format_number(checker: (byte: number) -> boolean, base: number): number
	OFFSET += 2
	local start = OFFSET
	local digit_index = 0

	while OFFSET <= #EQUATION do
		local next_byte = BYTE_AT(EQUATION, OFFSET)

		if is_valid_hex(next_byte) then
			if digit_index > MAX_DIGIT_INDEX then
				error(`Cannot have more than {MAX_DIGITS} digits in a number`)
			end

			buffer.writeu8(NUMBER_BUFFER, digit_index, next_byte)
			digit_index += 1
		elseif next_byte ~= UNDERSCORE then
			break
		end
		OFFSET += 1
	end

	-- erroring if the "number" is literally just 0x or 0b
	if start == OFFSET then
		error("malformed number")
	end
	return tonumber(buffer.readstring(NUMBER_BUFFER, 0, digit_index), base) :: any
end

local function parse_number_buffer(byte: number): number
	local digit_index = 0

	if byte == ZERO then
		local format_specifier = BYTE_AT(EQUATION, OFFSET + 1)

		if format_specifier == LOWER_X or format_specifier == UPPER_X then
			OFFSET += 2
			local start = OFFSET

			while OFFSET <= #EQUATION do
				local next_byte = BYTE_AT(EQUATION, OFFSET)

				if is_valid_hex(next_byte) then
					if digit_index > MAX_DIGIT_INDEX then
						error(`Cannot have more than {MAX_DIGITS} digits in a number`)
					end

					buffer.writeu8(NUMBER_BUFFER, digit_index, next_byte)
					digit_index += 1
				elseif next_byte ~= UNDERSCORE then
					break
				end
				OFFSET += 1
			end

			-- erroring if the "number" is literally just 0x
			if start == OFFSET then
				error("malformed number")
			end

			return tonumber(buffer.readstring(NUMBER_BUFFER, 0, digit_index), 16) :: number
		elseif format_specifier == LOWER_B or format_specifier == UPPER_B then
			OFFSET += 2
			local start = OFFSET

			while OFFSET <= #EQUATION do
				local next_byte = BYTE_AT(EQUATION, OFFSET)

				if is_valid_binary(next_byte) then
					if digit_index > MAX_DIGIT_INDEX then
						error(`Cannot have more than {MAX_DIGITS} digits in a number`)
					end

					buffer.writeu8(NUMBER_BUFFER, digit_index, next_byte)
					digit_index += 1
				elseif next_byte ~= UNDERSCORE then
					break
				end
				OFFSET += 1
			end

			-- erroring if the "number" is literally just 0b
			if start == OFFSET then
				error("malformed number")
			end
			return tonumber(buffer.readstring(NUMBER_BUFFER, 0, digit_index), 2) :: number
		end
	end
	local has_decimal = byte == PERIOD
	OFFSET += 1

	while OFFSET <= #EQUATION do
		local next_byte = BYTE_AT(EQUATION, OFFSET)

		if IS_DIGIT(next_byte) then
			if digit_index > MAX_DIGIT_INDEX then
				error(`Cannot have more than {MAX_DIGITS} digits in a number`)
			end

			buffer.writeu8(NUMBER_BUFFER, digit_index, next_byte)
			digit_index += 1
		elseif next_byte == PERIOD then
			if not has_decimal then
				has_decimal = true
			else
				error("Cannot have more than 1 decimal point in a number")
			end
		elseif next_byte ~= UNDERSCORE then
			break
		end
		OFFSET += 1
	end

	return tonumber(buffer.readstring(NUMBER_BUFFER, 0, digit_index)) :: number
end

local function parse_number_format_function(byte: number): number
	if byte == ZERO then
		local format_specifier = BYTE_AT(EQUATION, OFFSET + 1)

		if format_specifier == LOWER_X or format_specifier == UPPER_X then
			return parse_format_number(is_valid_hex, 16)
		elseif format_specifier == LOWER_B or format_specifier == UPPER_B then
			return parse_format_number(is_valid_binary, 2)
		end
	end
	local has_decimal = byte == PERIOD
	local digit_index = 0
	OFFSET += 1

	while OFFSET <= #EQUATION do
		local next_byte = BYTE_AT(EQUATION, OFFSET)

		if IS_DIGIT(next_byte) then
			if digit_index > MAX_DIGIT_INDEX then
				error(`Cannot have more than {MAX_DIGITS} digits in a number`)
			end

			buffer.writeu8(NUMBER_BUFFER, digit_index, next_byte)
			digit_index += 1
		elseif next_byte == PERIOD then
			if not has_decimal then
				has_decimal = true
			else
				error("Cannot have more than 1 decimal point in a number")
			end
		elseif next_byte ~= UNDERSCORE then
			break
		end
		OFFSET += 1
	end

	return tonumber(buffer.readstring(NUMBER_BUFFER, 0, digit_index)) :: any
end

local NORMAL_EQUATION =
	"937_895_063_254_915_635_310_666_542_141_563_652_859_108_090_743_377_235_611_594_632_368_252_384_844_857_933_416_821_070_545_270_629_379_141_615_655_457_422_943_930_059_778_067_752_455_141_627_110_197_855_702_250_317_219_746_516_242_845_979_592_949_930_943_851_259_931_706_118_367_565_275_861_429_971_036_890_657_355_564_890_091_687_953_566_653_866_533_596_279_718_244_937_690_998_023_669_062_128_370_296_542_369_669_822_895_130_296_664_431_414_493_774_275_810_505_934_245_606_507_980_157_268_287_778_434_820_824_611_758_827_809_747_155_362_766_182_244_887_167_147_011_974_075_143_415_104_466_980_765_017_042_381_374_004_910_538_001_604_296_880_818_952_068_291_347_"
local BINARY_EQUATION =
	"0b111_011_010_011_110_101_100_111_010_001_011_111_101_011_100_101_111_010_010_011_100_000_011_100_010_111_101_001_110_001_010_001_010_010_101_000_100_011_000_110_001_000_101_001_100_001_010_000_100_101_100_100_101_000_101_011_100_001_110_100_001_001_110_000_001_000_011_100_111_110_001_111_001_100_000_101_011_001_111_000_011_011_110_001_000_111_001_001_110_101_111_000_110_110_100_110_010_010_101_010_100_110_001_000_010_100_011_110_000_000_010_100_011_001_001_100_100_011_100_111_001_111_010_001_100_010_000_011_111_011_100_101_101_111_101_010_001_100_111_111_111_010_011_011_000_010_111_000_100_110_000_110_101_110_000_110_110_101_011_111_110_111_101_101_110_000_"
local ITERATIONS = 100
local FIRST_BYTE = 0
local random = Random.new()

local random_hex_chars = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }

for i = 97, 102 do
	table.insert(random_hex_chars, string.char(i))
end

local function get_random<V>(t: { V }): V
	return t[random:NextInteger(1, #t)]
end

local hex_eq_concat = table.create(166 * 4, "_")

for i = 1, 166, 4 do
	hex_eq_concat[i] = get_random(random_hex_chars)
	hex_eq_concat[i + 1] = get_random(random_hex_chars)
	hex_eq_concat[i + 2] = get_random(random_hex_chars)
end

local HEX_EQUATION = "0x" .. table.concat(hex_eq_concat)

return {
	ParameterGenerator = function()
		return
	end,

	BeforeAll = function() end,
	AfterAll = function() end,
	BeforeEach = function() end,
	AfterEach = function() end,

	Functions = {
		concat = function(Profiler)
			EQUATION = NORMAL_EQUATION
			FIRST_BYTE = BYTE_AT(EQUATION, 1)
			for i = 1, ITERATIONS do
				OFFSET = 1
				NUMBER_SEGMENTS = table.create(10)
				Profiler.Begin("Parse Normal")
				parse_number_concat(FIRST_BYTE)
				Profiler.End()
			end
			EQUATION = BINARY_EQUATION
			FIRST_BYTE = BYTE_AT(EQUATION, 1)

			for i = 1, ITERATIONS do
				OFFSET = 1
				Profiler.Begin("Parse Binary")
				parse_number_concat(FIRST_BYTE)
				Profiler.End()
			end
			EQUATION = HEX_EQUATION
			FIRST_BYTE = BYTE_AT(EQUATION, 1)

			for i = 1, ITERATIONS do
				OFFSET = 1
				Profiler.Begin("Parse Hex")
				parse_number_concat(FIRST_BYTE)
				Profiler.End()
			end
		end,
		buffer = function(Profiler)
			EQUATION = NORMAL_EQUATION
			FIRST_BYTE = BYTE_AT(EQUATION, 1)

			for i = 1, ITERATIONS do
				OFFSET = 1
				Profiler.Begin("Parse Normal")
				parse_number_buffer(FIRST_BYTE)
				Profiler.End()
			end
			EQUATION = BINARY_EQUATION
			FIRST_BYTE = BYTE_AT(EQUATION, 1)

			for i = 1, ITERATIONS do
				OFFSET = 1
				Profiler.Begin("Parse Binary")
				parse_number_buffer(FIRST_BYTE)
				Profiler.End()
			end
			EQUATION = HEX_EQUATION
			FIRST_BYTE = BYTE_AT(EQUATION, 1)

			for i = 1, ITERATIONS do
				OFFSET = 1
				Profiler.Begin("Parse Hex")
				parse_number_buffer(FIRST_BYTE)
				Profiler.End()
			end
		end,
		buffer_with_format_function = function(Profiler)
			EQUATION = NORMAL_EQUATION
			FIRST_BYTE = BYTE_AT(EQUATION, 1)

			for i = 1, ITERATIONS do
				OFFSET = 1
				Profiler.Begin("Parse Normal")
				parse_number_format_function(FIRST_BYTE)
				Profiler.End()
			end
			EQUATION = BINARY_EQUATION
			FIRST_BYTE = BYTE_AT(EQUATION, 1)

			for i = 1, ITERATIONS do
				OFFSET = 1
				Profiler.Begin("Parse Binary")
				parse_number_format_function(FIRST_BYTE)
				Profiler.End()
			end
			EQUATION = HEX_EQUATION
			FIRST_BYTE = BYTE_AT(EQUATION, 1)

			for i = 1, ITERATIONS do
				OFFSET = 1
				Profiler.Begin("Parse Hex")
				parse_number_format_function(FIRST_BYTE)
				Profiler.End()
			end
		end,
	},
}
