local testkit = require("../../testkit")
local random = require("./init")

local TEST, CASE, CHECK, FINISH = testkit.test()
local CAT_SOUNDS = { "meow", "mrrp", "mrow" }

local function HAS_SAME_VALUES(a: { unknown }, b: { unknown }): boolean
	for _, value in a do
		if not table.find(a, value) then
			return false
		end
	end

	for _, value in b do
		if not table.find(b, value) then
			return false
		end
	end

	return true
end

TEST("random", function()

	do CASE("integer")
		CHECK(type(random.integer()) == "number")
	end

	do CASE("shuffle")
		local new_sounds = table.clone(CAT_SOUNDS)

		random.shuffle(new_sounds)
		CHECK(HAS_SAME_VALUES(CAT_SOUNDS, new_sounds))
	end

	do CASE("value")
		CHECK(table.find(CAT_SOUNDS, random.value(CAT_SOUNDS)))
	end

	do CASE("float")
		CHECK(type(random.float()) == "number")
	end

	do CASE("float min max")
		local min, max = .5, .7
		local n = random.float(min, max)
		CHECK(type(n) == "number" and math.clamp(n, min, max) == n)
	end

	do CASE("integer")
		CHECK(type(random.integer()) == "number")
	end

	do CASE("integer min max")
		local min, max = 0, 10
		local n = random.integer(min, max)
		CHECK(type(n) == "number" and math.clamp(n, min, max) == n and math.floor(n) == n)
	end

	do CASE("vector")
		CHECK(type(random.vector()) == "vector")
	end

	do CASE("vector min max")
		local min, max = vector.zero, vector.one
		local v = random.vector(min, max)
		CHECK(type(v) == "vector" and vector.clamp(v, min, max) == v)
	end

	do CASE("normalized_vector")
		CHECK(type(random.normalized_vector()) == "vector")
	end

	do CASE("get_seed")
		CHECK(type(random.get_seed()) == "number")
	end

	do CASE("create class")
		local random = random.create(1)
		CHECK(random.state == 1)
	end

	do CASE("create class seed")
		local random = random.create()
		CHECK(type(random.state) == "number")
	end

	-- random class fields cases
	do
		local skip_fields = { random.create, random.get_seed }
		local c = random.create()

		for name, f in random do
			if table.find(skip_fields, f)  then
				continue
			end
		
			CASE(`class:{name}`)
			local cf = (c :: any)[name] :: (...any) -> any

			if f == random.value then
				local x = type(cf(c, CAT_SOUNDS)) == type(f(CAT_SOUNDS))
				CHECK(type(cf(c, CAT_SOUNDS)) == type(f(CAT_SOUNDS)))
			elseif f == random.shuffle then
				local a, b = table.clone(CAT_SOUNDS), table.clone(CAT_SOUNDS)

				cf(c, a)
				f(b)

				CHECK(HAS_SAME_VALUES(a, b) and HAS_SAME_VALUES(a, CAT_SOUNDS))
			else
				CHECK(type(cf(c)) == type(f()))
			end
		end
	end
end)
