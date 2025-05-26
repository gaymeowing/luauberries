
--[[
	remove
	swap removal func for removing the first index,
	if the value doesnt exist it'll error
]]

local function remove<V>(t: { V }, i: number?): V
	if not i then
		i = 1
	end
	local v = t[i :: number]

	if v ~= nil then
		if #t ~= 1 then
			t[i :: number] = t[#t]
			t[#t] = nil
		else
			t[1] = nil
		end
		
		return v
	else
		error("table is empty", 2)
	end
end

return remove
