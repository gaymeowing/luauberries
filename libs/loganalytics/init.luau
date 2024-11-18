
-- loganalytics
-- a simple wrapper around analytics service's bad api, that makes it into a decent api

local AnalyticsService = game:GetService("AnalyticsService")

export type CustomFields = { [string]: string }

type ConvertedCustomFields = { [Enum.AnalyticsCustomFieldKeys]: string }?

type BaseAnalyticsInfo = {
	custom_fields: CustomFields?
}

export type AnalyticsCustomEventInfo = BaseAnalyticsInfo & {
	value: number?,
	name: string,
}

export type AnalyticsOnboardingFunnelStepInfo = BaseAnalyticsInfo & {
	step_name: string?,
	step: number,
}

export type AnalyticsProgressionInfo = BaseAnalyticsInfo & {
	status: Enum.AnalyticsProgressionType,
	level_name: string,
	path_name: string,
	level: number,
	step: number?,
}

export type AnalyticsEconomyInfo = BaseAnalyticsInfo & {
	transaction_type: Enum.AnalyticsEconomyTransactionType,
	flow_type: Enum.AnalyticsEconomyFlowType,
	ending_balance: number,
	currency_type: string,
	amount: number,
	item_sku: string?,
}

export type AnalyticsFunnelStepInfo = BaseAnalyticsInfo & {
	funnel_name: string,
	sessionid: string?,
	step_name: string?,
	step: number?,
}

type CustomLoggerMethodInfo<F = CustomFields> = {
	value: number?,
	fields: F,
}

type LoggerPrototype = {
	event: (<S, N, F>(self: S & Logger, name: N & string, fields: F & {}) -> S & { [N]: (self: Logger, player: Player, info: CustomLoggerMethodInfo<F>) -> () }) & 
		(<S, N>(self: S & Logger, name: N & string) -> S & { [N]: (self: Logger, player: Player, value: number?) -> () }),
	onboarding_funnel_step: (self: Logger, player: Player, info: AnalyticsOnboardingFunnelStepInfo) -> (),
	progression: (self: Logger, player: Player, info: AnalyticsProgressionInfo) -> (),
	funnel_step: (self: Logger, player: Player, info: AnalyticsFunnelStepInfo) -> (),
	economy: (self: Logger, player: Player, info: AnalyticsEconomyInfo) -> (),
	__index: LoggerPrototype,
}

export type Logger = typeof(setmetatable({} :: {}, {} :: LoggerPrototype))

local CUSTOM_FIELD_FORMAT = "%* = %*"
local FORMAT = string.format
local CUSTOM_FIELDS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01,
	Enum.AnalyticsCustomFieldKeys.CustomField02,
	Enum.AnalyticsCustomFieldKeys.CustomField03,
}
local MAX_CUSTOM_FIELDS = #CUSTOM_FIELDS
local TOO_MANY_ENTRIES_ERR = `[LOG_ANALYTICS] cannot have more than {MAX_CUSTOM_FIELDS} custom fields`

@native
local function TABLE_TO_CUSTOM_FIELDS(fields: CustomFields): ConvertedCustomFields
	local return_tbl = {}
	local index = 1

	for key, value in fields do
		if index == MAX_CUSTOM_FIELDS then
			error(TOO_MANY_ENTRIES_ERR)
		else
			return_tbl[CUSTOM_FIELDS[index]] = FORMAT(CUSTOM_FIELD_FORMAT, key, value)
			index += 1
		end
	end
	return return_tbl
end

local function INFO_TO_CUSTOM_FIELDS(info: BaseAnalyticsInfo): ConvertedCustomFields?
	local custom_fields = info.custom_fields

	if custom_fields then
		return TABLE_TO_CUSTOM_FIELDS(custom_fields)
	else
		return nil
	end
end

local function onboarding_funnel_step(player: Player, info: AnalyticsOnboardingFunnelStepInfo)
	AnalyticsService:LogOnboardingFunnelStepEvent(
		player, info.step, info.step_name, INFO_TO_CUSTOM_FIELDS(info)
	)
end

local function progression(player: Player, info: AnalyticsProgressionInfo)
	AnalyticsService:LogProgressionEvent(
		player, info.path_name, info.status, info.level,
		info.level_name, INFO_TO_CUSTOM_FIELDS(info)
	)
end

local function funnel_step(player: Player, info: AnalyticsFunnelStepInfo)
	AnalyticsService:LogFunnelStepEvent(
		player, info.funnel_name, info.sessionid, info.step, 
		info.step_name, INFO_TO_CUSTOM_FIELDS(info)
	)
end

local function custom(player: Player, info: AnalyticsCustomEventInfo)
	AnalyticsService:LogCustomEvent(
		player, info.name, info.value, INFO_TO_CUSTOM_FIELDS(info)
	)
end

local function economy(player: Player, info: AnalyticsEconomyInfo)
	AnalyticsService:LogEconomyEvent(
		player, info.flow_type, info.currency_type, info.amount, info.ending_balance, 
		info.transaction_type :: any, info.item_sku, INFO_TO_CUSTOM_FIELDS(info)
	)
end

local logger = {} :: LoggerPrototype
logger.__index = logger

logger.event = function(logger: any, name: string, fields: CustomFields?)
	if fields then
		logger[name] = function(player: Player, info: CustomLoggerMethodInfo)
			AnalyticsService:LogCustomEvent(player, name, info.value, TABLE_TO_CUSTOM_FIELDS(info.fields))
		end
	else
		logger[name] = function(player: Player, value: number?)
			AnalyticsService:LogCustomEvent(player, name, value)
		end
	end

	return logger :: any
end :: any

-- having parens around all of these local function calls so they inline
-- fuck you multiret
function logger.onboarding_funnel_step(logger, player, info)
	return ( onboarding_funnel_step(player, info) )
end

function logger.progression(logger, player, info)
	return ( progression(player, info) )
end

function logger.funnel_step(logger, player, info)
	return ( funnel_step(player, info) )
end

function logger.economy(logger, player, info)
	return ( economy(player, info) )
end

local loganalytics_mt = {}

function loganalytics_mt.__call(): Logger
	return setmetatable({}, logger)
end

table.freeze(loganalytics_mt)
table.freeze(logger)

return table.freeze(setmetatable({
	onboarding_funnel_step = onboarding_funnel_step,
	funnel_step = funnel_step,
	progression = progression,
	economy = economy,
	custom = custom,
}, loganalytics_mt))
