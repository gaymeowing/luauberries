
--[[
	libinfo
	utility func for reading LIBRARY.toml files and providing types for LIBINFOs
]]

local serde = require("@lune/serde")
local fs = require("@lune/fs")

type RuntimeInfo = {
	optional: { string }?,
	main: string,
}?

type BaseLibInfo<R> = {
	tags: { string },
	version: string,
	runtime: R,
}

type InternalLibInfo = BaseLibInfo<RuntimeInfo | string>

type LibInfo = BaseLibInfo<RuntimeInfo?>

local CACHED_INFOS = {} :: { [string]: LibInfo }

local function libinfo(lib: string): LibInfo
	local cached = CACHED_INFOS[lib]
 
	if cached then
		return cached
	else
		local raw = serde.decode("toml", fs.readFile(`libs/{lib}/LIBRARY.toml`)) :: InternalLibInfo

		if raw.runtime then
			local runtime = raw.runtime

			if type(runtime) == "string" then
				raw.runtime = { main = runtime }
			else
				if runtime.optional then
					table.freeze(runtime.optional)
				end
			end

			table.freeze(raw.runtime) 
		else
			error(`no runtime specified for lib {lib}`)
		end

		CACHED_INFOS[lib] = table.freeze(raw) :: any
		return raw :: any
	end
end

return libinfo
