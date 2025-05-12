--!native

--[[
	weak
	a weak table utility so its easier to get types with weak tables
]]

export type WeakType =
	| "kvs"
	| "ks"
	| "vs"
	| "kv"
	| "k"
	| "v"

local WEAK_PAIR_SHRINKABLE = table.freeze({ __mode = "kvs" })
local WEAK_VALUE_SHRINKABLE = table.freeze({ __mode = "vs" })
local WEAK_KEY_SHRINKABLE = table.freeze({ __mode = "ks" })
local WEAK_PAIR = table.freeze({ __mode = "kv" })
local WEAK_VALUE = table.freeze({ __mode = "v" })
local WEAK_KEY = table.freeze({ __mode = "k" })

local function GET_WEAK_META_FOR_TYPE(type: WeakType): { __mode: string }
	return if type == "kvs" then
			WEAK_PAIR_SHRINKABLE
		elseif type == "vs" then
			WEAK_VALUE_SHRINKABLE
		elseif type == "ks" then
			WEAK_KEY_SHRINKABLE
		elseif type == "kv" then
			WEAK_PAIR
		elseif type == "k" then
			WEAK_KEY
		else
			WEAK_VALUE
end

local weak = {}

--[[
	Creates a new weak table of the provided type.
]]
function weak.create(type: WeakType): {}
	return setmetatable({} :: any, GET_WEAK_META_FOR_TYPE(type)) :: any
end

--[[
	Sets the metatable of the provided table to the weak metatable 
	corrosponding to the provided type of weak table, and returns the provided table.
]]
function weak.weaken<T>(t: T & {}, type: WeakType): T
	return setmetatable(t :: any, GET_WEAK_META_FOR_TYPE(type))
end

return table.freeze(weak)

