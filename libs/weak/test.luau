local testkit = require("../../testkit")
local weak = require("./init")

local WEAK_TYPES = { "kvs", "ks", "vs", "kv", "k", "v" }
local TEST, CASE, CHECK, FINISH = testkit.test()

TEST("weak", function()
	for _, weak_type in WEAK_TYPES do
		CASE(weak_type)
		local weakt = weak.create(weak_type)
		CHECK(getmetatable(weakt).__mode == weak_type)
	end

	do CASE("weaken")
		local t = {}
		local weakened = weak.weaken(t, "k")
		CHECK(weak == weakened)
	end

end)
