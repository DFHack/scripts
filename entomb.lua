-- Entomb corpse items of any dead unit.
--@module = true
local utils = require('utils')

-- Get unit from selected corpse or corpse piece item.
function GetUnitFromCorpse(item)
    if math.type(item) == "integer" then item = df.item.find(item)
    elseif not item then item = dfhack.gui.getSelectedItem(true) end
    if item then
        if df.item_corpsest:is_instance(item) or df.item_corpsepiecest:is_instance(item) then
            return df.unit.find(item.unit_id)
        else
            qerror('Item is not a corpse or body part.')
        end
    end
end

-- Validate tomb zone assignment.
local function CheckTombZone(building, unit_id)
    if df.building_civzonest:is_instance(building) and building.type == df.civzone_type.Tomb then
        if building.assigned_unit_id == unit_id then
            return true
        end
    end
    return false
end

-- Iterate through all available tomb zones.
local function IterateTombZones(unit_id)
    for _, building in ipairs(df.global.world.buildings.other.ZONE_TOMB) do
        if CheckTombZone(building, unit_id) then return building end
    end
    return nil
end

-- Check if any of the unit's corpse items are not yet placed in a coffin.
function isEntombed(unit)
    -- Return FALSE for still living or undead units with empty corpse_parts vector.
    if #unit.corpse_parts == 0 then return false end
    for _, item_id in ipairs(unit.corpse_parts) do
        local item = df.item.find(item_id)
        if item then
            local inBuilding = dfhack.items.getGeneralRef(item, df.general_ref_type.BUILDING_HOLDER)
            local building_id = inBuilding and inBuilding.building_id or -1
            local building = df.building.find(building_id)
            local isCoffin = (building and df.building_coffinst:is_instance(building)) or false
            -- Return FALSE if even one item is not interred.
            if not isCoffin then
                return false
            end
        end
    end
    return true
end

local function GetTombZone(unit)
    local unit_id = unit.id
    local tomb
    local entombed = false
    -- Check if unit is already assigned to a tomb zone.
    local isAlreadyAssigned = IterateTombZones(unit_id)
    if isAlreadyAssigned then
        tomb = isAlreadyAssigned
        entombed = isEntombed(unit)
    else
        -- Find an unassigned tomb zone.
        tomb = IterateTombZones(-1)
    end
    return tomb, entombed
end

-- Set corpse items to be valid for burial.
local function FlagForBurial(unit, corpseParts)
    -- Undead units have empty corpse_parts vector.
    if unit.enemy.undead then
        for _, item in ipairs(df.global.world.items.other.ANY_CORPSE) do
            if df.item_corpsest:is_instance(item) or df.item_corpsepiecest:is_instance(item) then
                if item.unit_id == unit.id then
                    corpseParts:insert('#', item.id)
                end
            end
        end
    end
    local burialItemCount = 0
    for _, item_id in ipairs(corpseParts) do
        local item = df.item.find(item_id)
        if item then
            item.flags.dead_dwarf = true
            -- Some corpse items may be lost/destroyed before burial.
            burialItemCount = burialItemCount + 1
        end
    end
    return burialItemCount
end

function AssignToTomb(unit, tomb)
    local corpseParts = unit.corpse_parts
    local strBurial = '%s assigned to %s for burial.'
    local strTomb = 'Tomb %d'
    -- Provide the tomb's ID so users can invoke it when interring arbitrary items.
    strTomb = string.format(strTomb, tomb.id)
    if #tomb.name > 0 then
        strTomb = tomb.name
    else
        -- Assign name to unnamed tombs for easier search/reference.
        tomb.name = strTomb
    end
    local strCorpseItems = '(%d corpse, body part%s, or burial item%s)'
    local strPlural = ''
    local strNoCorpse = '%s has no corpse or body parts available for burial.'
    local strUnitName = unit and dfhack.units.getReadableName(unit)
    local incident_id = unit.counters.death_id
    if incident_id ~= -1 then
        local incident = df.incident.find(incident_id)
        -- Corpse will not be interred if not yet discovered,
        -- which never happens for units not belonging to player's civ.
        incident.flags.discovered = true
    end
    local burialItemCount = FlagForBurial(unit, corpseParts)
    if burialItemCount > 1 then strPlural = 's' end
    if burialItemCount == 0 then
        print(string.format(strNoCorpse, strUnitName))
    else
        tomb.assigned_unit_id = unit.id
        if not utils.linear_index(unit.owned_buildings, tomb) then
            unit.owned_buildings:insert('#', tomb)
        end
        print(string.format(strBurial, strUnitName, strTomb))
        print(string.format(strCorpseItems, burialItemCount, strPlural, strPlural))
    end
end

function GetCoffin(tomb)
    local coffin
    if df.building_civzonest:is_instance(tomb) and tomb.type == df.civzone_type.Tomb then
        for _, building in ipairs(tomb.contained_buildings) do
            if df.building_coffinst:is_instance(building) then coffin = building end
        end
    -- Allow other scripts to call this function and pass the actual coffin building instead.
    elseif df.building_coffinst:is_instance(tomb) then
        coffin = tomb
    end
    return coffin
end

-- Adapted from scripts/internal/caravan/pedestal.lua::is_displayable_item()
-- Allow checks for possible use case of interring of non-corpse items.
local function isMoveableItem(tomb, coffin, item, options)
    if not item or
        item.flags.hostile or
        item.flags.removed or
        item.flags.spider_web or
        item.flags.construction or
        item.flags.encased or
        item.flags.trader or
        item.flags.owned or
        item.flags.on_fire
    then
        return false
    end
    if item.flags.in_job then
        local inJob = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
        local job = inJob and inJob.data.job or nil
        if job
            and job.job_type == df.job_type.PlaceItemInTomb
            and dfhack.job.getGeneralRef(job, df.general_ref_type.BUILDING_HOLDER) ~= nil
            and dfhack.job.getGeneralRef(job, df.general_ref_type.BUILDING_HOLDER).building_id == tomb.id
            -- Allow task to be cancelled if teleporting.
            and not options.teleport
        then
            return false
        end
    elseif item.flags.in_inventory then
        local inContainer = dfhack.items.getGeneralRef(item, df.general_ref_type.CONTAINED_IN_ITEM)
        if not inContainer then return false end
    end
    if not dfhack.maps.isTileVisible(xyz2pos(dfhack.items.getPosition(item))) then
        return false
    end
    if item.flags.in_building then
        local building = dfhack.items.getHolderBuilding(item)
        -- Item is already interred.
        if building and building == coffin then return false end
        for _, containedItem in ipairs(building.contained_items) do
            -- Item is part of a building.
            if item == contained_item.item then return false end
        end
    end
    return true
end

-- Remove job from item to allow for hauling or teleportation.
local function RemoveJob(item)
    local inJob = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
    local job = inJob and inJob.data.job
    if job then dfhack.job.removeJob(job) end
end

function TeleportToCoffin(tomb, coffin, item)
    if not tomb or not coffin then return end
    local itemName = item and dfhack.items.getReadableDescription(item) or nil
    if item.flags.in_job then RemoveJob(item) end
    if (dfhack.items.moveToBuilding(item, coffin, df.building_item_role_type.TEMP)) then
        -- Flag the item to become an interred item, otherwise it will be hauled back to stockpiles.
        item.flags.in_building = true
        local strMove = 'Teleporting %d %s into a coffin.'
        print(string.format(strMove, item.id, itemName))
    end
end

function HaulToCoffin(tomb, coffin, item)
    if not tomb or not coffin then return end
    local itemName = item and dfhack.items.getReadableDescription(item) or nil
    if item.flags.in_job then RemoveJob(item) end
    local pos = utils.getBuildingCenter(coffin)
    local job = df.job:new()
    job.job_type = df.job_type.PlaceItemInTomb
    job.pos = pos
    dfhack.job.attachJobItem(job, item, df.job_role_type.Hauled, -1, -1)
    dfhack.job.addGeneralRef(job, df.general_ref_type.BUILDING_HOLDER, tomb.id)
    tomb.jobs:insert('#', job)
    dfhack.job.linkIntoWorld(job, true)
    local strMove = 'Tasking %d %s for immediate burial.'
    print(string.format(strMove, item.id, itemName))
end

local function InterItems(tomb, unit, options)
    local corpseParts = unit.corpse_parts
    local coffin = GetCoffin(tomb)
    if coffin then
        for _, item_id in ipairs(corpseParts) do
            local item = df.item.find(item_id)
            if isMoveableItem(tomb, coffin, item, options) then
                if options.teleport then
                    TeleportToCoffin(tomb, coffin, item)
                elseif options.haulNow then
                    HaulToCoffin(tomb, coffin, item)
                end
            end
        end
    else
        print('No coffin in the assigned tomb zone.\nCorpse items will not be moved into the tomb zone.')
    end
end

local function ParseArgs(args)
    local unit, tomb
    local options = {
        haulNow = false,
        teleport = false
    }
    if args and #args > 0 then
        for i, v in ipairs(args) do
            if v == 'help' then print(dfhack.script_help()) return end
            if v == 'unit' then
                local unit_id = tonumber(args[i+1]) or nil
                unit = unit_id and df.unit.find(unit_id)
                if not unit then qerror('Invalid unit ID.') end
            end
            if v == 'tomb' then
                local building_id = tonumber(args[i+1]) or nil
                local building = building_id and df.building.find(building_id)
                if not building then qerror('Invalid zone ID.') end
                -- Check if tomb zone is unassigned.
                if CheckTombZone(building, -1) then
                    tomb = building
                else
                    qerror('Specified zone ID does not point to an unassigned tomb zone.')
                end
            end
            if v == 'now' then options.haulNow = true end
            if v == 'teleport'  then options.teleport = true end
            if options.haulNow and options.teleport then
                qerror('Burial items cannot be teleported and tasked for hauling simultaneously.')
            end
        end
    end
    return unit, tomb, options
end

local function Main(args)
    if not dfhack.isSiteLoaded() and not dfhack.world.isFortressMode() then
        qerror('This script requires the game to be in fortress mode.')
    end
    local unit, tomb, options = ParseArgs(args)
    if not unit then unit = GetUnitFromCorpse() end
    if unit then
        local entombed
        if not tomb then tomb, entombed = GetTombZone(unit) end
        if entombed then
            print('Unit is already completely interred in a tomb zone.')
        elseif tomb then
            -- Prevent multiple tomb zone assignments when tomb ID is specified in the command line.
            -- Iterating through building.assigned_unit_id is probably safer than checking in
            -- unit.owned_buildings, as a reference in one does not guarantee a reference in the other.
            building = IterateTombZones(unit.id)
            if building and tomb ~= building then
                qerror('Unit already has an assigned tomb zone.')
            end
            AssignToTomb(unit, tomb)
        else
            print('No unassigned tomb zones are available.')
        end
        if options.haulNow or options.teleport then
            InterItems(tomb, unit, options)
        end
    else
        qerror('No item selected or unit specified.')
    end
end

if not dfhack_flags.module then
    Main({...})
end
