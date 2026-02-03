type function flatten_set(set_to: type, component: type)
	if component.tag == "table" then
		for key, property in component:properties() do
			set_to:setwriteproperty(key, property.write)
			set_to:setreadproperty(key, property.read)
		end
	else
		for _, inner_component in component:components() do
			flatten_set(set_to, inner_component)
		end
	end
end

type function Flatten(t: type): type
	if t.tag == "table" then
		return types.copy(t)
	else
		local table = types.newtable()

		for _, component in t:components() do
			flatten_set(table, component)
		end
		return table
	end
end

type BaseError<T> = {
	read type: T,
}

type BaseOffsetError<T> = BaseError<T> & {
	read offset: number,
}

type NotEnoughArgumentsForMethodError = BaseOffsetError<"NotEnoughArgumentsForMethod"> & {
	read required_argument_amount: number,
	read given_argument_amount: number,
	read method: string,
}

type NonExistantConstantOrMethodError = BaseOffsetError<"NonExistantConstantOrMethod"> & {
	read provided_constant_or_method: string,
}

export type ExpectingToken =
	| Operation
	| Symbol
	| Method

type ExpectedValueError = BaseOffsetError<"ExpectedValue"> & {
	--[[
		What token was given instead of a value (a number, open paren, or open abs bar)

		(Abs bar `|` is a closing abs bar, used for indicating empty abs bars `||`)
	]]
	given_token: TokensThatExpectAValue,
	--- The token that was expecting a value
	expecting_token: ExpectingToken,
}

export type Error =
	| BaseOffsetError<"NonTopLevelCommaNotInMethod">
	| BaseError<"SolveStackHasTooManyValuesLeft">
	| BaseOffsetError<"InvalidClosingParenthese">
	| BaseOffsetError<"MoreThanOneDecimalPoint">
	| BaseOffsetError<"ExpectedValueBeforePow">
	| BaseOffsetError<"InvalidCodepoint">
	| BaseOffsetError<"MalformedNumber">
	| BaseOffsetError<"TooManyDigits">
	| NotEnoughArgumentsForMethodError
	| NonExistantConstantOrMethodError
	| ExpectedValueError


type Type = "type"

-- cant currently use Type in the snake_case type functions because of https://github.com/luau-lang/luau/issues/1892
type function get_error_type(error_info: type): type?
	if error_info.tag == "table" then
		return error_info:readproperty(types.singleton("type")) :: any
	end

	for _, component in error_info:components() do
		local error_type = get_error_type(component)

		if error_type then
			return error_type :: any
		end
	end
	return nil
end

type function get_error_types(): type
	local components = Error:components() :: { type }

	for index, component in components do
		components[index] = get_error_type(component)
	end
	return types.unionof(table.unpack(components))
end

-- temporary type function because singleton inference still sucks in luau :(
export type function GetErrorForErrorType(error_type: type): type
	local errors = Error:components()

	if error_type then
		local error_type_singleton: type
		local error_type_string: string

		if error_type.tag == "singleton" then
			error_type_singleton = error_type
			error_type_string = error_type:value() :: any
		else
			for _, component in error_type:components() do
				if component.tag == "singleton" then
					error_type_string = component:value() :: string
					error_type_singleton = component
					break
				end
			end

			if not error_type_singleton then
				error(
					"couldnt find string singleton in error_type provided, error_type is expected to be 'T & types.ErrorType'"
				)
			end
		end

		for _, component in errors do
			if (get_error_type(component) :: type):value() ~= error_type_string then
				continue
			end
			local flattened_error_info = Flatten(component)
			flattened_error_info:setproperty(Type, nil)

			for key, property in flattened_error_info:properties() do
				flattened_error_info:setproperty(key, property.read)
			end
			return flattened_error_info
		end
		error(`No error exists for ErrorType '{error_type_string}'`)
	end
	local components_without_type_property = table.create(#errors) :: { type }

	for index, component in errors do
		local flattened_component = Flatten(component)
		flattened_component:setproperty(Type, nil)
		components_without_type_property[index] = flattened_component
	end
	return types.unionof(table.unpack(components_without_type_property))
end

-- cant make ErrorType a type function because there will be an "attempt to modify other type function arena" error
export type ErrorType = get_error_types<>

export type Method = {
	total_arguments: number,
	--- indicates if the method was declared using implicit parentheses or not
	read is_implicit: true?,
	offset: number,
	name: string,
}

-- horrible name for a type as it doesn't really describe what its for
-- PRs welcome for giving this a better name
export type TokensThatExpectAValue = NonUnaryOperation | SymbolsThatExpectAValue

export type Precedence2Operation =
	| "*"
	| "/"
	-- removed because i would imagine the floor division operator being confusing
	-- for regular 3 year old roblox players and also doing floor(x / y) is fine
	-- | "//"
	| "%"

export type NonUnaryOperation =
	| Precedence2Operation
	| "+"
	| "-"
	| "^"
	| "|"

-- stylua: ignore
export type Operation =
	| NonUnaryOperation
	| "unary-"
	| "%of"

export type SymbolsThatExpectAValue =
	| ","
	| ")"


-- stylua: ignore
export type Symbol =
	| SymbolsThatExpectAValue
	| "("

-- stylua: ignore
export type Token =
	| Operation
	| Symbol
	| Method
	| number

-- stylua: ignore
export type SYValue =
	| Operation
	| Method
	| "("

-- stylua: ignore
export type RPNValue =
	| Operation
	| Method
	| number

export type RPN = { RPNValue }

return nil
