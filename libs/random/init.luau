--!native

--[[
	random
	pure luau functional equivalent to robloxs random class
]]

type SetState<V> = (v: V) -> ()

type MinMaxMethod<S, MIN, MAX, R> = (set_state: SetState<S>, min: MIN, max: MAX, seed: S) -> R

type Method<S, V, R> = (set_state: SetState<S>, v: V, seed: S) -> R

--[[
	Generates pseudorandom numbers, vectors, and directions.
]]
type RandomSpec<TS = nil, TV = nil, NV = nil, V = nil, F = nil, I = nil, MI = nil> = {
	--[[
		Returns a normalized vector (unit vector) with a pseudorandom direction.
	]]
	normalized_vector: NV,
	--[[
		Uniformly shuffles an array-like table in-place.
	]]
	shuffle: TS,
	--[[
		Returns a pseudorandom integer uniformly distributed over `[min, max]`.
	]]
	integer: I,
	--[[
		Returns a pseudorandom vector uniformly distributed over `[min, max]`.
	]]
	vector: V,
	--[[
		Returns a random value from an array-like table.
	]]
	value: TV,
	--[[
		Returns a pseudorandom number uniformly distributed over `[min, max]`.
	]]
	float: F,
	__index: MI, -- if this isnt here the solver has a seizure
}

type RandomPrototype = RandomSpec<
	<V>(random: Random, t: { V }) -> (),
	<V>(random: Random, t: { V }) -> V,
	(random: Random) -> vector,
	(random: Random, min: vector?, max: vector?) -> vector,
	(random: Random, min: number?, max: number?) -> number,
	(random: Random, min: number?, max: number?) -> number,
	RandomPrototype
>

export type Random = setmetatable<{
	state: number,
}, RandomPrototype>

type Export = RandomSpec<
	<V>(t: { V }, seed: number?) -> (),
	<V>(t: { V }, seed: number?) -> V,
	(seed: number?) -> vector,
	(min: vector?, max: vector?, seed: number?) -> vector,
	(min: number?, max: number?, seed: number?) -> number,
	(min: number?, max: number?, seed: number?) -> number
> & {
	--[[
		Creates a new Random object, useful for not having to constantly pass around a seed variable.
	]]
	create: (seed: number?) -> Random,
	--[[
		Returns the current seed being used for non-class random functions.
	]]
	get_seed: () -> number,
}

local function CREATE_SEED(): number
	return os.time() * os.clock() % 100
end

local DEFAULT_MAX = 2 ^ 23
local DEFAULT_MIN = -DEFAULT_MAX
local DEFAULT_MAX_VECTOR = vector.create(DEFAULT_MAX, DEFAULT_MAX, DEFAULT_MAX)
local DEFAULT_MIN_VECTOR = -DEFAULT_MAX_VECTOR
local SEED = CREATE_SEED()

local function is_close(a: number, b: number): boolean
	return math.abs(a - b) <= math.max(
		1e-09 * math.max(math.abs(a), math.abs(b)), 0
	)
end

local function RANDOMIZE_STATE(state: number): number
	return (state * 6364136223846793) + 105
end

local function SET_GSTATE(seed: number)
	if seed == SEED or is_close(seed, SEED) then
		seed = RANDOMIZE_STATE(seed)
	end

	SEED = seed
	math.randomseed(seed)
end

local function SET_STATE(random: Random)
	local state = RANDOMIZE_STATE(random.state)
	math.randomseed(state)
	random.state = state
end

local function CREATE_CLASS_METHOD<V, R>(f: Method<Random, V, R>): (Random, V) -> R
	return function(random, v)
		return f(SET_STATE, v, random)
	end
end

local function CREATE_METHOD<V, R>(f: Method<number, V, R>): (V, number?) -> R
	return function(v, seed)
		return f(SET_GSTATE, v, seed or SEED)
	end
end

local function CREATE_CLASS_METHOD_RANGE<MIN, MAX, R>(
	f: MinMaxMethod<Random, MIN, MAX, R>
): (Random, MIN, MAX) -> R
	return function(random, min, max)
		return f(SET_STATE, min, max, random)
	end
end

local function CREATE_METHOD_RANGE<MIN, MAX, R>(
	f: MinMaxMethod<number, MIN, MAX, R>
): (MIN, MAX, number?) -> R
	return function(min, max, seed)
		return f(SET_GSTATE, min, max, seed or SEED)
	end
end

local function CREATE_METHOD_NO_ARG<S, R>(
	f: (SetState<S>, S) -> R, set_state: SetState<S>
): (S) -> R
	return function(s)
		return f(set_state, s)
	end
end

local function INTEGER<V>(
	set_state: (v: V) -> (), min: number, max: number, v: V
): number
	set_state(v)
	-- if math.random isnt wrapped here it wont inline 
	return (math.random(min, max))
end

local function FLOAT<V>(
	set_state: (v: V) -> (), min: number, max: number, v: V
): number
	set_state(v)
	return min + (math.random() * (max - min))
end

local function VALUE<V>(set_state: SetState<V>, t: { unknown }, v: V): unknown
	return t[INTEGER(set_state, 1, #t, v)]
end

local function SHUFFLE<V>(set_state: SetState<V>, t: { unknown }, v: V)
	for index, value in t do
		local random_index = INTEGER(set_state, index, #t, v)
		t[index] = t[random_index]
		t[random_index] = value
	end
end

local function EXPORT_INTEGER<V>(
	set_state: SetState<V>, min: number?, max: number?, v: V
): number
	return INTEGER(set_state, min or DEFAULT_MIN, max or DEFAULT_MAX, v)
end

local function EXPORT_FLOAT<V>(
	set_state: SetState<V>, min: number?, max: number?, v: V
): number
	return FLOAT(set_state, min or DEFAULT_MIN, max or DEFAULT_MAX, v)
end

local function VECTOR<V>(
	set_state: SetState<V>, min: vector?, max: vector?, v: V
): vector
	if not max then
		max = DEFAULT_MAX_VECTOR
	end

	if not min then
		min = DEFAULT_MIN_VECTOR
	end

	return vector.create(
		FLOAT(set_state, min.x, max.x, v),
		FLOAT(set_state, min.y, max.y, v),
		FLOAT(set_state, min.z, max.z, v)
	)
end

local function NORMALIZED_VECTOR<V>(
	set_state: SetState<V>, v: V
): vector
	--[[
		doing this because normalized_vector is weird and only takes in a seed or random arg
		so its just easier to do defaults here + if its a method on the class the first arg should never be nil
	]]
	if not v then
		v = SEED :: any
	end

	set_state(v)
	local theta = math.random() * math.pi * 2
	set_state(v)
	local u = math.random() * 2 - 1
	local c = math.sqrt(1 - u * u)

	return vector.create(
		c * math.cos(theta),
		u,
		c * math.sin(theta)
	)
end

local random_prototype: RandomPrototype = {
	normalized_vector = CREATE_METHOD_NO_ARG(NORMALIZED_VECTOR, SET_STATE),
	integer = CREATE_CLASS_METHOD_RANGE(EXPORT_INTEGER),
	float = CREATE_CLASS_METHOD_RANGE(EXPORT_FLOAT),
	vector = CREATE_CLASS_METHOD_RANGE(VECTOR),
	shuffle = CREATE_CLASS_METHOD(SHUFFLE),
	value = CREATE_CLASS_METHOD(VALUE),
}

local random: Export = {
	normalized_vector = CREATE_METHOD_NO_ARG(NORMALIZED_VECTOR, SET_GSTATE),
	integer = CREATE_METHOD_RANGE(EXPORT_INTEGER),
	float = CREATE_METHOD_RANGE(EXPORT_FLOAT),
	vector = CREATE_METHOD_RANGE(VECTOR),
	shuffle = CREATE_METHOD(SHUFFLE),
	value = CREATE_METHOD(VALUE),
} :: Export

function random.create(seed)
	return setmetatable({
		state = seed or CREATE_SEED()
	}, random_prototype)
end

function random.get_seed()
	return SEED
end

do
	
	random_prototype.__index = random_prototype
	table.freeze(random_prototype)
	table.freeze(random)

end

return random :: Export
