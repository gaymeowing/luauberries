
--[[
	gsub
	a function that only gives the first result of string.gsub so the typechecker doesnt scream
]]

type GsubSubsitute =
	| { [string]: string }
	| ((string) -> string)
	| string

--[[
	Returns a copy of `s` in which all or the first `n` occurrences of the pattern are replaced with the given replacement.
]]
local function gsub(
	s: string, p: string, f: GsubSubsitute, maxs: number?
): string
	return (string.gsub(s, p, f, maxs))
end

return gsub
