
--[[
	loganalytics
	a simple wrapper around analytics service's bad api, that makes it into a decent api
]]

local AnalyticsService = game:GetService("AnalyticsService")

local MAX_CUSTOM_FIELDS: "3" = "3"
local MAX_CUSTOM_FIELDS_NUM = tonumber(MAX_CUSTOM_FIELDS)

type MAX_CUSTOM_FIELDS = typeof(MAX_CUSTOM_FIELDS)

type function CustomFieldsFunc(t, max_len)
	local max_len = tonumber(max_len:value())

	if t:is("table") then
		local len = 0

		for key, values in t:properties() do
			len += 1

			if len > max_len then
				error(`cannot have more fields than '{max_len}'`)
			end

			local value = values.write or values.read
			local value_tag = value.tag

			if
				value_tag ~= "number" or
				value_tag ~= "string" or
				((value_tag == "singleton") and (type(value:value()) ~= "string"))
			then
				error("value must be of type 'string' or 'number'")
			end

			local key_tag = key.tag

			if
				key_tag ~= "string" or
				(key_tag == "singleton" and (type(key:value()) ~= "string"))
			then
				error("key must be of type 'string'")
			end
		end

		return t
	else
		error(`type {t.tag} is not of type 'CustomFields'`)
	end
end

type function CustomEventMethods(eventsinfo, player, max_len, mt, class)
	if eventsinfo:is("table") then
		local nil_type = types.singleton(nil)
		local custom_event_methods = types.newtable(nil, nil, mt)
		local opt_number = types.unionof(types.number, nil_type)
		local fields_singleton = types.singleton("fields")
		local value_singleton = types.singleton("value")
		local max_len = tonumber(max_len:value())

		for name, info in eventsinfo:properties() do
			info = info.write or info.read

			if info:is("table") then
				local properties = info:properties()

				if next(properties) ~= nil then
					local real_info = types.newtable()
					local len = 0

					for key, type_or_enum in properties do
						len += 1

						if len > max_len then
							error(`cannot have more than {max_len} fields in custom fields for event '{name:value()}'`)
						end

						local info_value

						type_or_enum = type_or_enum.write or type_or_enum.read

						if type_or_enum:is("union") then
							info_value = type_or_enum
						elseif type_or_enum:is("singleton") then
							local type = type_or_enum:value()

							if type == "number" then
								info_value = types.number
							elseif type == "string" then
								info_value = types.string
							end
						end

						real_info:setreadproperty(key, info_value)
					end

					custom_event_methods:setreadproperty(name, types.newfunction({
						head = {
							class, player,
							types.newtable({
								[value_singleton] = opt_number,
								[fields_singleton] = types.unionof(real_info, nil_type)
							})
						}}, {}
					))
				end
			else
				custom_event_methods:setreadproperty(name, types.newfunction({
					head = { class, player, opt_number }
				}, {}))
			end
		end

		return custom_event_methods
	else
		error(`type '{eventsinfo.tag}' is not of type 'CustomEventsInfo'`)
	end
end

export type CustomFields<T> = CustomFieldsFunc<T, MAX_CUSTOM_FIELDS>

type ConvertedCustomFields = { [Enum.AnalyticsCustomFieldKeys]: string }?

type BaseAnalyticsInfo<T> = {
	custom_fields: CustomFields<T>?
}

export type AnalyticsCustomEventInfo<T> = BaseAnalyticsInfo<T> & {
	value: number?,
	name: string,
}

export type AnalyticsOnboardingFunnelStepInfo<T> = BaseAnalyticsInfo<T> & {
	step_name: string?,
	step: number,
}

export type AnalyticsProgressionInfo<T> = BaseAnalyticsInfo<T> & {
	status: Enum.AnalyticsProgressionType,
	level_name: string,
	path_name: string,
	level: number,
	step: number?,
}

export type AnalyticsEconomyInfo<T> = BaseAnalyticsInfo<T> & {
	transaction_type: Enum.AnalyticsEconomyTransactionType,
	flow_type: Enum.AnalyticsEconomyFlowType,
	ending_balance: number,
	currency_type: string,
	amount: number,
	item_sku: string?,
}

export type AnalyticsFunnelStepInfo<T> = BaseAnalyticsInfo<T> & {
	funnel_name: string,
	sessionid: string?,
	step_name: string?,
	step: number?,
}

type CustomLoggerMethodInfo<T> = {
	value: number?,
	fields: CustomFields<T>
}

type CustomEventsInfo = {
	[string]: {
		[string]: "number" | "string" | string,
	} | true
}

type LoggerPrototype = {
	onboarding_funnel_step: <T>(self: Logger, player: Player, info: AnalyticsOnboardingFunnelStepInfo<T>) -> (),
	progression: <T>(self: Logger, player: Player, info: AnalyticsProgressionInfo<T>) -> (),
	funnel_step: <T>(self: Logger, player: Player, info: AnalyticsFunnelStepInfo<T>) -> (),
	economy: <T>(self: Logger, player: Player, info: AnalyticsEconomyInfo<T>) -> (),
	__index: LoggerPrototype,
}

type Logger = typeof(setmetatable({} :: {}, {} :: LoggerPrototype))

local CUSTOM_FIELD_FORMAT = "%* = %*"
local FORMAT = string.format
local CUSTOM_FIELDS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01,
	Enum.AnalyticsCustomFieldKeys.CustomField02,
	Enum.AnalyticsCustomFieldKeys.CustomField03,
}
local TOO_MANY_ENTRIES_ERR = `[LOG_ANALYTICS]: cannot have more than '{MAX_CUSTOM_FIELDS}' custom fields`

@native
local function TABLE_TO_CUSTOM_FIELDS<T>(fields: CustomFields<T>): ConvertedCustomFields
	local return_tbl = {}
	local index = 1

	for key, value in fields do
		if index == MAX_CUSTOM_FIELDS_NUM then
			error(TOO_MANY_ENTRIES_ERR)
		else
			return_tbl[CUSTOM_FIELDS[index]] = FORMAT(CUSTOM_FIELD_FORMAT, key, value)
			index += 1
		end
	end
	return return_tbl
end

local function INFO_TO_CUSTOM_FIELDS<T>(info: BaseAnalyticsInfo<T>): ConvertedCustomFields?
	local custom_fields = info.custom_fields

	if custom_fields then
		return TABLE_TO_CUSTOM_FIELDS(custom_fields)
	else
		return nil
	end
end

--[[
	Logs an event used to track user actions stepping through an onboarding funnel.
	Funnel breakdowns will only consider the user and event values from the first step in a funnel session.
]]
local function onboarding_funnel_step<T>(player: Player, info: AnalyticsOnboardingFunnelStepInfo<T>)
	AnalyticsService:LogOnboardingFunnelStepEvent(
		player, info.step, info.step_name, INFO_TO_CUSTOM_FIELDS(info)
	)
end

--[[
	Logs an event for when a user has started, completed, or failed a level attempt.
]]
local function progression<T>(player: Player, info: AnalyticsProgressionInfo<T>)
	AnalyticsService:LogProgressionEvent(
		player, info.path_name, info.status, info.level,
		info.level_name, INFO_TO_CUSTOM_FIELDS(info)
	)
end

--[[
	Logs an event used to track user actions stepping through a pre-planned funnel.
	Funnel breakdowns will only consider the user and event values from the first step in a funnel session.
]]
local function funnel_step<T>(player: Player, info: AnalyticsFunnelStepInfo<T>)
	AnalyticsService:LogFunnelStepEvent(
		player, info.funnel_name, info.sessionid, info.step,
		info.step_name, INFO_TO_CUSTOM_FIELDS(info)
	)
end

--[[
	Logs an event used to track custom metrics of a user in experience.
	For additional information, see [Custom Events](https://create.roblox.com/docs/production/analytics/custom-events).
]]
local function custom<T>(player: Player, info: AnalyticsCustomEventInfo<T>)
	AnalyticsService:LogCustomEvent(
		player, info.name, info.value, INFO_TO_CUSTOM_FIELDS(info)
	)
end

--[[
	Logs an event used to track player actions related in experience.
]]
local function economy<T>(player: Player, info: AnalyticsEconomyInfo<T>)
	AnalyticsService:LogEconomyEvent(
		player, info.flow_type, info.currency_type, info.amount, info.ending_balance,
		info.transaction_type :: any, info.item_sku, INFO_TO_CUSTOM_FIELDS(info)
	)
end

local logger = {} :: LoggerPrototype
logger.__index = logger

function logger.onboarding_funnel_step(logger, player, info)
	onboarding_funnel_step(player, info)
end

function logger.progression(logger, player, info)
	progression(player, info)
end

function logger.funnel_step(logger, player, info)
	funnel_step(player, info)
end

function logger.economy(logger, player, info)
	economy(player, info)
end

local loganalytics = {
	onboarding_funnel_step = onboarding_funnel_step,
	funnel_step = funnel_step,
	progression = progression,
	economy = economy,
	custom = custom,
}

--[[
	Creates a custom logger with methods added for custom_events described in the `custom_events` table.
	Custom event methods are fully typed, and allow for strictly defining what can be put in as custom fields.
]]
function loganalytics.logger<E>(
	custom_events: E & CustomEventsInfo
): Logger & CustomEventMethods<E, Player, MAX_CUSTOM_FIELDS, LoggerPrototype, Logger>
	local custom_event_methods = {}

	for name, custom_fields in custom_events do
		if type(custom_fields) == "table" then
			custom_event_methods[name] = function<T>(self: Logger, player: Player, info: CustomLoggerMethodInfo<T>)
				AnalyticsService:LogCustomEvent(player, name, info.value, TABLE_TO_CUSTOM_FIELDS(info.fields))
			end
		else
			custom_event_methods[name] = function(self: Logger, player: Player, value: number?)
				AnalyticsService:LogCustomEvent(player, name, value)
			end
		end
	end

	return table.freeze(setmetatable(custom_event_methods, logger)) :: any
end

table.freeze(logger)

return table.freeze(loganalytics)
