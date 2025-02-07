--Deport resident nobles of other lands and summon your rightful lord if he/she is elsewhere

--[[
TODO:
  * Feature: have rightful ruler immigrate to fort if off-site
  * QoL: make sure items are unassigned
]]--

local argparse = require("argparse")

local options = {
    help = false,
    all = false,
    unitId = -1,
    list = false
}

fort = nil      ---@type df.world_site
civ = nil       ---@type df.historical_entity
capital = nil   ---@type df.world_site

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
    local capital = nil
    for _, link in ipairs(civ.site_links) do
        if link.flags.capital then
            capital = df.world_site.find(link.target)
            break
        end
    end

    return capital
end

function addNobleOfOtherSite(unit, nobleList)
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
        if capital.id ~= fort.id then
            table.insert(nobleList, {unit = unit, site = capital})
        end
        return
    end

    local name = dfhack.units.getReadableName(unit)
    -- Logic for dukes, counts, barons
    local site = findSiteOfRule(noblePos)
    if not site then qerror("could not find land of "..name) end

    if site.id == fort.id then return end -- noble rules current fort
    table.insert(nobleList, {unit = unit, site = site})
end

---@param histFig df.historical_figure
---@param newSite df.world_site
local function addHistFigToSite(histFig, newSite)
    -- have unit join site government
    local siteGovId = newSite.cur_owner_id
    print("new site gov = "..siteGovId)
    histFig.entity_links:insert("#", {new = df.histfig_entity_link_memberst, entity_id = siteGovId, link_strength = 100})
    local histFigId = histFig.id

    -- have unit join new site
    local siteId = newSite.id
    local siteGov = df.historical_entity.find(siteGovId)
    if not siteGov then qerror("could not find site!") end

    siteGov.histfig_ids:insert('#', histFigId)
    siteGov.hist_figures:insert('#', histFig)
    local hfEventId = df.global.hist_event_next_id
    df.global.hist_event_next_id = df.global.hist_event_next_id+1
    df.global.world.history.events:insert("#", {new = df.history_event_add_hf_entity_linkst, year = df.global.cur_year, seconds = df.global.cur_year_tick, id = hfEventId, civ = siteGovId, histfig = histFigId, link_type = 0})

    local hfEventId = df.global.hist_event_next_id
    df.global.hist_event_next_id = df.global.hist_event_next_id+1
    df.global.world.history.events:insert("#", {new = df.history_event_change_hf_statest, year = df.global.cur_year, seconds = df.global.cur_year_tick, id = hfEventId, hfid = histFigId, state = 1, reason = -1, site = siteId})

    return siteGov
end

---@param unit df.unit
---@param histFig df.historical_figure
---@param oldSite df.historical_entity
local function removeUnitFromSiteEntity(unit, histFig, oldSite)
    local histFigId = histFig.id

    -- free owned rooms
    for i = #unit.owned_buildings-1, 0, -1 do
        local tmp = df.building.find(unit.owned_buildings[i].id)
        dfhack.buildings.setOwner(tmp, nil)
    end

    -- remove from workshop profiles
    for _, bld in ipairs(df.global.world.buildings.other.WORKSHOP_ANY) do
        for k, v in ipairs(bld.profile.permitted_workers) do
            if v == unit.id then
                bld.profile.permitted_workers:erase(k)
                break
            end
        end
    end
    for _, bld in ipairs(df.global.world.buildings.other.FURNACE_ANY) do
        for k, v in ipairs(bld.profile.permitted_workers) do
            if v == unit.id then
                bld.profile.permitted_workers:erase(k)
                break
            end
        end
    end

    -- disassociate from work details
    for _, detail in ipairs(df.global.plotinfo.labor_info.work_details) do
        for k, v in ipairs(detail.assigned_units) do
            if v == unit.id then
                detail.assigned_units:erase(k)
                break
            end
        end
    end

    -- unburrow
    for _, burrow in ipairs(df.global.plotinfo.burrows.list) do
        dfhack.burrows.setAssignedUnit(burrow, unit, false)
    end

    -- erase the unit from the fortress entity
    for k,v in ipairs(oldSite.histfig_ids) do
        if v == histFigId then
            df.global.plotinfo.main.fortress_entity.histfig_ids:erase(k)
            break
        end
    end
    for k,v in ipairs(oldSite.hist_figures) do
        if v.id == histFigId then
            df.global.plotinfo.main.fortress_entity.hist_figures:erase(k)
            break
        end
    end
    for k,v in ipairs(oldSite.nemesis) do
        if v.figure.id == histFigId then
            df.global.plotinfo.main.fortress_entity.nemesis:erase(k)
            df.global.plotinfo.main.fortress_entity.nemesis_ids:erase(k)
            break
        end
    end

    -- remove the old entity link and create new one to indicate former membership
    histFig.entity_links:insert("#", {new = df.histfig_entity_link_former_memberst, entity_id = oldSite.id, link_strength = 100})
    for k,v in ipairs(histFig.entity_links) do
        if v._type == df.histfig_entity_link_memberst and v.entity_id == oldSite.id then
            histFig.entity_links:erase(k)
            break
        end
    end
end

-- adapted from emigration::desert()
---@param unit df.unit
---@param toSite df.world_site
function emigrate(unit, toSite)
    local histFig = df.historical_figure.find(unit.hist_figure_id)
    if histFig == nil then qerror("could not find histfig!") end

    local fortEnt = df.global.plotinfo.main.fortress_entity

    -- mark for leaving
    unit.following = nil
    unit.civ_id = civ.id -- should be redundant but oh well
    unit.flags1.forest = true
    unit.flags2.visitor = true
    unit.animal.leave_countdown = 2

    -- remove current job
    if unit.job.current_job then dfhack.job.removeJob(unit.job.current_job) end

    -- break up any social activities
    for _, actId in ipairs(unit.social_activities) do
        local act = df.activity_entry.find(actId)
        if act then act.events[0].flags.dismissed = true end
    end

    removeUnitFromSiteEntity(unit, histFig, fortEnt)
    local siteGov = addHistFigToSite(histFig, toSite)

    -- announce the changes
    local unitName = dfhack.df2console(dfhack.units.getReadableName(unit))
    local siteName = dfhack.df2console(dfhack.translation.translateName(toSite.name, true))
    local govName = dfhack.df2console(dfhack.translation.translateName(siteGov.name, true))
    local line = unitName .. " has left to join " ..govName.. " as lord of " .. siteName .. "."
    print("[+] "..dfhack.df2console(line))
    dfhack.gui.showAnnouncement(line, COLOR_WHITE)
end

---@param unit df.unit
local function inStrangeMood(unit)
    local job = unit.job.current_job
    if not job then return false end

    local jobType = job.job_type -- taken from notifications::for_moody()
    return df.job_type_class[df.job_type.attrs[jobType].type] == 'StrangeMood'
end

---@param unit df.unit
local function isSoldier(unit)
    return unit.military.squad_id ~= -1
end

function listNoblesFound(nobleList)
    for _, record in pairs(nobleList) do
        local unit = record.unit
        local site = record.site

        local nobleName = dfhack.df2console(dfhack.units.getReadableName(unit))
        local siteName = dfhack.df2console(dfhack.translation.translateName(site.name, true))
        local unitMsg = unit.id..": "..nobleName.." to be sent to "..siteName
        if isSoldier(unit) then
            local squad = df.squad.find(unit.military.squad_id)
            if not squad then qerror("could not find unit's squad") end
            local squadName = dfhack.df2console(dfhack.translation.translateName(squad.name, true))
            unitMsg = unitMsg.." [!] Unit is soldier in "..squadName
        end

        print(unitMsg)
    end
end

function main()
    local freeloaders = {}
    for _, unit in ipairs(dfhack.units.getCitizens()) do
        if options.unitId ~= -1 and unit.id ~= options.unitId then goto continue end
        if dfhack.units.isDead(unit) or not dfhack.units.isSane(unit) then goto continue end

        addNobleOfOtherSite(unit, freeloaders)
        ::continue::
    end

    if #freeloaders == 0 then
        if options.unitId ~= -1 then
            print("No eligible nobles to be emigrated.")
        else
            print("No eligible nobles found with ID = "..options.unitId)
        end
    end

    if options.list then
        listNoblesFound(freeloaders)
        return
    end

    for _, record in pairs(freeloaders) do
        local noble = record.unit
        local site = record.site

        local nobleName = dfhack.units.getReadableName(noble)
        if inStrangeMood(noble) then
            print("[-] "..nobleName.." is in a strange mood! Leave alone for now.")
        elseif isSoldier(noble) then
            print("[-] "..nobleName.." is in a squad! Unassign the unit before proceeding.")
        else
            emigrate(noble, site)
        end
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
    if not fort then qerror("could not find current site") end

    civ = df.historical_entity.find(df.global.plotinfo.civ_id)
    if not civ then qerror("could not find current civ") end

    capital = findCapital(civ)
    if not capital then qerror("could not find capital") end

    if options.list then return true end -- list option does not require unit options

    local noOptions = options.unitId == -1 and not options.all
    if noOptions then
        print("No options selected, defaulting to list mode.")
        options.list = true
        return true
    end

    local invalidUnit = options.unitId ~= -1 and options.all
    if invalidUnit then qerror("Either specify one unit or all.") end

    return true
end

------------------------------
-- [[ SCRIPT STARTS HERE ]] --
------------------------------

argparse.processArgsGetopt({...}, {
    {"h", "help", handler=function() options.help = true end},
    {"a", "all", handler=function() options.all = true end},
    {"u", "unit", hasArg=true, handler=function(id) options.unitId = tonumber(id) end},
    {"l", "list", handler=function() options.list = true end}
})

pass = initChecks()
if not pass then return end

main()
