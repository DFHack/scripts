-- Iterate over all tools, clear the in_job flag for minecarts, and report how many flags were actually flipped from true to false

local tools = df.global.world.items.other.TOOL
local flipped = 0
for i = 0, #tools - 1 do
    local tool = tools[i]
    -- Only consider minecart tools
    if tool.subtype.id == "ITEM_TOOL_MINECART" then
        -- Only flip if it was true
        if tool.flags.in_job then
            tool.flags.in_job = false
            flipped = flipped + 1
        end
    end
end

-- Print count of flags flipped from true to false
dfhack.printerr(string.format(
    "clear_minecart_jobs: flipped in_job flag on %d minecart tool(s) from true to false\n", flipped
))
