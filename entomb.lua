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
    if building.type == df.civzone_type.Tomb then
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

function PutInCoffin(coffin, item)
    if item then
        -- Remove job from item to allow it to be teleported.
        if item.flags.in_job then
            local inJob = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
            local job = inJob and inJob.data.job
            if job then
                dfhack.job.removeJob(job)
            end
        end
        if (dfhack.items.moveToBuilding(item, coffin, df.building_item_role_type.TEMP)) then
            -- Flag the item become an interred item, otherwise it will be hauled back to stockpiles.
            item.flags.in_building = true
        end
    end
end

function HaulToCoffin(tomb, coffin, item)
    if not tomb or not coffin or not item then return end

    if dfhack.items.getHolderBuilding(item) == coffin and item.flags.in_building == true then
print("DEBUG: item is already properly interred, skipping", tomb.id, dfhack.buildings.getName(tomb),
coffin.id, dfhack.buildings.getName(coffin), item.id, dfhack.items.getReadableDescription(item))
        return  -- already interred in this coffin, skip
    end

    -- TODO Consider what should happen when certain item.flags are set, particularly .forbid and .dump.
    -- TODO Consider copy-paste-modify scripts/internal/caravan/pedestal.lua::is_displayable_item()

    -- Remove current job from item to allow it to be moved to the tomb.
    if item.flags.in_job then
        local inJob = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
        local job = inJob and inJob.data.job or nil
        if job
            and job.job_type == df.job_type.PlaceItemInTomb
            and dfhack.job.getGeneralRef(job, df.general_ref_type.BUILDING_HOLDER) ~= nil
            and dfhack.job.getGeneralRef(job, df.general_ref_type.BUILDING_HOLDER).building_id == tomb.id
        then
print("DEBUG: desired job already exists, skipping", tomb.id, dfhack.buildings.getName(tomb),
coffin.id, dfhack.buildings.getName(coffin), item.id, dfhack.items.getReadableDescription(item), job.id)
            return  -- desired job already exists, skip
        end
        if job then
print("DEBUG: removing current job from this item", item.id, dfhack.items.getReadableDescription(item),
job.id, df.job_type[job.job_type])
            dfhack.job.removeJob(job)
        end
    end

    local pos = utils.getBuildingCenter(coffin)

    local job = df.job:new()
    job.job_type = df.job_type.PlaceItemInTomb
    job.pos = pos

    dfhack.job.attachJobItem(job, item, df.job_role_type.Hauled, -1, -1)
    dfhack.job.addGeneralRef(job, df.general_ref_type.BUILDING_HOLDER, tomb.id)
    tomb.jobs:insert('#', job)

    dfhack.job.linkIntoWorld(job, true)
end

local function GetCoffin(tomb)
    local coffin
    if tomb.type == df.civzone_type.Tomb then
        for _, building in ipairs(tomb.contained_buildings) do
            if df.building_coffinst:is_instance(building) then coffin = building end
        end
    -- Allow other scripts to call this function and pass the actual coffin building instead.
    elseif df.building_coffinst:is_instance(tomb) then
        coffin = tomb
    end
    return coffin
end

function AssignToTomb(unit, tomb, forceBurial)
    local corpseParts = unit.corpse_parts
    local strBurial = '%s assigned to %s for burial.'
    local strTomb = 'a tomb zone'
    if #tomb.name > 0 then strTomb = tomb.name end
    local strCorpseItems = '(%d corpse or body part%s)'
    local strNoCorpse = '%s has no corpse or body parts available for burial.'
    local strUnitName = unit and dfhack.units.getReadableName(unit)
    local strPlural = ''
    local incident_id = unit.counters.death_id
    if incident_id ~= -1 then
        local incident = df.incident.find(incident_id)
        -- Corpse will not be interred if not yet discovered,
        -- which never happens for units not belonging to player's civ.
        incident.flags.discovered = true
    end
    local burialItemCount = FlagForBurial(unit, corpseParts)
    if burialItemCount == 0 then
        print(string.format(strNoCorpse, strUnitName))
    else
        tomb.assigned_unit_id = unit.id
        print(string.format(strBurial, strUnitName, strTomb))
        if forceBurial then
            local coffin = GetCoffin(tomb)
            if coffin then
                for _, item_id in ipairs(corpseParts) do
                    local item = df.item.find(item_id)
                    -- PutInCoffin(coffin, item)
                    HaulToCoffin(tomb, coffin, item)
                end
                print('Corpse items have been teleported into a coffin.')
            else
                print('No coffin in the assigned tomb zone.\nCorpse items will not be teleported into the tomb zone.')
            end
        end
        if burialItemCount > 1 then strPlural = 's' end
        print(string.format(strCorpseItems, burialItemCount, strPlural))
    end
end

local function parseArgs(args)
    local unit, tomb, forceBurial
    if args and #args > 0 then
        for i, v in ipairs(args) do
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
            if v == 'now' then forceBurial = true end
        end
    end
    return unit, tomb, forceBurial
end

local function Main(args)
    local unit, tomb, forceBurial = parseArgs(args)
    local entombed
    if not unit then unit = GetUnitFromCorpse() end
    if unit then
        if not tomb then tomb, entombed = GetTombZone(unit) end
        if entombed then
            print('Unit is already completely interred in a tomb zone.')
        elseif tomb then
            AssignToTomb(unit, tomb, forceBurial)
        else
            print('No unassigned tomb zones are available.')
        end
    else
        qerror('No item selected or unit specified.')
    end
end

if not dfhack_flags.module then
    Main({...})
end
