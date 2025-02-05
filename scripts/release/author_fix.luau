--!native

-- author fix
-- changes author names to the authors new username

local function author_fix(author: string): string
    if author == "Kalrnlo" then
        return "gaymeowing"
    else
        return author
    end
end

return author_fix
