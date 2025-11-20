
--[[
	player loaded
	handles callbacks for a player loaded remote, because having a player loaded remote
	is a good idea so you don't fill up the remote queue for a player
	before they've been able to receive remote events
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local character = require("@libs/character")

export type PlayerLoadedCallback = (player: Player & { Character: character.Character }) -> ()

local CALLBACKS_WAITING_FOR_NEXT_PLAYER = {} :: { PlayerLoadedCallback }
local PLAYERS_LOADED = table.create(Players.MaxPlayers) :: { Player }
local THREADS_WAITING_FOR_PLAYERS = {} :: { [Player]: { thread } }
local THREADS_WAITING_FOR_NEXT_PLAYER = {} :: { thread }
local CALLBACKS = {} :: { PlayerLoadedCallback }
local REMOTE_NAME = "PlayerLoaded"
local LOADED_COUNT = 0

local function SWAP_REMOVE(t: { unknown }, v: unknown)
	local index = table.find(t, v)

	if index then
		local length = #t

		if index ~= length then
			t[index] = t[length]
			t[length] = nil
		else
			t[length] = nil
		end
	end
end

local function CREATE_DISCONNECT<V>(t:{ V }, v: V): () -> ()
	return function()
		SWAP_REMOVE(t, v)
	end
end

local player_loaded = {}

--[[
	Calls the provided callback everytime a player loads in,
	unless disconnected using the returned disconnect function.
]]
function player_loaded.on(f: PlayerLoadedCallback, dont_run_for_existing: true?): () -> ()
	if not dont_run_for_existing then
		for _, player in PLAYERS_LOADED do
			task.defer(f, player :: any)
		end
	end

	table.insert(CALLBACKS, f)
	return CREATE_DISCONNECT(CALLBACKS, f)
end

--[[
	Yields the current thread until the provided player loads in,
	or if the player leaves the game it'll then resume the current thread
	with nil instead of the player.
]]
function player_loaded.wait_for_player(player: Player): Player?
	if not table.find(PLAYERS_LOADED, player) then
		local threads = THREADS_WAITING_FOR_PLAYERS[player]

		if threads then
			table.insert(threads, coroutine.running())
		else
			THREADS_WAITING_FOR_PLAYERS[player] = { coroutine.running() }
		end
		return coroutine.yield()
	else
		return player
	end
end

--[[
	Calls the provided callback with the next player that loads in,
	unless disconnected using the returned disconnect function.
]]
function player_loaded.once(f: PlayerLoadedCallback): () -> ()
	table.insert(CALLBACKS_WAITING_FOR_NEXT_PLAYER, f)
	return CREATE_DISCONNECT(CALLBACKS_WAITING_FOR_NEXT_PLAYER, f)
end

--[[
	Yields the current thread, and resumes it with the next player that loads in
]]
function player_loaded.wait(): Player
	table.insert(THREADS_WAITING_FOR_NEXT_PLAYER, coroutine.running())
	return coroutine.yield()
end

do

	local function run_for_player(player: Player)
		local threads = THREADS_WAITING_FOR_PLAYERS[player]

		LOADED_COUNT += 1
		PLAYERS_LOADED[LOADED_COUNT] = player

		if threads then
			THREADS_WAITING_FOR_PLAYERS[player] = nil

			for _, thread in threads do
				task.defer(thread, player)
			end
		end

		for _, callback in CALLBACKS_WAITING_FOR_NEXT_PLAYER do
			task.defer(callback, player :: any)
		end

		for _, thread in THREADS_WAITING_FOR_NEXT_PLAYER do
			task.defer(thread, player)
		end

		for _, callback in CALLBACKS do
			task.defer(callback, player :: any)
		end

		table.clear(CALLBACKS_WAITING_FOR_NEXT_PLAYER)
		table.clear(THREADS_WAITING_FOR_NEXT_PLAYER)
	end

	if RunService:IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Parent = ReplicatedStorage
		remote.Name = REMOTE_NAME

		remote.OnServerEvent:Connect(function(loaded_player)
			if not table.find(PLAYERS_LOADED, loaded_player) then
				remote:FireClient(loaded_player, PLAYERS_LOADED)
				run_for_player(loaded_player)

				for _, player in PLAYERS_LOADED do
					remote:FireClient(player, loaded_player)
				end
			end
		end)
	else
		local remote: RemoteEvent = ReplicatedStorage:WaitForChild(REMOTE_NAME) :: any

		remote.OnClientEvent:Connect(function(player_or_players: Player | { Player })
			if type(player_or_players) == "table" then
				for _, player in player_or_players do
					if not table.find(PLAYERS_LOADED, player) then
						run_for_player(player)
					end
				end
			else
				run_for_player(player_or_players)
			end
		end)

		task.defer(function()
			if not game:IsLoaded() then
				game.Loaded:Wait()
			end

			remote:FireServer()
			run_for_player(Players.LocalPlayer)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		local threads = THREADS_WAITING_FOR_PLAYERS[player]

		if threads then
			THREADS_WAITING_FOR_PLAYERS[player] = nil

			for _, thread in threads do
				task.defer(thread, nil)
			end
		end

		SWAP_REMOVE(PLAYERS_LOADED, player)
	end)

end

return table.freeze(player_loaded)
