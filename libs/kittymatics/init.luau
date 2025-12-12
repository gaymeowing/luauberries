
--[[
	kittymatics
	server physics replication for roblox, thats good unlike like how roblox by default replicates physics objects owned by the server
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

type ModelWithPrimaryPart = Model & {
	PrimaryPart: BasePart
}

type TagReplicationInfo = {
	model: Model,
	tag: string,
	metadata: buffer
}
