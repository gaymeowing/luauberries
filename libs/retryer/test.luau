local testkit = require("@testkit")
local retryer = require("@libs/retryer")

local TEST, CASE, CHECK, FINISH = testkit.test()
local NOOP = function() end
local ATTEMPTS = 0

local function ENDS_WITH(s: string, ends_with: string): boolean
	return string.sub(s, #s - #ends_with + 1, #s) == ends_with
end

local function meower(kitty: string, catter: string): (string, string)
	ATTEMPTS += 1

	if ATTEMPTS % 2 ~= 0 or ATTEMPTS == 2 then
		error("lmao")
	end

	return `{kitty} :3`, `{catter} 🐈`
end

TEST("retryer", function()
	do CASE("retry errors if max_retries is 1")
		local success, retryer_error = pcall(retryer.retry, 1, NOOP)

		CHECK(
			success == false and
			ENDS_WITH(retryer_error, "[RETRYER]: max_retries cannot be less than 2")
		)
	end

	do CASE("delay errors if max_retries is 1")
		local success, retryer_error = pcall(retryer.delay, 2, 1, NOOP)

		CHECK(
			success == false and
			ENDS_WITH(retryer_error, "[RETRYER]: max_retries cannot be less than 2")
		)
	end

	do CASE("exponent errors if max_retries is 1")
		local success, retryer_error = pcall(retryer.exponent, 2, 2, 1, NOOP)

		CHECK(
			success == false and
			ENDS_WITH(retryer_error, "[RETRYER]: max_retries cannot be less than 2")
		)
	end

	do CASE("retry")
		local success1, ret1_1, ret1_2 = retryer.retry(2, meower, "meow", "mrrow")
		local success2, ret2_1, ret2_2 = retryer.retry(4, meower, "meow", "mrrow")

		CHECK(
			success1 == false and ENDS_WITH(ret1_1, "lmao") and ret1_2 == nil and
			success2 == true and ret2_1 == "meow :3" and ret2_2 == "mrrow 🐈"
		)
	end

	do CASE("delay")
		ATTEMPTS = 0
		local success1, ret1_1, ret1_2 = retryer.delay(2, 2, meower, "meow", "mrrow")
		local success2, ret2_1, ret2_2 = retryer.delay(2, 4, meower, "meow", "mrrow")

		CHECK(
			success1 == false and ENDS_WITH(ret1_1, "lmao") and ret1_2 == nil and
			success2 == true and ret2_1 == "meow :3" and ret2_2 == "mrrow 🐈"
		)
	end

	do CASE("exponent")
		ATTEMPTS = 0
		local success1, ret1_1, ret1_2 = retryer.exponent(2, .5, 2, meower, "meow", "mrrow")
		local success2, ret2_1, ret2_2 = retryer.exponent(2, .5, 4, meower, "meow", "mrrow")

		CHECK(
			success1 == false and ENDS_WITH(ret1_1, "lmao") and ret1_2 == nil and
			success2 == true and ret2_1 == "meow :3" and ret2_2 == "mrrow 🐈"
		)
	end

	do CASE("infinite")
		local ret1_1, ret1_2 = retryer.infinite(meower, "meow", "mrrow")
		CHECK(ret1_1 == "meow :3" and ret1_2 == "mrrow 🐈")
	end

	do CASE("infinite_delay")
		local ret1_1, ret1_2 = retryer.infinite_delay(1, meower, "meow", "mrrow")
		CHECK(ret1_1 == "meow :3" and ret1_2 == "mrrow 🐈")
	end

	do CASE("infinite_exponent")
		local ret1_1, ret1_2 = retryer.infinite_exponent(1, .5, meower, "meow", "mrrow")
		CHECK(ret1_1 == "meow :3" and ret1_2 == "mrrow 🐈")
	end
end)
