-- Entomb corpse items of any dead unit.
--@module = true

local argparse = require('argparse')
local utils = require('utils')
local guidm = require('gui.dwarfmode')

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

-- Get unit from selected corpse or body part item.
function GetUnitFromCorpse(item)
    if math.type(item) == "integer" then item = df.item.find(item)
    elseif not item then item = dfhack.gui.getSelectedItem(true) end
    if item then
        if df.item_corpsest:is_instance(item) or df.item_corpsepiecest:is_instance(item) then
            return df.unit.find(item.unit_id)
        else
            qerror('Selected item is not a corpse or body part.')
        end
    end
    return nil
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
        -- Use only active (unpaused) zones when assigning unassigned tomb zones.
        if unit_id == -1 and not building.spec_sub_flag.active then goto skipIteration end
        if CheckTombZone(building, unit_id) then return building end
        ::skipIteration::
    end
    return nil
end

-- Use when user inputs coffin building ID instead of tomb zone ID.
function GetTombFromCoffin(building)
    if #building.relations > 0 then
        for _, zone in ipairs(building.relations) do
            if df.building_civzonest:is_instance(zone) and zone.type == df.civzone_type.Tomb then
                return zone
            end
        end
    end
    return nil
end

function GetTombFromZone(building)
    if df.building_civzonest:is_instance(building) and building.type == df.civzone_type.Tomb then
        return building
    elseif df.building_coffinst:is_instance(building) then
        return GetTombFromCoffin(building)
    end
    return nil
end

function GetTombFromUnit(unit)
    -- Check if unit already has a tomb zone assigned.
    local alreadyAssignedTomb = unit and IterateTombZones(unit.id)
    if alreadyAssignedTomb then
        return alreadyAssignedTomb
    else
        -- Get an unassigned tomb zone.
        return IterateTombZones(-1)
    end
end

-- Set unit's corpse items to be valid for burial.
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
    -- Provide the tomb's ID so the user can invoke it when interring arbitrary items.
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
        -- Only needed for units that have a death incident.
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
        -- Make tomb zone unavailable for automatic assignment to other dead units.
        tomb.zone_settings.tomb.flags.no_pets = true
        tomb.zone_settings.tomb.flags.no_citizens = true
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
-- Allow checks for possible use case of interring arbitrary items.
local function isMoveableItem(tomb, coffin, item, options)
    if not item or
        -- Allow forbid/dump/melt designated items to be valid.
        item.flags.hostile or
        item.flags.removed or
        item.flags.spider_web or
        item.flags.construction or
        item.flags.encased or
        item.flags.trader or
        item.flags.owned or
        item.flags.garbage_collect or
        item.flags.on_fire
    then
        return false
    end
    -- Allow user to exclude items by forbidding when adding arbitrary items.
    if options.addItem and item.flags.forbid then
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

function isAlreadyBurialItem(unit, item)
    -- Prevent duplicating unit's own corpse parts in corpse_parts.
    for _, v in ipairs(unit.corpse_parts) do
        if item.id == v then return true end
    end
    -- Prevent adding burial items belonging to other units with an assigned tomb.
    for _, building in ipairs(df.global.world.buildings.other.ZONE_TOMB) do
        if not CheckTombZone(building, -1) then
            local otherUnit = df.unit.find(building.assigned_unit_id)
            for _, v in ipairs(otherUnit.corpse_parts) do
                if item.id == v then return true end
            end
        end
    end
    return false
end

-- Set additional arbitrary items to be valid for burial.
function AddBurialItems(unit, tomb, options)
    local coffin = GetCoffin(tomb)
    local item = dfhack.gui.getSelectedItem(true)
    local cursor = guidm.getCursorPos()
    local burialItems = {}
    local strAddItem = 'Adding %s for burial with unit.'
    local strItemName
    local strCannotInter = 'Unable to inter additional item(s);\n ...%s.'
    local strNoCoffin = 'no coffin in assigned tomb zone'
    local strNotValidItem = 'selected item is not valid for burial'
    local strNoCursorItems = 'no items at cursor are valid for burial'
    local strNoSelect = 'no item selected and keyboard cursor not enabled'
    if not coffin then
        print(string.format(strCannotInter, strNoCoffin))
    elseif item then
        if isMoveableItem(tomb, coffin, item, options) and
            not isAlreadyBurialItem(unit, item)
        then
            strItemName = item and dfhack.items.getReadableDescription(item) or nil
            print(string.format(strAddItem, strItemName))
            table.insert(burialItems, item)
        else
            print(string.format(strCannotInter, strNotValidItem))
        end
    -- Use keyboard cursor to set multiple items for burial.
    elseif cursor then
        -- Filter items to iterate according to tile block at cursor.
        local block = dfhack.maps.getTileBlock(cursor)
        for _, blockItem_id in ipairs(block.items) do
            local blockItem = df.item.find(blockItem_id)
            local x, y, _ = dfhack.items.getPosition(blockItem)
            if x == cursor.x and y == cursor.y then
                item = blockItem
                if isMoveableItem(tomb, coffin, item, options) and
                    not isAlreadyBurialItem(unit, item)
                then
                    strItemName = item and dfhack.items.getReadableDescription(item) or nil
                    print(string.format(strAddItem, strItemName))
                    table.insert(burialItems, item)
                end
            end
        end
        if #burialItems == 0 then
            print(string.format(strCannotInter, strNoCursorItems))
        end
    else
        print(string.format(strCannotInter, strNoSelect))
    end
    if #burialItems > 0 then
        local corpseParts = unit.corpse_parts
        for _, burialItem in ipairs(burialItems) do
            burialItem.flags.dead_dwarf = true
            corpseParts:insert('#', burialItem.id)
        end
    end
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
        print('Unable to move burial item(s);\n ...no coffin in assigned tomb zone.')
    end
end

-- Process unit and tomb before executing operations.
local function PreOpProcess(unit, building, options)
    local tomb = building and GetTombFromZone(building)
    local entombed = false
    if not options.addItem then
        if not unit then
            unit = GetUnitFromCorpse()
        end
        if not tomb then
            tomb = GetTombFromUnit(unit)
        end
        if unit and tomb then
            -- Unit has a tomb, but it's not the specified tomb.
            if IterateTombZones(unit.id) and tomb ~= IterateTombZones(unit.id) then
                qerror('Unit already has an assigned tomb zone.')
            -- Specified tomb is not assigned to unit, and specified tomb is not unassigned.
            elseif not CheckTombZone(tomb, unit.id) and not CheckTombZone(tomb, -1) then
                qerror('Specified tomb zone is already assigned to a different unit.')
            end
        end
        if unit then
            if not tomb then
                qerror('No unassigned tomb zones are available.')
            end
            entombed = isEntombed(unit)
        else
            qerror('No item selected or unit specified.')
        end
    else
        -- Either a unit or an assigned tomb zone must be specified when add-item is called,
        -- as corpse/body part items cannot be used to assign tomb zones with this option.
        local strCannotInter = 'Unable to inter additional item(s);\n ...%s.'
        local strNoUnit = 'specified tomb zone is not assigned to a unit'
        local strNoTomb = 'specified unit has no assigned tomb zone'
        local strWrongPair = 'specified tomb zone is not assigned to specified unit'
        local strNotSpecified = 'no assigned tomb zone or unit with assigned tomb zone specified'
        if tomb and not unit then
            if tomb.assigned_unit_id == -1 then
                qerror(string.format(strCannotInter, strNoUnit))
            end
            unit = df.unit.find(tomb.assigned_unit_id)
            if not unit then
                qerror(string.format(strCannotInter, strNoUnit))
            end
        elseif unit and not tomb then
            tomb = GetTombFromUnit(unit)
            if not tomb then
                -- Equivalent to having no available unassigned tomb zones,
                -- but emphasize on unit having no assigned tomb.
                qerror(string.format(strCannotInter, strNoTomb))
            end
        elseif tomb and unit then
            if not CheckTombZone(tomb, unit.id) and not CheckTombZone(tomb, -1) then
                qerror(string.format(strCannotInter, strWrongPair))
            end
        else
            qerror(string.format(strCannotInter, strNotSpecified))
        end
    end
    return unit, tomb, entombed
end

local function ParseCommandLine(args)
    local unit, building
    local options = {
        help = false,
        addItem = false,
        haulNow = false,
        teleport = false
    }
    local positionals = argparse.processArgsGetopt(args, {
        {'h', 'help', handler = function() options.help = true end},
        {'u', 'unit', hasArg = true, handler = function(arg)
            local unit_id = argparse.positiveInt(arg, 'unit')
            unit = unit_id and df.unit.find(unit_id)
            if not unit then qerror('Invalid unit ID.') end end
        },
        {'t', 'tomb', hasArg = true, handler = function(arg)
            local building_id = argparse.positiveInt(arg, 'tomb')
            building = building_id and df.building.find(building_id)
            if not building then qerror('Invalid zone ID.') end end
        },
        {'a', 'add-item', handler = function() options.addItem = true end},
        {'n', 'haul-now', handler = function() options.haulNow = true end},
        -- Commenting out to make this script a non-Armok tool.
        -- {'', 'teleport', handler = function() options.teleport = true end}
    })
    return unit, building, options
end

local function Main(args)
    if not dfhack.isSiteLoaded() and not dfhack.world.isFortressMode() then
        qerror('This script requires the game to be in fortress mode.')
    end
    local unit, building, options = ParseCommandLine(args)
    if args == 'help' or options.help then
        print(dfhack.script_help())
        return
    end
    if options.haulNow and options.teleport then
        qerror('Burial items cannot be teleported and tasked for hauling simultaneously.')
    end
    local tomb, entombed
    unit, tomb, entombed = PreOpProcess(unit, building, options)
    if entombed then
        print('Unit is already completely interred in a tomb zone.')
    elseif unit and tomb then
        AssignToTomb(unit, tomb)
        if options.addItem then
            AddBurialItems(unit, tomb, options)
        end
        if options.haulNow or options.teleport then
            InterItems(tomb, unit, options)
        end
    end
end

if not dfhack_flags.module then
    Main({...})
end
