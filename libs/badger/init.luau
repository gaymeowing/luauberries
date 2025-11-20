
--[[
	badger
	badge service wrapper
]]

local BadgeService = game:GetService("BadgeService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

export type Badge = {
	read index: number,
	read id: number,
}

type AwardInfo = {
	start_of_last_attempt: number,
	read badgeid: number,
	read userid: number,
	attempts: number,
}

type PlayerInfo = {
	read owned: { [Badge]: true? },
	start_of_latest_fetch: number,
	ids_to_check: { number }?,
	amount_checked: number,
	fetch_success: boolean,
	fetch_thread: thread?,
	read userid: number,
	fetching: boolean,
}

local THREADS_WAITING_FOR_PLAYER_INFO = {} :: { [number]: { thread }? }
local CHECK_BADGES = BadgeService.CheckUserBadgesAsync
local NON_FETCHING_PLAYER_INFOS = {} :: { PlayerInfo }
local PLAYER_INFOS = {} :: { [number]: PlayerInfo }
local REMOVING_PLAYER_INFOS = {} :: { PlayerInfo }
local ID_TO_BADGE = {} :: { [number]: Badge? }
local FREE_FETCH_THREADS = {} :: { thread }
local AWARD_QUEUE = {} :: { AwardInfo }
local AWARD = BadgeService.AwardBadge
local IDS = {} :: { number }
local CHECK_IDS_INCREMENT = 9
--[[
	BadgeService:CheckUserBadgesAsync() allows 5 requests per player each minute
	so every 12 seconds we should be trying to fetch
--]]
local FETCH_DELAY = 12
local TOTAL_IDS = 0

local function SWAP_REMOVE(t: { any }, index: number)
	if index ~= 1 then
		local len = #t
		t[index] = t[len]
		t[len] = nil
	else
		t[1] = nil
	end
end

local function GET_INFO(player: Player): PlayerInfo?
	local userid = player.UserId
	local info = PLAYER_INFOS[userid]

	if player.Parent == Players and not info then
		local threads = THREADS_WAITING_FOR_PLAYER_INFO[userid]
		local thread = coroutine.running()

		if threads then
			table.insert(threads, thread)
		else
			THREADS_WAITING_FOR_PLAYER_INFO[userid] = { thread }
		end
		return coroutine.yield()
	end

	return info
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

local badger = {}

--[[
	Gets or creates a badge symbol for the given Id.
]]
function badger.get(id: number): Badge
	local badge_for_id = ID_TO_BADGE[id]

	if badge_for_id then
		return badge_for_id
	else
		TOTAL_IDS += 1

		local badge = table.freeze({
			index = TOTAL_IDS,
			id = id,
		})

		ID_TO_BADGE[id] = badge
		table.insert(IDS, id)
		return badge
	end
end

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

	if info then
		return info.amount_checked >= badge.index
			and info.owned[badge] ~= nil
	else
		return false
	end
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

	local function fetch_thread_runner(info: PlayerInfo)
		while true do
			local ids_to_check = info.ids_to_check :: { number }
			local userid = info.userid

			info.start_of_latest_fetch = os.clock()
			local success, awarded: { number } = pcall(
				CHECK_BADGES, BadgeService, userid, info.ids_to_check
			)

			if success then
				local amount_checked = info.amount_checked + #ids_to_check
				local owned = info.owned

				for _, id in ids_to_check do
					if table.find(awarded, id) ~= nil then
						owned[ID_TO_BADGE[id] :: any] = true
					end
				end

				if amount_checked == TOTAL_IDS then
					table.insert(FREE_FETCH_THREADS, info.fetch_thread :: thread)
					info.fetch_thread = nil
					info.ids_to_check = nil
				end
			end

			table.insert(NON_FETCHING_PLAYER_INFOS, info)
			info.fetch_success = success
			info.fetching = false
			info = coroutine.yield()
		end
	end

	local function GET_OR_CREATE_FETCH_THREAD(info: PlayerInfo)
		local fetch_thread = FREE_FETCH_THREADS[1]

		if fetch_thread then
			info.fetch_thread = fetch_thread
			task.defer(fetch_thread, info)
		else
			local thread = task.defer(fetch_thread_runner, info)
			info.fetch_thread = thread
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		local userid = player.UserId
		local info = PLAYER_INFOS[userid]
		PLAYER_INFOS[userid] = nil

		if info.fetching then
			table.insert(REMOVING_PLAYER_INFOS, info)
		else
			table.insert(FREE_FETCH_THREADS, info.fetch_thread :: thread)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		local userid = player.UserId
		local threads_waiting = THREADS_WAITING_FOR_PLAYER_INFO[userid]
		local info: PlayerInfo = {
			ids_to_check = table.move(IDS, 1, 1 + CHECK_IDS_INCREMENT, 1, {}),
			start_of_latest_fetch = nil :: any,
			fetch_thread = nil :: any,
			fetch_success = false,
			amount_checked = 0,
			fetching = true,
			userid = userid,
			owned = {},
		}

		GET_OR_CREATE_FETCH_THREAD(info)
		PLAYER_INFOS[userid] = info

		if threads_waiting then
			THREADS_WAITING_FOR_PLAYER_INFO[userid] = nil
			bulk_defer_threads(threads_waiting, info)
		end
	end)

	RunService.PostSimulation:Connect(function()
		local now = os.clock()

		for index, info in NON_FETCHING_PLAYER_INFOS do
			local amount_checked = info.amount_checked

			if
				amount_checked ~= TOTAL_IDS -- the thread hasn't successfully fetched if the player owns every badge
				and now - info.start_of_latest_fetch >= FETCH_DELAY -- it must be 12 seconds since the previous fetch started
			then
				local check_start = amount_checked + 1
				local check_end = check_start + CHECK_IDS_INCREMENT
				local ids_to_check = info.ids_to_check
				local fetch_thread = info.fetch_thread

				info.fetching = true

				if ids_to_check then
					table.clear(ids_to_check)
					info.ids_to_check = table.move(IDS, check_start, check_end, 1, ids_to_check)
				else
					info.ids_to_check = table.move(IDS, check_start, check_end, 1, {})
				end

				if fetch_thread then
					task.defer(fetch_thread, info)
				else
					GET_OR_CREATE_FETCH_THREAD(info)
				end

				SWAP_REMOVE(NON_FETCHING_PLAYER_INFOS, index)
			end
		end

		for index, info in REMOVING_PLAYER_INFOS do
			if info.fetching then
				continue
			end

			table.insert(FREE_FETCH_THREADS, info.fetch_thread :: thread)
			SWAP_REMOVE(REMOVING_PLAYER_INFOS, index)
		end

		for _, info in AWARD_QUEUE do

		end
	end)

	table.freeze(badger)

end

return badger
