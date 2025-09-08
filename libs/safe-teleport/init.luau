
--[[
    safe teleport
    modified version of robloxs safe teleport function on the docs for TeleportAsync with types
    and api improvements
]]

local TeleportService = game:GetService("TeleportService")
local retryer = require("@libs/retryer")

type BaseTeleportDataValue = string | buffer | Vector2 | vector | Vector3int16 | EnumItem | UDim | UDim2 | Rect | 
    NumberRange | Vector2int16 | Color3 | Axes | DateTime | Random | Font | Faces | Content | Vector3

type TeleportDataValue = BaseTeleportDataValue | number

export type TeleportData = { [number]: TeleportData | TeleportDataValue } | { [BaseTeleportDataValue]: TeleportData | TeleportDataValue }

export type SafeTeleportResult = {
    private_server_id: string,
    access_code: string,
}

export type SafeTeleportInfo = {
    reserve_server: boolean?,
    access_code: string?,
    data: TeleportData?,
    jobid: string?,
}

local FAILED_RESULT: SafeTeleportResult = table.freeze({
    private_server_id = "0",
    access_code = "",
})
local TELEPORT_ASYNC = TeleportService.TeleportAsync
local ATTEMPT_LIMIT = 5
local FLOOD_DELAY = 15
local RETRY_DELAY = 1

local function TELEPORT(placeid: number, players: { Player }, opts: TeleportOptions?): (boolean, SafeTeleportResult)
	local success, result = retryer.delay(
        RETRY_DELAY, ATTEMPT_LIMIT, TELEPORT_ASYNC, 
        TeleportService, placeid, players, opts
    )

	if success then
        return success, table.freeze({
            access_code = result.ReservedServerAccessCode,
            private_server_id = result.PrivateServerId,
        })
    else
		warn(`[SAFE TELEPORT]: teleport failed\n\tteleport_async_err: {result}`)
        return success, FAILED_RESULT
	end
end

local safe_teleport_mt = {}
local safe_teleport = setmetatable({
    attempt_limit = ATTEMPT_LIMIT,
    flood_delay = FLOOD_DELAY,
    retry_delay = RETRY_DELAY,
}, safe_teleport_mt)

function safe_teleport_mt.__call(
    safe_teleport: typeof(safe_teleport), placeid: number,
    players_or_player: {Player} | Player, info: SafeTeleportInfo?
): (boolean, SafeTeleportResult)
    local players = if type(players_or_player) == "table" then players_or_player else { players_or_player }

    if not table.isfrozen(safe_teleport) then
        ATTEMPT_LIMIT = safe_teleport.attempt_limit
        FLOOD_DELAY = safe_teleport.flood_delay
        RETRY_DELAY = safe_teleport.retry_delay
        table.freeze(safe_teleport)
    end

    if info then
        local options = Instance.new("TeleportOptions")
        options.ReservedServerAccessCode = info.access_code :: any
        options.ShouldReserveServer = info.reserve_server :: any
        options.ServerInstanceId = info.jobid :: any
        options:SetTeleportData(info.data)
        return TELEPORT(placeid, players, options)
    else
        return TELEPORT(placeid, players)
    end
end

do

    TeleportService.TeleportInitFailed:Connect(function(player, result, err, placeid, opts)
	    if result == Enum.TeleportResult.Flooded then
		    task.wait(FLOOD_DELAY)
	    elseif result == Enum.TeleportResult.Failure then
	    	task.wait(RETRY_DELAY)
	    else
		    -- if the teleport is invalid, report the error instead of retrying
	    	error(`[SAFE TELEPORT]: teleport init failed\n\tresult_type: {result.Name}\n\terror: {err}`)
	    end

	    TELEPORT(placeid, player, opts)
    end)

    table.freeze(safe_teleport_mt)

end

return safe_teleport
