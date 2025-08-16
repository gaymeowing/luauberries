
--[[
	leaderstats
	roblox leaderstats wrapper providing a nicer api, compared to dealing with instances directly 
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

type AllowedValues = number | string

type AllowedDefaults = "float" | "string" | "integer" | AllowedValues

type Stats = { [string]: AllowedValues }

type LeaderstatsFolder =  Folder & { [string]: ValueBase & { Value: AllowedValues } }

-- this exists for no reason other than "well theres an integer pattern for having an integer with a number literal so why not for floats"
type FloatPattern = "^f(%-?%d+%.?%d*)$"

type IntegerPattern = "^i(%-?%d+)$"

type function LeaderstatsCreator(stats: type, player_type: type)
	if stats.tag ~= "table" then
		error("stats is not of type 'table'")
	end

	local integer_pattern = IntegerPattern:value()
	local float_pattern = FloatPattern:value()
	local new_partial_stats = types.newtable()
	local new_stats = types.newtable()

	for key, value in stats:properties() do
		if key:is("singleton") then
			local raw_key = key:value()

			if type(raw_key) ~= "string" then
				error(`key '{key}' does not have subtype 'string'`)
			end
		else
			error(`key '{key}' is not a type singleton`)
		end

		value = value.read or value.write
		local prop_value = value

		if value.tag == "singleton" then
			local raw_value = value:value()

			if 
				raw_value == "float" or
				raw_value == "integer" or
				type(raw_value) == "number" or
				string.match(raw_value, float_pattern) or
				string.match(raw_value, integer_pattern)
			then
				prop_value = types.number
			elseif raw_value == "string" or type(raw_value) == "string" then
				prop_value = types.string
			else
				error(`value '{value}' for key '{key}' is not of type '"integer" | "string" | "float" | number | string'`)
			end
		elseif 
			-- using ~= for all these checks didn't work :(
			not (value == types.number or 
			value == types.string or 
			value.tag == "union")
		then
			error(`value '{value}' for key '{key}' is not of type 'string | number' or is a type union made up of 'string | number'`)
		end

		new_partial_stats:setproperty(key, types.optional(prop_value))
		new_stats:setproperty(key, prop_value)
	end

	return types.newtable(nil, { 
		index = player_type, readresult = new_stats, 
		writeresult = new_partial_stats
	})
end

export type Leaderstats<S = {}> = LeaderstatsCreator<S, Player>

local PLAYER_TO_FOLDER = {} :: { [Player]: LeaderstatsFolder? }
local STATS_TO_FOLDER = {} :: { [Stats]: LeaderstatsFolder }
local LEADERSTATS_FOLDER_TEMPLATE = Instance.new("Folder")
local INTEGER_PATTERN: IntegerPattern = "^i(%-?%d+)$"
local FLOAT_PATTERN: FloatPattern = "^f(%-?%d+%.?%d*)$"
local PLAYER_TO_STATS = {} :: { [Player]: Stats }
local LEADERSTATS_FOLDER_NAME = "leaderstats"
local LEADERSTATS_OBJECT: { [Player]: Stats }
local STAT_NAMES = {} :: { string }
local FULL_LINES: { string }
local LINES: { string }

local leaderstats = {}
local stats = {}

local function STATS_TO_STRING(stats: Stats, indent: string, outer_indent: string): string
	local folder = STATS_TO_FOLDER[stats]

	for index, stat_name in STAT_NAMES do
		local stat_instance = folder[stat_name]
		
		LINES[index] = if stat_instance:IsA("StringValue") then
				`{stat_name} = '{stat_instance.Value}'`
			else
				`{stat_name} = {stat_instance.Value}`
	end

	local final = string.format(
		"{\n%*%*,\n%*}", indent,
		table.concat(LINES, string.format(",\n%*", indent)),
		outer_indent
	)
	table.clear(LINES)
	return final
end

local function GET_OR_CREATE_STATS(player: Player, folder: LeaderstatsFolder): Stats
	local player_stats = PLAYER_TO_STATS[player]

	if player_stats then
		return player_stats :: any
	else
		local new_player_stats = table.freeze(setmetatable({}, stats)) :: any
		PLAYER_TO_STATS[player] = new_player_stats
		STATS_TO_FOLDER[new_player_stats] = folder
		return new_player_stats
	end
end

local function GET_OR_CREATE_FOLDER(player: Player): LeaderstatsFolder
	local folder = PLAYER_TO_FOLDER[player]

	if folder then
		return folder :: any
	else
		local folder = player:FindFirstChild(LEADERSTATS_FOLDER_NAME) :: any
		
		if folder then
			PLAYER_TO_FOLDER[player] = folder
			return folder
		else
			local new_folder = LEADERSTATS_FOLDER_TEMPLATE:Clone()
			PLAYER_TO_FOLDER[player] = new_folder
			new_folder.Parent = player
			return new_folder 
		end
	end
end

function stats.__newindex(stats: Stats, stat: string, value: AllowedValues): AllowedValues
	STATS_TO_FOLDER[stats][stat].Value = value
	return value
end

function stats.__index(stats: Stats, stat: string): AllowedValues
	return STATS_TO_FOLDER[stats][stat].Value
end

function stats.__tostring(stats: Stats): string
	return STATS_TO_STRING(stats, "\t", "")
end

function leaderstats.__newindex(leaderstats: Leaderstats, player: Player, partial_stats: { [string]: AllowedValues? }?): Stats
	if player and player:IsDescendantOf(game) then
		local folder = GET_OR_CREATE_FOLDER(player)

		if partial_stats then
			for _, stat in STAT_NAMES do
				local new_value = partial_stats[stat]

				if new_value then
					folder[stat].Value = new_value
				end
			end
		end
		return GET_OR_CREATE_STATS(player, folder)
	else
		error(`[LEADERSTATS]: cannot set key '{player}', as key is not of type 'Player'`)
	end
end

function leaderstats.__index(leaderstats: Leaderstats, player: Player): Stats
	if player and player:IsDescendantOf(game) then
		return GET_OR_CREATE_STATS(player, GET_OR_CREATE_FOLDER(player))
	else
		error(`[LEADERSTATS]: cannot set key '{player}', as key is not of type 'Player'`)
	end
end

function leaderstats.__tostring(leaderstats: Leaderstats): string
	local index = 1

	for player, stats in leaderstats do
		FULL_LINES[index] = string.format(
			"\t[Player<\"%*\", %*>] = %*", player.DisplayName, player.UserId,
			STATS_TO_STRING(stats :: any, "\t\t", "\t")
		)
		index += 1
	end

	local final = `\{\n{table.concat(FULL_LINES, ",\n\t")}\n\}`
	table.clear(FULL_LINES)
	return final
end

--[[
	Creates a new leaderstats object
]]
local function create<S>(stats: S): Leaderstats<S>
	if LEADERSTATS_OBJECT then
		error("[LEADERSTATS]: cannot have more than 1 leaderstats object")
	end

	LEADERSTATS_OBJECT = setmetatable({}, leaderstats)
	local stat_amount = 0

	for name, value in stats do
		local integer_match = tonumber(string.match(value, INTEGER_PATTERN))
		local float_match = not integer_match and tonumber(string.match(value, FLOAT_PATTERN))
		local stat_instance: ValueBase

		if value == "string" then
			stat_instance = Instance.new("StringValue")
		elseif value == "float" then
			stat_instance = Instance.new("NumberValue")
		elseif value == "integer" then
			stat_instance = Instance.new("IntValue")
		elseif type(value) == "number" then
			stat_instance = Instance.new("NumberValue")
			stat_instance.Value = value
		elseif integer_match then
			stat_instance = Instance.new("IntValue")
			stat_instance.Value = integer_match
		elseif float_match then
			stat_instance = Instance.new("NumberValue")
			stat_instance.Value = float_match
		else
			stat_instance =  Instance.new("StringValue")
			stat_instance.Value = value
		end

		stat_instance.Parent = LEADERSTATS_FOLDER_TEMPLATE
		table.insert(STAT_NAMES, name)
		stat_instance.Name = name
		stat_amount += 1
	end

	FULL_LINES = table.create(Players.MaxPlayers) :: any
	LINES = table.create(stat_amount) :: any
	return LEADERSTATS_OBJECT :: any
end

do

	--[[
		this is to fix the edge case where the folder is created on the client,
		when its going to be created on the server but like just hasnt yet
	--]]
	if RunService:IsClient() then
		Players.DescendantAdded:Connect(function(instance)
			local parent = instance.Parent :: any

			if parent and instance.Name == LEADERSTATS_FOLDER_NAME then
				local folder = PLAYER_TO_FOLDER[parent]

				if folder then
					folder:Destroy()
				end
				PLAYER_TO_FOLDER[parent] = instance
			end
		end)
	end
	
	Players.PlayerRemoving:Connect(function(player)
		local stats = PLAYER_TO_STATS[player]

		if stats then
			PLAYER_TO_FOLDER[player] = nil
			PLAYER_TO_STATS[player] = nil
			STATS_TO_FOLDER[stats] = nil
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		if LEADERSTATS_OBJECT then
			GET_OR_CREATE_STATS(
				LEADERSTATS_OBJECT, player, GET_OR_CREATE_FOLDER(player)
			)
		end
	end)

	LEADERSTATS_FOLDER_TEMPLATE.Name = LEADERSTATS_FOLDER_NAME
	table.freeze(leaderstats)
	table.freeze(stats)

end

return create
