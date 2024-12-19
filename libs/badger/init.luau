
-- badger
-- badge service wrapper

local BadgeService = game:GetService("BadgeService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

export type Badge = {
	index: number,
	id: number,
}

type PlayerInfo = {
	threads_waiting_for_id: { [number]: { thread } },
	threads_waiting_for_all: { thread }?,
	has_been_destroyed: true?,
	owned: { [number]: true? },
	ids_to_check: { number },
	amount_checked: number,
	check_success: boolean,
	running: boolean,
	thread: thread,
	start: number,
}

local THREADS_WAITING_FOR_PLAYER_INFO = {} :: { [Player]: { thread }? }
local CHECK_BADGES = BadgeService.CheckUserBadgesAsync
local PLAYER_INFOS = {} :: { [Player]: PlayerInfo }
local ID_TO_BADGE = {} :: { [number]: Badge? }
local AWARD = BadgeService.AwardBadge
local IDS = {} :: { number }
local PAIR_INCREMENT = 9
local NULL = nil :: any
-- BadgeService:CheckUserBadgesAsync() allows 5 requests per player each minute
-- so every 12 seconds we should be trying to fetch
local FETCH_DELAY = 12
local TOTAL_IDS = 0

local function GET_INFO(player: Player): PlayerInfo?
	local info = PLAYER_INFOS[player]

	if not info then
		local threads = THREADS_WAITING_FOR_PLAYER_INFO[player]
		local thread = coroutine.running()

		if threads then
			table.insert(threads, thread)
		else
			THREADS_WAITING_FOR_PLAYER_INFO[player] = { thread }
		end
		info = coroutine.yield()
	end

	return info
end

local function HAS_BADGE(player: Player, badge: Badge, info: PlayerInfo): boolean
	local id = badge.id

	if info.amount_checked >= badge.index then
		return info.owned[id] :: any
	else
		local waitlists = info.threads_waiting_for_id
		local threads = waitlists[id]

		if threads then
			table.insert(threads, coroutine.running())
		else
			waitlists[id] = { coroutine.running() }
		end
		return coroutine.yield()
	end
end

local function GET_IDS_OWNED(player: Player): { [number]: true? }?
	local info = GET_INFO(player)
	
	if info then
		if info.amount_checked == TOTAL_IDS then
			return info.owned
		else
			local threads = info.threads_waiting_for_all

			if threads then
				table.insert(threads, coroutine.running())
			else
				info.threads_waiting_for_all = { coroutine.running() }
			end
			return coroutine.yield()
		end
	else
		return nil
	end
end

local badger_mt = {}

--[[
	Gets or creates a badge symbol for the given Id.

	WARNING: Badge symbols will not be gc'd, but why would you need them to gc anyways... 
]]
function badger_mt.__call<S>(self: S, id: number): Badge
	local badge_for_id = ID_TO_BADGE[id]

	if badge_for_id then
		return badge_for_id
	else
		TOTAL_IDS += 1

		local badge = table.freeze({
			index = TOTAL_IDS,
			id = id 
		})

		ID_TO_BADGE[id] = badge
		table.insert(IDS, id)
		return badge
	end
end

local badger = setmetatable({}, badger_mt)

--[[
	Returns a Set of all the ids for each badge a player currently has, otherwise returns nil if unsuccessful.
]]
function badger.get_ids(player: Player): { [number]: true? }?
	local ids = GET_IDS_OWNED(player)

	return if ids then
			table.clone(ids)
		else
			nil
end

--[[
	Awards the provided badge to the player.

	Note: This method can fail, so be sure to implement retrying if nessacary.
]]
function badger.award(player: Player, badge: Badge): boolean
	local info = GET_INFO(player)
	
	if info then
		local success = AWARD(BadgeService, player.UserId, badge.id)
		info = PLAYER_INFOS[player]
			
		if success and info then
			info.owned[badge.id] = true
		end
		return success
	else
		return false
	end
end

--[[
	Checks if a player has the provided badge.

	Note: This doesn't account for the case where a player removes a badge from their inventory,
	but thats highly unlikely. And its pretty safe to assume its because they don't want it.
]]
function badger.has(player: Player, badge: Badge): boolean
	local info = GET_INFO(player)

	return if info then
			HAS_BADGE(player, badge, info)
		else
			false
end

--[[
	Returns a Set of all the badges a player currently has, otherwise returns nil if unsuccessful.
]]
function badger.get_badges(player: Player): { [Badge]: true? }?
	local ids_owned = GET_IDS_OWNED(player)

	if ids_owned then
		-- using table.clone to pre allocate the table hash
		local badges: any = table.clone(ids_owned)

		for id in ids_owned do
			badges[ID_TO_BADGE[id]] = true 
		end
		return badges
	else
		return nil
	end
end

do

	local function bulk_defer_threads(threads: { thread }, value: unknown)
		for _, thread in threads do
			task.defer(thread, value)
		end
	end

	local function fetch_thread_runner(player: Player, info: PlayerInfo)
		local threads_waiting_for_id = info.threads_waiting_for_id
		local ids_to_check = info.ids_to_check
		local userid = player.UserId
		local owned = info.owned

		while not info.has_been_destroyed do
			info.start = os.clock()
			local success, awarded: { number } = pcall(
				CHECK_BADGES, BadgeService, userid, info.ids_to_check
			)

			if success then
				info.amount_checked += #ids_to_check

				for _, id in ids_to_check do
					local threads_waiting = threads_waiting_for_id[id]
					local is_awarded = table.find(awarded, id) ~= nil

					if threads_waiting then
						bulk_defer_threads(threads_waiting, is_awarded)
						threads_waiting_for_id[id] = nil
					elseif is_awarded then
						owned[id] = true
					end
				end
			end

			info.check_success = success
			info.running = false
			coroutine.yield()
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		local info = PLAYER_INFOS[player]
		PLAYER_INFOS[player] = nil

		while info.running do
			task.wait()
		end

		local threads_waiting_for_all = info.threads_waiting_for_all

		if threads_waiting_for_all then
			bulk_defer_threads(threads_waiting_for_all, nil)
		end

		for _, threads in info.threads_waiting_for_id do
			bulk_defer_threads(threads, false)
		end

		task.cancel(info.thread)
	end)

	Players.PlayerAdded:Connect(function(player)
		local threads_waiting = THREADS_WAITING_FOR_PLAYER_INFO[player]
		local info: PlayerInfo = {
			ids_to_check = table.move(IDS, 1, 1 + PAIR_INCREMENT, 1, {}),
			threads_waiting_for_id = {},
			check_success = false,
			amount_checked = 0,
			start = os.clock(),
			running = true,
			thread = NULL,
			owned = {},
		}
		PLAYER_INFOS[player] = info
		info.thread = task.defer(fetch_thread_runner, player, info)

		if threads_waiting then
			THREADS_WAITING_FOR_PLAYER_INFO[player] = nil
			bulk_defer_threads(threads_waiting, info)
		end
	end)

	RunService.PostSimulation:Connect(function()
		for player, info in PLAYER_INFOS do
			local amount_checked = info.amount_checked
			local check_start = amount_checked + 1

			--[[
				1: the thread isnt doing work to fetch info
				2: the thread hasnt successfully fetched if the player owns every badge
				3: it must be 12 seconds since the previous fetch started
			--]]
			if 
				not info.running and 
				amount_checked ~= TOTAL_IDS and
				os.clock() - info.start >= FETCH_DELAY
			then
				local check_end = check_start + PAIR_INCREMENT
				local ids_to_check = info.ids_to_check

				table.clear(ids_to_check)
				info.ids_to_check = table.move(
					IDS, check_start, check_end, 1, ids_to_check
				)

				task.defer(info.thread)
			end
		end
	end)
	
	table.freeze(badger_mt)
	table.freeze(badger)

end

return badger