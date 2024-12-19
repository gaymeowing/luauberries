
-- libinfo
-- utility func for reading LIBRARY.toml files
-- and providing types for LIBINFOs

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

type InternalLibInfo = BaseLibInfo<RuntimeInfo | string | nil>

type LibInfo = BaseLibInfo<RuntimeInfo?>

local LIBINFO_PATH_FORMAT = "libs/%*/LIBRARY.toml"
local CACHED_INFOS = {} :: { [string]: LibInfo }
local FORMAT = string.format
local FREEZE = table.freeze

local function libinfo(lib: string): LibInfo
 local cached = CACHED_INFOS[lib]
 
 if cached then
  return cached
 else
  local raw: InternalLibInfo = serde.decode("toml", fs.readFile(FORMAT(LIBINFO_PATH_FORMAT, lib)))
  local runtime = raw.runtime

  if runtime then
   if type(runtime) == "string" then
    runtime = { main = runtime }
   else
    local optional = runtime.optional

    if optional then
     FREEZE(optional)
    end
   end
   raw.runtime = FREEZE(runtime) 
  end

  CACHED_INFOS[lib] = FREEZE(raw) :: any
  return raw :: any
end

return libinfo