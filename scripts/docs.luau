
--[[
	docs
	generates sidebar, and homepage
]]

local iter_dir = require("@scripts/iter_dir")
local read_dir = require("@scripts/read_dir")
local gsub = require("@scripts/gsub")
local serde = require("@lune/serde")
local fs = require("@lune/fs")

type SidebarItem = { text: string, link: string }

type LibdocInfo = {
	items: { LibdocInfo }?,
	link: string,
	text: string,
}

local IGNORE = table.freeze({ ".vitepress", "public", "index.md", "installing.md" })
local FEATURE_FORMAT = "  - title: %*\n    details: %*\n    link: %*\n"
local HOME_SRC = fs.readFile("docs/index.md")
local DOCDESCS = {} :: { [string]: string }
local FANCY_URL_PATTERN = "%[(.-)%]%(.-%)"
local LIBDOCS = {} :: { LibdocInfo }
local DESC_PATTERN = "\n\n(.-)\n\n"
local UPPER = string.upper
local MATCH = string.match
local FIND = string.find
local SUB = string.sub

local function NAME_FROM_FILE_NAME(file_name: string): string
	local rest_of_name = SUB(
		file_name, 2, (FIND(file_name, ".", 1, true) :: any) - 1
	)

	return gsub(
		UPPER(SUB(file_name, 1, 1)) .. rest_of_name, 
		"%-%a", function(dash_and_char)
			return " " .. UPPER(SUB(dash_and_char, 2, 2))
		end
	)
end

local function GET_SHORTENED_DESC(file: string): string
	local desc = MATCH(gsub(file, "\r", ""), DESC_PATTERN)

	if desc then
		return gsub(desc, FANCY_URL_PATTERN, function(url_name)
			return gsub(url_name, "`", "")
		end)
	else
		return "n/a"
	end
end

for _, lib_doc in read_dir("docs") do
	if table.find(IGNORE, lib_doc) then
		continue
	end
	local name = NAME_FROM_FILE_NAME(lib_doc)
	local path = `docs/{lib_doc}`

	if fs.isFile(path) then
		DOCDESCS[name] = GET_SHORTENED_DESC(fs.readFile(path))
		table.insert(LIBDOCS, table.freeze({
			link = `/{lib_doc}`,
			text = name,
		}))
	else
		local index_path = `{path}/index.md`

		if fs.isFile(index_path) then
			local relative_index_path = `/{lib_doc}/index.md`
			DOCDESCS[name] = GET_SHORTENED_DESC(fs.readFile(index_path))
			local items = {} :: { LibdocInfo }
			local libdoc_info = {
				link = relative_index_path,
				items = items,
				text = name,
			}

			iter_dir(path, function(name, file_path)				
				if file_path ~= index_path then
					table.insert(items, {
						text = NAME_FROM_FILE_NAME(name),
						link = MATCH(file_path, "docs(.+)") or "",
					})
				end
			end :: any)

			table.insert(LIBDOCS, libdoc_info)
		else
			error("cannot have docs dir without an index.md file")
		end
	end
end

table.sort(LIBDOCS, function(a, b)
	return a.text > b.text
end)

local before_features = MATCH(HOME_SRC, "((.+)features:)")
local features = table.create(#LIBDOCS)

for index, libdoc in LIBDOCS do
	local name = libdoc.text
	features[index] = string.format(
		FEATURE_FORMAT, name, DOCDESCS[name], libdoc.link
	)
end

fs.writeFile("docs/.vitepress/sidebar-libs.json", serde.encode("json", LIBDOCS))
fs.writeFile("docs/index.md", `{before_features}\n{table.concat(features)}---`)
