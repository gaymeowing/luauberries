
-- rbxthumb
-- module for easily creating roblox thumbnail urls, based on nevermores rbxthumbutil
-- although with types 

type PlayerThumbnailFormatter<S> = (player: Player, size: S?, circular: boolean?) -> Content
type ThumbnailFormatter<S> = (id: number, size: S?, circular: boolean?) -> Content

export type ThumbnailType = "Asset" | "Avatar" | "AvatarHeadShot" | "BadgeIcon"  | 
	"BundleThumbnail" | "GameIcon" | "GamePass" | "GroupIcon" | "Outfit" | "FontFamily" | 
	"AvatarBust"

export type ThumbnailSize = "1200×80" | "720x720" | "420x420" |"352x352" | "150x150" | 
	"100x100" | "60x60" | "50x50" | "48x48" | "180x180"

type AvatarHeadshotThumbnailSize = "48×48" | "60×60" | "100×100" | "150×150" | "180×180" |
	"352×352" | "420×420"

type AvatarBustThumbnailSize = "100x100" | "150x15" | "75×75" | "100×100" | "150×150" | "180×180" | 
	"352×352" | "420×420"

type FullAvatarThumbnailSize = "50×50" | "60×60" | "75×75" | "100×100" | "150×150" | "180×180" | 
	"352×352" | "420×420"

local BASE_URI = "rbxthumb://type=%*&id=%*&w=%*&h=%*"
local CIRCULAR_URI = `{BASE_URI}&filters=circular`
local ASSET_ENUM = Enum.AvatarItemType.Asset
local CREATE_CONTENT = Content.fromUri
local BUNDLE_STR = "BundleThumbnail"
local SPLIT_PATTERN = "(%*)x(%*)"
local FORMAT = string.format
local DEFUALT_SIZE_NUM = 150
local MATCH = string.match
local ASSET_STR = "Asset"

local function RAW_FORMAT(
	id: number,
	type: ThumbnailType,
	width: number | string,
	height: number | string,
	circular: boolean?
): Content
	return CREATE_CONTENT(FORMAT(
		if circular then CIRCULAR_URI else BASE_URI,
		type,
		id,
		width,
		height
	))
end

local function SPLIT_SIZE(
	size: ThumbnailSize?,
	default_width: number,
	default_height: number
): (number | string, number | string)
	if size then
		local width, height = MATCH(size, SPLIT_PATTERN)
		return width or default_width, height or default_height
	else
		return default_width, default_height
	end
end

local function FORMAT_RBXTHUMB_URL(
	id: number, 
	type: ThumbnailType,
	size: ThumbnailSize?,
	circular: boolean?
): Content
	local width, height = SPLIT_SIZE(size, DEFUALT_SIZE_NUM, DEFUALT_SIZE_NUM)
	return RAW_FORMAT(id, type, width, height, circular)
end

local function CREATE_PLAYER_FORMATTER<S>(
	type: ThumbnailType,
	default_width: number?,
	default_height: number?
): PlayerThumbnailFormatter<S>
	local defualt_height = default_height or DEFUALT_SIZE_NUM
	local defualt_width = default_width or DEFUALT_SIZE_NUM

	return function(player: Player, size: S?, circular: boolean?): Content
		local width, height = SPLIT_SIZE(size :: any, defualt_width, defualt_height)
		return ( RAW_FORMAT(player.UserId, type, width, height, circular) )
	end
end

local function CREATE_FORMATTER<S>(
	type: ThumbnailType,
	default_width: number?,
	default_height: number?
): ThumbnailFormatter<S>
	local defualt_height = default_height or DEFUALT_SIZE_NUM
	local defualt_width = default_width or DEFUALT_SIZE_NUM

	return function(id: number, size: S?, circular: boolean?): Content
		local width, height = SPLIT_SIZE(size :: any, defualt_width, defualt_height)
		return ( RAW_FORMAT(id, type, width, height, circular) )
	end
end

local rbxthumb = {
	player_headshot = CREATE_PLAYER_FORMATTER("AvatarHeadShot") :: PlayerThumbnailFormatter<AvatarHeadshotThumbnailSize>,
	player_bust = CREATE_PLAYER_FORMATTER("AvatarBust") :: PlayerThumbnailFormatter<AvatarBustThumbnailSize>,
	avatar_headshot = CREATE_FORMATTER("AvatarHeadShot") :: ThumbnailFormatter<AvatarHeadshotThumbnailSize>,
	player_full = CREATE_PLAYER_FORMATTER("Avatar") :: PlayerThumbnailFormatter<FullAvatarThumbnailSize>,
	avatar_bust = CREATE_FORMATTER("AvatarBust") :: ThumbnailFormatter<AvatarBustThumbnailSize>,
	bundle = CREATE_FORMATTER("BundleThumbnail") :: ThumbnailFormatter<"150x150" | "420x420">,
	avatar_full = CREATE_FORMATTER("Avatar") :: ThumbnailFormatter<FullAvatarThumbnailSize>,
	fontfamily = CREATE_FORMATTER("FontFamily", 1200, 80) :: ThumbnailFormatter<"1200×80">,
	group = CREATE_FORMATTER("GroupIcon") :: ThumbnailFormatter<"150x150" | "420x420">,
	outfit = CREATE_FORMATTER("Outfit") :: ThumbnailFormatter<"150x150" | "420x420">,
	asset = CREATE_FORMATTER("Asset") :: ThumbnailFormatter<"150x150" | "420x420">,
	experience = CREATE_FORMATTER("GameIcon"):: ThumbnailFormatter<"150x150">,
	gamepass = CREATE_FORMATTER("GamePass") :: ThumbnailFormatter<"150x150">,
	badge = CREATE_FORMATTER("BadgeIcon") :: ThumbnailFormatter<"150x150">,
}

function rbxthumb.avatar_item(
	avatar_item_type: Enum.AvatarItemType,
	id: number, 
	size: ("150x150" | "420x420")?,
	circular: boolean?
): Content
	return if avatar_item_type == ASSET_ENUM then
		FORMAT_RBXTHUMB_URL(id, ASSET_STR :: any, size, circular)
	else 
		FORMAT_RBXTHUMB_URL(id, BUNDLE_STR :: any, size, circular)
end

return table.freeze(rbxthumb)