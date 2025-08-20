
--[[
	plugtilly
	roblox plugin utility
]]

export type DockWidgetPluginGuiInfo = {
	initally_enabled_should_override_restore: boolean,
	inital_dock_state: Enum.InitialDockState,
	initally_enabled: boolean,
	inital_size: vector,
	min_size: vector?,
	title: string?,
}

export type Setting<V> = (value: V?) -> V

local SETTING_NIL = "__PLUGTILLY_SETTING_NIL__"

local function SET_SETTING(plugin: Plugin, key: string, value: unknown)
	plugin:SetSetting(key, if value ~= nil then value else SETTING_NIL)
end

local function GET_SETTING(plugin: Plugin, key: string): any
	local value = plugin:GetSetting(key)
	return if value ~= SETTING_NIL then value else nil
end

--[[
	Gives the actual name of the plugin, as plugins that are loaded in via
	the plugins folder have "user_" appended to the beginning and ".rbxm"
 	appended at the end of their instance name.
]]
local function GET_NAME(plugin: Plugin): string
	local name = plugin.Name
	return string.match(name, "user_(.-)%.rbxm") or name
end

local plugtilly = {
	name = GET_NAME,
}

--[[
	Wrapper for Plugin:CreateDockWidgetPluginGui() that instead uses a table for info,
	and also will automatically set the name of the DockWidgetPluginGui based on the plugins name
	and the title if provided in the info table.
	It also sets the DockWidgetPluginGui to have the ZIndexBehavior of Sibling, and to not ResetOnSpawn.
]]
function plugtilly.create_dock_widget_plugin_gui(
	plugin: Plugin, id: string, info: DockWidgetPluginGuiInfo
): DockWidgetPluginGui
	local plugin_name = GET_NAME(plugin)
	local inital_size = info.inital_size
	local min_size = info.min_size or inital_size
	local title = info.title

	local gui = plugin:CreateDockWidgetPluginGui(
		id, DockWidgetPluginGuiInfo.new(
			info.inital_dock_state, info.initally_enabled,
			info.initally_enabled_should_override_restore,
			inital_size.x, inital_size.y,
			min_size.x, min_size.y
		)
	)

	if title then
		gui.Name = `{plugin_name} "{title}"`
		gui.Title = title
	else
		gui.Title = plugin_name
		gui.Name = plugin_name
	end

	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	return gui
end

--[[
	Simple function for migrating a old setting to a new setting
]]
function plugtilly.migrate_setting<V>(
	plugin: Plugin, old_key: string, new_setting: Setting<V>,
	converter: (value: any) -> V
)
	new_setting(converter(GET_SETTING(plugin, old_key)))
end

--[[
	Wrapper around Plugin:GetSetting() and Plugin:SetSetting(),
	that gives single function that when called it'll give you the current setting value,
	and calling it with an argument will also set the setting.
]]
function plugtilly.setting<V>(plugin: Plugin, key: string, default: V): Setting<V>
	if plugin:GetSetting(key) == nil then
		SET_SETTING(plugin, key, default)
	end

	return function(...)
		if select("#", ...) ~= 0 then
			local value = select(1, ...)
			SET_SETTING(plugin, key, value)
			return value
		end

		return GET_SETTING(plugin, key)
	end
end

return table.freeze(plugtilly)
