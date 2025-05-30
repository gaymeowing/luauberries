
--[[
	dep graph
	module for generating a dependency graph for all libraries
]]

local require_pattern = require("@scripts/require_pattern")
local iter_scripts = require("@scripts/iter_scripts")
local read_dir = require("@scripts/read_dir")
local remove = require("@scripts/remove")
local process = require("@lune/process")

export type DependencyInfo = {	
	shallow: { string },
	has_deps: boolean,
	deep: { string },
}

local GRAPH = {} :: { [string]: DependencyInfo }
local FOUND = {} :: { [string]: boolean }
local DEPQUEUE = {} :: { string }

for _, lib in read_dir("libs") do
	GRAPH[lib] = {
		has_deps = false,
		shallow = {},
		deep = {},
	}
end

for lib, depinfo in GRAPH do
	local shallow = depinfo.shallow

	iter_scripts(`libs/{lib}`, function(_, src)
		for dep_lib in string.gmatch(src, require_pattern.libs_alias) do
			if not table.find(shallow, dep_lib) then
				table.insert(shallow, dep_lib)
			end
		end
	end)
end

for lib, depinfo in GRAPH do
	local shallow = depinfo.shallow
	local deep = depinfo.deep

	if #shallow ~= 0 then
		local queue_len = #shallow
    	table.move(shallow, 1, queue_len, 1, DEPQUEUE)

   		while queue_len ~= 0 do
        	local current = remove(DEPQUEUE, queue_len)
			queue_len -= 1
        
        	if not FOUND[current] then
				table.insert(deep, current)
           	 	FOUND[current] = true
            
            	-- Add the shallow dependencies of the current item to the queue
           		for _, dep in GRAPH[current].shallow do
					queue_len += 1
					DEPQUEUE[queue_len] = dep
            	end
        	end
    	end
		
		depinfo.has_deps = true
		table.clear(DEPQUEUE)
		table.clear(FOUND)
	end

	if #deep == #shallow then
		depinfo.deep = table.freeze(shallow)
	else
		table.freeze(shallow)
		table.freeze(deep)
	end

	table.freeze(depinfo)
end

if process.args[1] == "print" then
	local pretty_graph = {} :: { [string]: { shallow: { string }, deep: { string } } | { string } }

	for lib, depinfo in GRAPH do
		local shallow = depinfo.shallow
		local deep = depinfo.deep

		if depinfo.has_deps then
			if shallow ~= deep then
				pretty_graph[lib] = {
					shallow = shallow,
					deep = deep,
				}
			else
				pretty_graph[lib] = shallow
			end
		end
	end
	print(pretty_graph)
end

return table.freeze(GRAPH)
