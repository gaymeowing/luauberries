
--[[
	textchat
	utility for TextChatService, making adding/removing, and muting TextSources easier
	alongside providing some utilities for chat visuals
]]

local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

type UserId = number

type PlayerOrUserId = Player | UserId

local CHANNEL_TO_SOURCES = {} :: { [TextChannel]: { [UserId]: TextSource } }
local USER_SOURCES = {} :: { [UserId]: { TextSource } }
local CHAT_COLORS = table.freeze({
	 -- BrickColor.new("Bright red").Color,
	Color3.new(253 / 255, 41 / 255, 67 / 255),
	 -- BrickColor.new("Bright blue").Color,
	Color3.new(1 / 255, 162 / 255, 255 / 255),
	 -- BrickColor.new("Earth green").Color,
	Color3.new(2 / 255, 184 / 255, 87 / 255),
	BrickColor.new("Bright violet").Color,
	BrickColor.new("Bright orange").Color,
	BrickColor.new("Bright yellow").Color,
	BrickColor.new("Light reddish violet").Color,
	BrickColor.new("Brick yellow").Color,
})

local function GET_ID_FROM_PLAYER_OR_USER_ID(player_or_user_id: PlayerOrUserId): number
	return if type(player_or_user_id) == "number" then 
			player_or_user_id 
		else 
			player_or_user_id.UserId
end

local function GET_COLOR_FOR_NAME(name: string): Color3
	local sub_number = if #name % 2 == 1 then -1 else 0
	local name_value = 0
	
	for index, codepoint in { string.byte(name, 1, #name) } do
		name_value += if (((#name - index) + 1) - sub_number) % 4 >= 2 then
				-codepoint
			else
				codepoint
	end
	
	return CHAT_COLORS[(name_value % #CHAT_COLORS) + 1]
end

local function GET_CHAT_PREFIX(
	display: string,
	name: string?,
	is_verified: boolean?,
	prefix: string?
): string
	return string.format(
		if is_verified then 
			"<font color=\"#%*\">\u{E000}%*</font>%*" 
		else 
			"<font color=\"#%*\">%*</font>%*", 
		GET_COLOR_FOR_NAME(name or display):ToHex(),
		if name then `{display}(@{name})` else display,
		prefix or ": "
	)
end

local textchat = {
	get_prefix = GET_CHAT_PREFIX
}

--[[
	Gives the chat color for a specific `player_or_name`, 
	if provided a player it uses `Player.Name` to give a chat color.
]]
function textchat.get_color(player_or_name: Player | string): Color3
	return GET_COLOR_FOR_NAME(
		if type(player_or_name) == "string" then player_or_name else player_or_name.Name
	)
end

function textchat.get_prefix_for_player(
	player: Player, include_name: boolean?, prefix: string?
): string
	return GET_CHAT_PREFIX(
		player.DisplayName, if include_name then player.Name else nil,
		player.HasVerifiedBadge, prefix
	)
end

--[[
	Removes the given `player_or_user_id` from the `channel`
]]
function textchat.remove_from_channel(
	player_or_user_id: PlayerOrUserId, channel: TextChannel
)
	local source = CHANNEL_TO_SOURCES[channel][GET_ID_FROM_PLAYER_OR_USER_ID(player_or_user_id)]

	if source then
		source:Destroy()
	end
end

--[[
	Adds the given `player` or `user_id` to the `channel`
]]
function textchat.add_to_channel(
	player_or_user_id: PlayerOrUserId, channel: TextChannel
): (TextSource?, boolean)
	return channel:AddUserAsync(
		GET_ID_FROM_PLAYER_OR_USER_ID(player_or_user_id)
	)
end

--[[
	Sets if a `player` or `user_id` is muted in all channels, or `channel` if provided
]]
function textchat.set_mute(
	player_or_user_id: PlayerOrUserId, is_muted: boolean, channel: TextChannel?
)
	local user_id = GET_ID_FROM_PLAYER_OR_USER_ID(player_or_user_id)

	if channel then
		local source = CHANNEL_TO_SOURCES[channel][user_id]

		if source then
			source.CanSend = is_muted
		end
	else
		for channel, sources in CHANNEL_TO_SOURCES do
			local source = CHANNEL_TO_SOURCES[channel][user_id]

			if source then
				source.CanSend = is_muted
			end
		end
	end
end

--[[
	Checks if the given `player_or_user_id` is muted in all channels, or a specific `channel`
]]
function textchat.is_muted(
	player_or_user_id: PlayerOrUserId, channel: TextChannel?
): boolean
	local user_id = GET_ID_FROM_PLAYER_OR_USER_ID(player_or_user_id)

	if channel then
		local source = CHANNEL_TO_SOURCES[channel][user_id]
		return source and source.CanSend
	else
		local sources = USER_SOURCES[user_id]
		local muted_count = 0

		for _, source in sources do
			if source.CanSend then
				muted_count += 1
			end
		end
		return #sources == muted_count
	end
end

if RunService:IsServer() then

	local function on_descendant_added(descendant: Instance)
		if descendant:IsA("TextSource") then
			local user_id = descendant.UserId
			local sources = USER_SOURCES[user_id]

			if sources then
				table.insert(sources, descendant)
			else
				USER_SOURCES[user_id] = { descendant }
			end

			-- text sources will only ever have TextChannels as their parents
			local channel_sources = CHANNEL_TO_SOURCES[descendant.Parent :: any]
		
			if channel_sources then
				if not channel_sources[user_id] then
					channel_sources[user_id] = descendant
				end
			end
		elseif descendant:IsA("TextChannel") then
			local sources = {}

			for _, child in descendant:GetChildren() do
				if child:IsA("TextSource") then
					sources[child.UserId] = child
				end
			end

			CHANNEL_TO_SOURCES[descendant] = sources
		end
	end

	TextChatService.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("TextSource") then
			local sources = USER_SOURCES[descendant.UserId]

			if sources then
				local index = table.find(sources, descendant)

				if index then
					if #sources == 1 then
						USER_SOURCES[descendant.UserId] = nil
					else
						sources[index] = sources[#sources]
						sources[#sources] = nil
					end
				end
			end
		elseif descendant:IsA("TextChannel") then
			CHANNEL_TO_SOURCES[descendant] = nil
		end
	end)

	TextChatService.DescendantAdded:Connect(on_descendant_added)

	Players.PlayerRemoving:Connect(function(player)
		USER_SOURCES[player.UserId] = nil
	end)

	task.spawn(function()
		for _, descendant in TextChatService:GetDescendants() do
			on_descendant_added(descendant)
		end
	end)
	
end

return table.freeze(textchat)
