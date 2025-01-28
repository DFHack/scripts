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

fort = nil
civ = nil
capital = nil

-- adapted from Units::get_land_title(np)
function findSiteOfRule(np)
    site = nil
    civ = np.entity -- lawmakers seem to be all civ-level positions
    assignments = civ.positions.assignments
    for _, link in ipairs(civ.site_links) do
        if not link.flags.land_for_holding then goto continue end
        if link.position_profile_id ~= np.assignment.id then goto continue end

        site = df.world_site.find(link.target)
        break
        ::continue::
    end

    return site
end

---comment
---@return df.world_site|nil
function findCapital(civ)
    local capital = nil
    for _, link in ipairs(civ.site_links) do
        siteId = link.target
        if link.flags.capital then
            capital = df.world_site.find(siteId)
            break
        end
    end

    return capital
end

function addIfRulesOtherSite(unit, freeloaders)
    local nps = dfhack.units.getNoblePositions(unit) or {}
    local noblePos = nil
    for _, np in ipairs(nps) do
        if np.position.flags.IS_LAW_MAKER then
            noblePos = np
            break
        end
    end

    if noblePos == nil then return end -- unit is not nobility

    -- Monarchs do not seem to have an world_site associated to them (?)
    if noblePos.position.code == "MONARCH" then
        if capital.id ~= fort.id then
            freeloaders[unit.id] = capital
        end
        return
    end

    name = dfhack.units.getReadableName(unit)
    -- Logic for non-monarch nobility (dukes, counts, barons)
    site = findSiteOfRule(noblePos)
    if site == nil then qerror("could not find land of "..name) end

    if site.id == fort.id then return end -- noble rules current fort
    freeloaders[unit.id] = site
end

function main()
    freeloaders = {}
    for _, unit in ipairs(dfhack.units.getCitizens()) do
        if dfhack.units.isDead(unit) or not dfhack.units.isSane(unit) then goto continue end
        addIfRulesOtherSite(unit, freeloaders)
        ::continue::
    end

    for unitId, site in pairs(freeloaders) do
        unit = df.unit.find(unitId)
        unitName = dfhack.df2console(dfhack.units.getReadableName(unit))
        siteName = dfhack.df2console(dfhack.translation.translateName(site.name, true))
        print(unitName.." is lord of "..siteName)
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

    fort = dfhack.world.getCurrentSite()
    if fort == nil then qerror("could not find current site") end

    civ = df.historical_entity.find(df.global.plotinfo.civ_id)
    if civ == nil then qerror("could not find current civ") end

    capital = findCapital(civ)
    if capital == nil then qerror("could not find capital") end

    return true
end

argparse.processArgsGetopt({...}, {
    {"h", "help", handler=function() options.help = true end},
    {"a", "all", handler=function() options.deport = true end},
})

pass = initChecks()
if not pass then return end

main()
