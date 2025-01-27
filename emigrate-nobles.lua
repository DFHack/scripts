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

fortId=nil

function isNoble(unit)
    local nps = dfhack.units.getNoblePositions(unit) or {}
    local isLawMaker = false

    local noblePos, nobleName

    for _, np in ipairs(nps) do
        pos = np.position
        if pos.flags.IS_LAW_MAKER then
            isLawMaker = true
            noblePos = np
            nobleName = dfhack.df2console(dfhack.units.getReadableName(unit))
            break
        end
    end

    if not isLawMaker then return false end

    civ = noblePos.entity -- lawmakers seem to be all civ-level positions
    assignments = civ.positions.assignments
    for _, link in ipairs(civ.site_links) do
        siteId = link.target
        posProfId = link.position_profile_id
        if posProfId < 0 then goto continue end

        assignment = assignments[posProfId]
        if assignment.id ~= noblePos.assignment.id then goto continue end

        site = df.world_site.find(siteId)
        siteName = dfhack.translation.translateName(site.name, true, true)

        if siteId == fortId then
            print(nobleName.." holds a position in this fortress - "..siteName)
            goto continue
        end

        print(nobleName.." is lord of "..siteName)
        ::continue::
    end

    return isLawMaker
end

function main()
    fort = df.historical_entity.find(fortId)
    fortName = dfhack.translation.translateName(fort.name, true)
    print("Current fort is "..fortName)

    for _, unit in ipairs(dfhack.units.getCitizens()) do
        if dfhack.units.isDead(unit) then goto continue end
        isNoble(unit)
        ::continue::
    end
end

function initChecks()
    if options.help then
        print(dfhack.script_help())
        return false
    end

    if not dfhack.world.isFortressMode() or not dfhack.isMapLoaded() then
        qerror('needs a loaded fortress map')
        return false
    end

    fortId = dfhack.world.GetCurrentSiteId()
    if fortId == -1 then
        qerror('could not find current site')
        return false
    end

    return true
end

argparse.processArgsGetopt({...}, {
    {"h", "help", handler=function() options.help = true end},
    {"a", "all", handler=function() options.deport = true end},
})

pass = initChecks()
if not pass then return end

main()
