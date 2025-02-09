--@module = true

--[[
TODO:
  * Feature: have rightful ruler immigrate to fort if off-site
  * QoL: make sure items are unassigned
]]--

local argparse = require("argparse")

local unit_link_utils = reqscript("internal/emigration/unit-link-utils")

local options = {
    all = false,
    unitId = -1,
    list = false
}

-- adapted from Units::get_land_title()
---@return df.world_site|nil
local function findSiteOfRule(np)
    local site = nil
    local civ = np.entity -- lawmakers seem to be all civ-level positions
    for _, link in ipairs(civ.site_links) do
        if not link.flags.land_for_holding then goto continue end
        if link.position_profile_id ~= np.assignment.id then goto continue end

        site = df.world_site.find(link.target)
        break
        ::continue::
    end

    return site
end

---@return df.world_site|nil
local function findCapital(civ)
    local civCapital = nil
    for _, link in ipairs(civ.site_links) do
        if link.flags.capital then
            civCapital = df.world_site.find(link.target)
            break
        end
    end

    return civCapital
end

---@param unit df.unit
---@param nobleList { unit: df.unit, site: df.world_site }[]
---@param thisSite df.world_site
---@param civ df.historical_entity
local function addNobleOfOtherSite(unit, nobleList, thisSite, civ)
    local nps = dfhack.units.getNoblePositions(unit) or {}
    local noblePos = nil
    for _, np in ipairs(nps) do
        -- TODO: also check if civ is not your fort? Some site govs have IS_LAW_MAKER positions
        if np.position.flags.IS_LAW_MAKER then
            noblePos = np
            break
        end
    end

    if not noblePos then return end -- unit is not nobility

    -- TODO: support other races that may not use MONARCH as position code
    --   entity.type == df.historical_entity_type.Civilization
    --   position.flags.RULES_FROM_LOCATION

    -- Monarchs do not seem to have an world_site associated to them (?)
    if noblePos.position.code == "MONARCH" then
        local capital = findCapital(civ)
        if capital and capital.id ~= thisSite.id then
            table.insert(nobleList, {unit = unit, site = capital})
        end
        return
    end

    local name = dfhack.units.getReadableName(unit)
    -- Logic for dukes, counts, barons
    local site = findSiteOfRule(noblePos)
    if not site then qerror("could not find land of "..name) end

    if site.id == thisSite.id then return end -- noble rules current fort
    table.insert(nobleList, {unit = unit, site = site})
end

---@param unit df.unit
local function removeMandates(unit)
    local mandates = df.global.world.mandates
    for i=#mandates-1,0,-1 do
        local mandate = mandates[i]
        if mandate.unit and mandate.unit.id == unit.id then
            mandates:erase(i)
            mandate:delete()
        end
    end
end

-- adapted from emigration::desert()
---@param unit df.unit
---@param toSite df.world_site
---@param prevEnt df.historical_entity
---@param civ df.historical_entity
local function emigrate(unit, toSite, prevEnt, civ)
    local histFig = df.historical_figure.find(unit.hist_figure_id)
    if not histFig then
        print("Could not find associated historical figure!")
        return
    end

    unit_link_utils.markUnitForEmigration(unit, civ.id, true)

    -- remove current job
    if unit.job.current_job then dfhack.job.removeJob(unit.job.current_job) end

    -- break up any social activities
    for _, actId in ipairs(unit.social_activities) do
        local act = df.activity_entry.find(actId)
        if act then act.events[0].flags.dismissed = true end
    end

    -- cancel any associated mandates
    removeMandates(unit)

    unit_link_utils.removeUnitAssociations(unit)
    unit_link_utils.removeHistFigFromEntity(histFig, prevEnt)

    -- have unit join new site government
    local siteGov = df.historical_entity.find(toSite.cur_owner_id)
    if not siteGov then qerror("could not find entity associated with new site") end
    unit_link_utils.addHistFigToSite(histFig, toSite.id, siteGov)

    -- announce the changes
    local unitName = dfhack.df2console(dfhack.units.getReadableName(unit))
    local siteName = dfhack.df2console(dfhack.translation.translateName(toSite.name, true))
    local govName = dfhack.df2console(dfhack.translation.translateName(siteGov.name, true))
    local line = unitName .. " has left to join " ..govName.. " as lord of " .. siteName .. "."
    print("[+] "..dfhack.df2console(line))
    dfhack.gui.showAnnouncement(line, COLOR_WHITE)
end

---@param unit df.unit
local function inSpecialJob(unit)
    local job = unit.job.current_job
    if not job then return false end

    if job.flags.special then return true end -- cannot cancel

    local jobType = job.job_type -- taken from notifications::for_moody()
    return df.job_type_class[df.job_type.attrs[jobType].type] == 'StrangeMood'
end

---@param unit df.unit
local function isSoldier(unit)
    return unit.military.squad_id ~= -1
end

---@param unit df.unit
---@param fortEnt df.historical_entity
---@param includeElected boolean
local function isAdministrator(unit, fortEnt, includeElected)
    ---@diagnostic disable-next-line: missing-parameter
    local nps = dfhack.units.getNoblePositions(unit) or {}

    ---@diagnostic disable-next-line: param-type-mismatch
    for _, np in ipairs(nps) do
        -- Elected officials can be chosen again
        local isAdmin = np.entity.id == fortEnt.id
        if not includeElected then isAdmin = isAdmin and not np.position.flags.ELECTED end
        if isAdmin then return true end
    end
    return false
end

---@param nobleList { unit: df.unit, site: df.world_site }[]
---@param fort df.world_site
---@param fortEnt df.historical_entity
local function listNoblesFound(nobleList, fort, fortEnt)
    for _, record in ipairs(nobleList) do
        local unit = record.unit
        local site = record.site

        local nobleName = dfhack.df2console(dfhack.units.getReadableName(unit))
        local unitMsg = unit.id..": "..nobleName
        if isSoldier(unit) then
            local squad = df.squad.find(unit.military.squad_id)
            local squadName = squad
                and dfhack.df2console(dfhack.translation.translateName(squad.name, true))
                or "unknown squad"

            unitMsg = "! "..unitMsg.." - soldier in "..squadName
        elseif isAdministrator(unit, fortEnt, true) then
            local fortName = dfhack.df2console(dfhack.translation.translateName(fort.name, true))
            unitMsg = "! "..unitMsg.." - administrator of "..fortName
        else
            local siteName = dfhack.df2console(dfhack.translation.translateName(site.name, true))
            unitMsg = "  "..unitMsg.." - to "..siteName
        end

        print(unitMsg)
    end
end

local function printNoNobles()
    if options.unitId == -1 then
        print("No eligible nobles to be emigrated.")
    else
        print("Unit ID "..options.unitId.." is not an eligible noble.")
    end
end

local function main()
    ---@diagnostic disable-next-line: assign-type-mismatch
    local fort = dfhack.world.getCurrentSite() ---@type df.world_site
    if not fort then qerror("could not find current site") end

    local fortEnt = df.global.plotinfo.main.fortress_entity

    local civ = df.historical_entity.find(df.global.plotinfo.civ_id)
    if not civ then qerror("could not find current civ") end

    ---@type { unit: df.unit, site: df.world_site }[]
    local freeloaders = {}
    for _, unit in ipairs(dfhack.units.getCitizens()) do
        if options.unitId ~= -1 and unit.id ~= options.unitId then goto continue end

        addNobleOfOtherSite(unit, freeloaders, fort, civ)
        ::continue::
    end

    if #freeloaders == 0 then
        printNoNobles()
        return
    end

    if options.list then
        listNoblesFound(freeloaders, fort, fortEnt)
        return
    end

    for _, record in ipairs(freeloaders) do
        local noble = record.unit
        local site = record.site

        local nobleName = dfhack.units.getReadableName(noble)
        if inSpecialJob(noble) then
            print("! "..nobleName.." is busy! Leave alone for now.")
        elseif isSoldier(noble) then
            print("! "..nobleName.." is in a squad! Unassign the unit and try again.")
        elseif isAdministrator(noble, fortEnt, false) then
            print("! "..nobleName.." is an administrator! Unassign the unit and try again.")
        else
            emigrate(noble, site, fortEnt, civ)
        end
    end
end

local function initChecks()
    if not dfhack.world.isFortressMode() or not dfhack.isMapLoaded() then
        qerror('needs a loaded fortress map')
    end

    if options.list then return true end -- list option does not require unit options

    local noOptions = options.unitId == -1 and not options.all
    if noOptions then
        unit = dfhack.gui.getSelectedUnit(true)
        if unit then
            options.unitId = unit.id
            local name = dfhack.units.getReadableName(unit)
            print("Selecting "..name.." (ID "..unit.id..")")
        else
            options.list = true
            print("Defaulting to list mode:")
        end

        return true
    end

    local invalidUnit = options.unitId ~= -1 and options.all
    if invalidUnit then qerror("Either specify one unit or all.") end

    return true
end

local function resetOptions()
    options.all = false
    options.unitId = -1
    options.list = false
end

------------------------------
-- [[ SCRIPT STARTS HERE ]] --
------------------------------

function run(args)
    argparse.processArgsGetopt(args, {
        {"a", "all", handler=function() options.all = true end},
        {"u", "unit", hasArg=true, handler=function(id) options.unitId = tonumber(id) end},
        {"l", "list", handler=function() options.list = true end}
    })

    if initChecks() then
        main()
    end

    resetOptions()
end
