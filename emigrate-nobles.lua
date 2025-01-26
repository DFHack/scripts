--Deport resident nobles of other lands and summon your rightful lord if he/she is elsewhere

local argparse = require("argparse")

--[[
Planned modes/options:
  - d/deport = remove inherited freeloaders
    - list = list possible nobles to evict
    - index = specific noble to kick
    - all = kick all listed nobles
  - i/import = find and invite heir to fortress (need a better name)
]]--
local options = {
    help = false
}

function isNoble(unit)
    for _, pos in ipairs(dfhack.units.getNoblePositions(unit) or {}) do
        entity_pos = pos.position
        if entity_pos.flags.IS_LAW_MAKER then
            name = dfhack.df2console(dfhack.units.getReadableName(unit))
            print(name.." is a noble")
        end
    end
end

function main()
    for _, unit in ipairs(dfhack.units.getCitizens()) do
        if not options.deport or dfhack.units.isDead(unit) then goto continue end
        isNoble(unit)
        ::continue::
    end
end


argparse.processArgsGetopt({...}, {
    {"h", "help", handler=function() options.help = true end},
    {"a", "all", handler=function() options.deport = true end},
})

if options.help then
    print(dfhack.script_help())
    return
end

main()
