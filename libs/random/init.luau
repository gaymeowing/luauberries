--!native

--[[
	random
	pure luau functional equivalent to robloxs random class
]]

type RandomPrototype = {
	--[[
		Returns a pseudorandom integer uniformly distributed over `[min, max]`.
	]]
	integer: (self: Random, min: number?, max: number?) -> number,
	--[[
		Returns a pseudorandom vector uniformly distributed over `[min, max]`.
	]]
	vector: (self: Random, min: vector?, max: vector?) -> vector,
	--[[
		Returns a pseudorandom number uniformly distributed over `[min, max]`.
	]]
	float: (self: Random, min: number?, max: number?) -> number,
	--[[
		Returns a normalized vector (unit vector) with a pseudorandom direction.
	]]
	normalized_vector: (self: Random) -> vector,
	--[[
		Uniformly shuffles an array-like table in-place.
	]]
	shuffle: <V>(self: Random, t: { V }) -> (),
	--[[
		Returns a random value from an array-like table.
	]]
	value: <V>(self: Random, t: { V }) -> V,
	__index: RandomPrototype
}

--[[
	Generates pseudorandom numbers, vectors, and directions.
]]
export type Random = setmetatable<{
	state: number,
}, RandomPrototype>

local function CREATE_SEED(): number
	return os.time() * os.clock() % 100
end

local DEFAULT_MAX = 9007199254740991
local DEFAULT_MIN = -DEFAULT_MAX
local SEED = CREATE_SEED()

local function is_close(a: number, b: number): boolean
	return math.abs(a - b) <= math.max(
		1e-09 * math.max(math.abs(a), math.abs(b)), 0
	)
end

local function RANDOMIZE_STATE(state: number): number
	return (state * 6364136223846793) + 105
end

local function GET_SEED(seed: number?): number
	seed = seed or CREATE_SEED()

	return if is_close(seed, SEED) then
			RANDOMIZE_STATE(seed)
		else
			seed
end

local function SET_SEED(seed: number)
	SEED = seed
	math.randomseed(seed)
end

--[[
	Returns a pseudorandom integer uniformly distributed over `[min, max]`.
]]
local function INTEGER(min: number?, max: number?, seed: number?): number
	SET_SEED(GET_SEED(seed))
	return math.random(min or DEFAULT_MIN, max or DEFAULT_MAX)
end

--[[
	Returns a pseudorandom number uniformly distributed over `[min, max]`.
]]
local function FLOAT(min: number?, max: number?, seed: number?): number
	SET_SEED(GET_SEED(seed))
	local real_min = min or math.random()
	SET_SEED(GET_SEED(seed))
	local real_max = max or math.random(real_min, DEFAULT_MAX)
	
	SET_SEED(GET_SEED(seed))
	return real_min + (math.random() * (real_max - real_min))
end

local function SET_STATE(random: Random)
	local state = RANDOMIZE_STATE(random.state)
	math.randomseed(state)
	random.state = state
end

local function CLASS_INTEGER(random: Random, min: number?, max: number?): number
	SET_STATE(random)
	return math.random(min or DEFAULT_MIN, max or DEFAULT_MIN)
end

local function CLASS_FLOAT(random: Random, min: number?, max: number?): number
	SET_STATE(random)
	local real_min = min or math.random()
	SET_STATE(random)
	local real_max = max or math.random(real_min, DEFAULT_MAX)
	
	SET_STATE(random)
	return real_min + (math.random() * (real_max - real_min))
end

local random_prototype = {
	integer = CLASS_INTEGER,
	float = CLASS_FLOAT,
} :: RandomPrototype

function random_prototype.normalized_vector(random)
	SET_STATE(random)
	local theta = math.random() * math.pi * 2
	SET_STATE(random)
	local u = math.random() * 2 - 1
	local c = math.sqrt(1 - u * u)

	return vector.create(
		c * math.cos(theta),
		u,
		c * math.sin(theta)
	)
end

function random_prototype.vector(random, min, max)
	max = max or vector.create(
		CLASS_FLOAT(random),
		CLASS_FLOAT(random),
		CLASS_FLOAT(random)
	)
	min = min or vector.zero

	return vector.create(
		CLASS_FLOAT(random, min.x, max.x),
		CLASS_FLOAT(random, min.y, max.y),
		CLASS_FLOAT(random, min.z, max.z)
	)
end

function random_prototype.shuffle(random, t)
	for index, value in t do
		local random_index = CLASS_INTEGER(random, index, #t)
		t[index] = t[random_index]
		t[random_index] = value
	end
end

function random_prototype.value(random, t)
	local index = CLASS_INTEGER(random, 1, #t)
	return index, t[index]
end

--[[
	Generates pseudorandom numbers, vectors, and directions.
]]
local random = {
	integer = INTEGER,
	float = FLOAT,
}

--[[
	Returns vector with random coordinates.
]]
function random.vector(min: vector?, max: vector?, seed: number?): vector
	max = max or vector.create(
		FLOAT(nil, nil, seed),
		FLOAT(nil, nil, seed),
		FLOAT(nil, nil, seed)
	)
	min = min or vector.zero

	return vector.create(
		FLOAT(min.x, max.x, seed),
		FLOAT(min.y, max.y, seed),
		FLOAT(min.z, max.z, seed)
	)
end

--[[
	Returns a normalized vector (unit vector) with a pseudorandom direction.
]]
function random.normalized_vector(seed: number?): vector
	SET_SEED(GET_SEED(seed))
	local theta = math.random() * math.pi * 2
	SET_SEED(GET_SEED(seed))
	local u = math.random() * 2 - 1
	local c = math.sqrt(1 - u * u)

	return vector.create(
		c * math.cos(theta),
		u,
		c * math.sin(theta)
	)
end

--[[
	Returns a random value from an array-like table.
]]
function random.value<V>(t: { V }, seed: number?): V
	return t[INTEGER(1, #t, seed)]
end

--[[
	Uniformly shuffles an array-like table in-place.
]]
function random.shuffle<V>(t: { V }, seed: number?)
	for index, value in t do
		local random_index = INTEGER(index, #t, seed)
		t[index] = t[random_index]
		t[random_index] = value
	end
end

--[[
	Creates a new Random object, useful for not having to constantly pass around a seed variable.
]]
function random.create(seed: number?): Random
	return setmetatable({
		state = seed or CREATE_SEED()
	}, random_prototype)
end

--[[
	Returns the current seed being used for non-class random functions.
]]
function random.get_seed(): number
	return SEED
end

do
	
	random_prototype.__index = random_prototype
	table.freeze(random_prototype)
	table.freeze(random)

end

return random