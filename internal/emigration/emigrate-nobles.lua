--@module = true

--Deport resident nobles of other lands

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

---@param unit          df.unit
---@param nobleList     { unit: df.unit, site: df.world_site }[]
---@param playerFort    df.world_site
---@param civ           df.historical_entity
local function addNobleOfOtherSite(unit, nobleList, playerFort, civ)
    local nps = dfhack.units.getNoblePositions(unit) or {}
    local noblePos = nil
    for _, np in ipairs(nps) do
        if np.position.flags.IS_LAW_MAKER then
            noblePos = np
            break
        end
    end

    if not noblePos then return end -- unit is not nobility

    -- Monarchs do not seem to have an world_site associated to them (?)
    if noblePos.position.code == "MONARCH" then
        local capital = findCapital(civ)
        if capital and capital.id ~= playerFort.id then
            table.insert(nobleList, {unit = unit, site = capital})
        end
        return
    end

    local name = dfhack.units.getReadableName(unit)
    -- Logic for dukes, counts, barons
    local site = findSiteOfRule(noblePos)
    if not site then qerror("could not find land of "..name) end

    if site.id == playerFort.id then return end -- noble rules current fort
    table.insert(nobleList, {unit = unit, site = site})
end

-- adapted from emigration::desert()
---@param unit      df.unit
---@param toSite    df.world_site
---@param civ       df.historical_entity
local function emigrate(unit, toSite, civ)
    local histFig = df.historical_figure.find(unit.hist_figure_id)
    if not histFig then
        print("Could not find associated historical figure!")
        return
    end

    local fortEnt = df.global.plotinfo.main.fortress_entity
    unit_link_utils.markUnitForEmigration(unit, civ.id, true)

    -- remove current job
    if unit.job.current_job then dfhack.job.removeJob(unit.job.current_job) end

    -- break up any social activities
    for _, actId in ipairs(unit.social_activities) do
        local act = df.activity_entry.find(actId)
        if act then act.events[0].flags.dismissed = true end
    end

    unit_link_utils.removeUnitAssociations(unit)
    unit_link_utils.removeHistFigFromEntity(histFig, fortEnt)

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

---@param nobleList { unit: df.unit, site: df.world_site }[]
local function listNoblesFound(nobleList)
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
    local fort = dfhack.world.getCurrentSite()
    if not fort then qerror("could not find current site") end

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
        listNoblesFound(freeloaders)
        return
    end

    for _, record in ipairs(freeloaders) do
        local noble = record.unit
        local site = record.site

        local nobleName = dfhack.units.getReadableName(noble)
        if inSpecialJob(noble) then
            print("[!] "..nobleName.." is busy! Leave alone for now.")
        elseif isSoldier(noble) then
            print("[!] "..nobleName.." is in a squad! Unassign the unit before proceeding.")
        else
            emigrate(noble, site, civ)
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
