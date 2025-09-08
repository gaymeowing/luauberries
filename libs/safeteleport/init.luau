
--[[
	safe teleport
	modified version of Roblox's safe teleport function on the docs for TeleportAsync with types
	and api improvements
]]

local TeleportService = game:GetService("TeleportService")
local retryer = require("@libs/retryer")

type BaseTeleportDataValue = string | buffer | Vector2 | vector | Vector3int16 | EnumItem | UDim | UDim2 | Rect |
	NumberRange | Vector2int16 | Color3 | Axes | DateTime | Random | Font | Faces | Content | Vector3

type TeleportDataValue = BaseTeleportDataValue | number

export type TeleportData =
	| { [BaseTeleportDataValue]: TeleportData | TeleportDataValue }
	| { [number]: TeleportData | TeleportDataValue }

export type TeleportResult = {
	read private_server_id: string,
	read access_code: string,
}

type BaseTeleportInfo<RS, AC, JI> = {
	--[[
		Flag to indicate if a reserved server should be
		allocated and the players should then be teleported to
		the allocated server.

		[Learn More](https://create.roblox.com/docs/reference/engine/classes/TeleportOptions#ShouldReserveServer)
	]]
	reserve_server: RS,
	--[[
		The reserved server access code that indicates the
		reserved server that the players(s) should be teleported to.

		[Learn More](https://create.roblox.com/docs/reference/engine/classes/TeleportOptions#ReservedServerAccessCode)
	]]
	access_code: AC,
	--[[
		Data to be passed to the destination with the player(s).

		[Learn More](<https://create.roblox.com/docs/reference/engine/classes/TeleportOptions#SetTeleportData>)
	]]
	data: TeleportData?,
	--[[
		The [`DataModel.JobId`](https://create.roblox.com/docs/reference/engine/classes/DataModel#JobId) of the server instance to
		teleport to.

		[Learn More](https://create.roblox.com/docs/reference/engine/classes/TeleportOptions#ServerInstanceId)
	]]
	jobid: JI,
}

type TeleportInfoWithResult =
	| BaseTeleportInfo<nil, string, nil>
	| BaseTeleportInfo<true, nil, nil>

type TeleportInfoWithoutResult =
	| BaseTeleportInfo<nil, string, nil>
	| BaseTeleportInfo<nil, nil, nil>

export type TeleportInfo =
	| TeleportInfoWithoutResult
	| TeleportInfoWithResult

type SafeTeleportPrototype = {
	__call:
		& ((
			safe_teleport: SafeTeleport, placeid: number, players_or_player: {Player} | Player
		) -> boolean)
		& ((
			safe_teleport: SafeTeleport, placeid: number, players_or_player: {Player} | Player, info: TeleportInfoWithoutResult
		) -> boolean)
		& ((
			safe_teleport: SafeTeleport, placeid: number, players_or_player: {Player} | Player, info: TeleportInfoWithResult
		) -> (boolean, TeleportResult))
}

type SafeTeleport = setmetatable<{
	attempt_limit: number,
	retry_delay: number,
	flood_delay: number,
}, SafeTeleportPrototype>

local TELEPORT_ASYNC = TeleportService.TeleportAsync
local FLOODED_ENUM = Enum.TeleportResult.Flooded
local FAILURE_ENUM = Enum.TeleportResult.Failure
local ATTEMPT_LIMIT = 5
local FLOOD_DELAY = 15
local RETRY_DELAY = 1

local function TELEPORT(placeid: number, players: { Player }, opts: TeleportOptions?): (boolean, TeleportResult?)
	local success, result: TeleportAsyncResult? = retryer.delay(
		RETRY_DELAY, ATTEMPT_LIMIT, TELEPORT_ASYNC,
		TeleportService, placeid, players, opts
	)

	if success then
		if result then
			return true, table.freeze({
				access_code = result.ReservedServerAccessCode,
				private_server_id = result.PrivateServerId,
			})
		end

		return true, nil
	else
		warn(`[SAFE TELEPORT]: teleport failed\n\tteleport_async_err: {result}`)
		return false, nil
	end
end

local safe_teleport_mt = {} :: SafeTeleportPrototype
local safe_teleport: SafeTeleport = setmetatable({
	attempt_limit = ATTEMPT_LIMIT,
	flood_delay = FLOOD_DELAY,
	retry_delay = RETRY_DELAY,
}, safe_teleport_mt)

function safe_teleport_mt.__call(safe_teleport, placeid, players_or_player, info)
	local players = if type(players_or_player) == "table" then players_or_player else { players_or_player }

	if not table.isfrozen(safe_teleport) then
		ATTEMPT_LIMIT = safe_teleport.attempt_limit
		FLOOD_DELAY = safe_teleport.flood_delay
		RETRY_DELAY = safe_teleport.retry_delay
		table.freeze(safe_teleport)
	end

	if info then
		local options = Instance.new("TeleportOptions")

		if info.reserve_server then
			options.ShouldReserveServer = info.reserve_server
		elseif info.access_code then
			options.ReservedServerAccessCode = info.access_code
		elseif info.jobid then
			options.ServerInstanceId = info.jobid
		end

		options:SetTeleportData(info.data :: any)
		return TELEPORT(placeid, players, options)
	else
		return TELEPORT(placeid, players)
	end
end

do

	TeleportService.TeleportInitFailed:Connect(function(
		player, result, teleport_error, placeid, options
	)
		if result == FLOODED_ENUM then
			task.wait(FLOOD_DELAY)
		elseif result == FAILURE_ENUM then
			task.wait(RETRY_DELAY)
		else
			-- if the teleport is invalid, report the error instead of retrying
			error(`[SAFE TELEPORT]: Teleport Init Failed\n\tresult: {result.Name}\n\terror: {teleport_error}`)
		end

		TELEPORT(placeid, { player }, options)
	end)

	table.freeze(safe_teleport_mt)

end

return safe_teleport
