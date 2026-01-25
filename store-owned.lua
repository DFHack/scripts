-- Task units to store their owned items.

local argparse = require("argparse")
local utils = require('utils')

local function GetUnit(item, options)
    local unit = dfhack.items.getOwner(item)
    if not unit then
        print('Selected item is not owned by any unit.')
    elseif not dfhack.units.isJobAvailable(unit) and not options.discard then
        unit = nil
        print('Owner of selected item is currently busy.')
    end
    return unit
end

local function isValidItem(item, unit)
    local validItem = true
    local itemPos = item and xyz2pos(dfhack.items.getPosition(item))
    local building = dfhack.items.getHolderBuilding(item)
    if item.flags.in_job or
        item.flags.hostile or
        item.flags.removed or
        item.flags.dead_dwarf or
        item.flags.rotten or
        item.flags.spider_web or
        item.flags.construction or
        item.flags.encased or
        item.flags.trader or
        item.flags.garbage_collect or
        item.flags.forbid or
        item.flags.dump or
        item.flags.on_fire or
        item.flags.melt or
        not dfhack.maps.isTileVisible(itemPos)
    then
        validItem = false
        print('Selected item cannot be stored.')
    elseif building then
        for _, civzone in ipairs(building.relations) do
            if civzone.assigned_unit_id == unit.id then
                if df.building_cabinetst:is_instance(building) or
                    df.building_armorstandst:is_instance(building) or
                    df.building_weaponrackst:is_instance(building) or
                    df.building_boxst:is_instance(building)
                then
                    validItem = false
                    print('Selected item is already stored in the owner\'s room furniture.')
                    goto skipCheck
                end
            end
        end
        if item.flags.in_building then
            validItem = false
            print('Selected item is part of a building.')
        end
    else
        local unitPos = unit and xyz2pos(dfhack.units.getPosition(unit))
        if not dfhack.maps.canWalkBetween(itemPos, unitPos) then
            validItem = false
            print('Owner of selected item cannot reach the item.')
        end
    end
    ::skipCheck::
    return validItem
end

local function isClothing(item)
    if df.item_armorst:is_instance(item) or
        df.item_shoesst:is_instance(item) or
        df.item_glovesst:is_instance(item) or
        df.item_helmst:is_instance(item) or
        df.item_pantsst:is_instance(item)
    then
        return true
    end
    return false
end

local function isArmor(item)
    if isClothing(item) and item.subtype.armorlevel > 0 then
        return true
    end
    return false
end

local function isWeapon(item)
    if df.item_weaponst:is_instance(item) then
        return true
    end
    return false
end

local function isGoods(item)
    if df.item_amuletst:is_instance(item) or
        df.item_braceletst:is_instance(item) or
        df.item_crownst:is_instance(item) or
        df.item_earringst:is_instance(item) or
        df.item_figurinest:is_instance(item) or
        df.item_gemst:is_instance(item) or
        df.item_instrumentst:is_instance(item) or
        df.item_ringst:is_instance(item) or
        df.item_scepterst:is_instance(item) or
        df.item_totemst:is_instance(item) or
        df.item_toyst:is_instance(item) or
        df.item_toolst:is_instance(item) -- Owned books and scrolls, which can be stored in boxes.
    then
        return true
    end
    return false
end

local function GetContainerType(item)
    -- Use chest as default, in case of any item not explicitly categorized.
    local containerType = df.building_boxst
    if isArmor(item) then
        containerType = df.building_armorstandst
    elseif isWeapon(item) then
        containerType = df.building_weaponrackst
    elseif isClothing(item) then
        containerType = df.building_cabinetst
    elseif isGoods(item) then
        containerType = df.building_boxst
    end
    return containerType
end

local function isEnoughCapacity(item, container)
    local capacity = 0
    local totalVol = 0
    local itemVol = item:getVolume()
    for _, containedItem in ipairs(container.contained_items) do
        -- Assume only one item is the container.
        if containedItem.item.flags.in_building and capacity == 0 then
            if df.item_armorstandst:is_instance(containedItem.item) or
                df.item_weaponrackst:is_instance(containedItem.item) or
                df.item_cabinetst:is_instance(containedItem.item) or
                df.item_boxst:is_instance(containedItem.item)
            then
                capacity = dfhack.items.getCapacity(containedItem.item)
            end
        else
            totalVol = totalVol + containedItem.item:getVolume()
        end
    end
    local remainingCapacity = capacity - (totalVol + itemVol)
    if remainingCapacity >= 0 then
        return true
    end
    return false
end

local function GetCivzoneName(civzone)
    local strCivzoneName
    if #civzone.name > 0 then
        strCivzoneName = civzone.name
    else
        strCivzoneName = dfhack.buildings.getName(civzone)
    end
    return strCivzoneName
end

local function GetPosFromContainer(item, unitPos, civzone)
    local containerType = GetContainerType(item)
    for _, container in ipairs(civzone.contained_buildings) do
        if containerType:is_instance(container) then
            local containerPos = utils.getBuildingCenter(container)
            if containerPos and
                isEnoughCapacity(item, container) and
                dfhack.maps.canWalkBetween(containerPos, unitPos)
            then
                local jobPos = containerPos
                local containerName = dfhack.buildings.getName(container)
                local strCivzoneName = GetCivzoneName(civzone)
                print(('Sufficient storage space available;\n ...selected item will be stored inside %s in %s.'):format(containerName, strCivzoneName))
                return jobPos
            end
        end
    end
    return nil
end

-- Items can be placed on any walkable tile, but in order to mimic native behavior
-- more closely, the item will be placed on a tile not occupied by a building.
-- However, to reduce visual clutter, any loose items already occupying the tile will be ignored.
local function GetPosFromTile(unitPos, civzone)
    local jobPos = civzone and xyz2pos(civzone.centerx, civzone.centery, civzone.z)
    if not dfhack.maps.canWalkBetween(jobPos, unitPos) or dfhack.buildings.findAtTile(jobPos) then
        jobPos = nil
        local x1, x2, y1, y2, z = civzone.x1, civzone.x2, civzone.y1, civzone.y2, civzone.z
        for y = y1, y2, 1 do
            for x = x1, x2, 1 do
                if dfhack.buildings.containsTile(civzone, x, y) then
                    local tilePos = xyz2pos(x, y, z)
                    if dfhack.maps.canWalkBetween(tilePos, unitPos) and
                        not dfhack.buildings.findAtTile(tilePos)
                    then
                        jobPos = tilePos
                        goto returnPos
                    end
                end
            end
        end
    end
    ::returnPos::
    if jobPos then
        local strCivzoneName = GetCivzoneName(civzone)
        print(('Unobstructed tile available;\n ...selected item will be dropped off on the floor of %s.'):format(strCivzoneName))
    end
    return jobPos
end

local function GetPosFromCivzone(civzones, item, unitPos, zoneType, putOnFloor)
    local jobPos
    for _, civzone in ipairs(civzones) do
        if civzone.type == zoneType then
            strCivzoneName = GetCivzoneName(civzone)
            if not putOnFloor then
                jobPos = GetPosFromContainer(item, unitPos, civzone)
            else
                jobPos = GetPosFromTile(unitPos, civzone)
            end
        end
        if jobPos then return jobPos end
    end
    return nil
end

local function GetPosFromOwnedCivzone(civzones, item, unitPos, putOnFloor)
    local jobPos
    local zoneTypes = {
        df.civzone_type.Bedroom,
        df.civzone_type.Office,
        df.civzone_type.DiningHall,
        df.civzone_type.Tomb
    }
    for _, zoneType in ipairs(zoneTypes) do
        jobPos = GetPosFromCivzone(civzones, item, unitPos, zoneType, putOnFloor)
        if jobPos then return jobPos end
    end
    return nil
end

local function GetPosFromDepot(unitPos)
    for _, depot in ipairs(df.global.world.buildings.other.TRADE_DEPOT) do
        -- Item will be dropped on the center tile of the trade depot rather than stored inside it.
        local depotPos = depot and utils.getBuildingCenter(depot)
        if depotPos and dfhack.maps.canWalkBetween(depotPos, unitPos) then
            local jobPos = depotPos
            print('Depot accessible;\n ...selected item will be dropped off at the '..dfhack.buildings.getName(depot)..'.')
            return jobPos
        else
            print('Unable to drop selected item off at the trade depot.')
        end
    end
    return nil
end

-- Prioritize storing in bedroom > office > dining room > tomb > dormitory > trade depot.
local function GetJobPos(unit, item, options)
    local jobPos
    local unitPos = unit and xyz2pos(dfhack.units.getPosition(unit))
    local civzones = unit and unit.owned_buildings
    local putOnFloor = false
    local strNoStorage = 'Unable to store selected item inside a storage furniture in'
    local strNoTile = 'Unable to drop selected item off on the floor of'
    local strOwnRoom = 'owner\'s assigned room(s)'
    local strDorm = 'the dormitory'
    if options.dorm or #civzones < 1 then
        if #civzones < 1 then
            print('Owner of selected item does not have any assigned rooms.')
        end
        goto getFromDorm
    elseif options.depot then
        goto getFromDepot
    end
    -- Get container in owned rooms to put item in.
    jobPos = GetPosFromOwnedCivzone(civzones, item, unitPos, putOnFloor)
    if not jobPos then
        print(('%s %s.'):format(strNoStorage, strOwnRoom))
        putOnFloor = true
        -- Get tile in owned rooms to drop item on.
        jobPos = GetPosFromOwnedCivzone(civzones, item, unitPos, putOnFloor)
    end
    ::getFromDorm::
    if not jobPos then
        if not options.dorm and #civzones > 0 then
            print(('%s %s.'):format(strNoTile, strOwnRoom))
        end
        if #df.global.world.buildings.other.ZONE_DORMITORY > 0 then
            civzones = df.global.world.buildings.other.ZONE_DORMITORY
        else
            print('No dormitory available.')
            goto getFromDepot
        end
        local zoneType = df.civzone_type.Dormitory
        putOnFloor = false
        -- Get container in dorm to put item in.
        jobPos = GetPosFromCivzone(civzones, item, unitPos, zoneType, putOnFloor)
        if not jobPos then
            print(('%s %s.'):format(strNoStorage, strDorm))
            putOnFloor = true
            -- Get tile in dorm to drop item on.
            jobPos = GetPosFromCivzone(civzones, item, unitPos, zoneType, putOnFloor)
        end
    end
    ::getFromDepot::
    if not jobPos then
        if not options.depot and #civzones > 0 then
            print(('%s %s.'):format(strNoTile, strDorm))
        end
        if #df.global.world.buildings.other.TRADE_DEPOT > 0 then
            jobPos = GetPosFromDepot(unitPos)
        else
            print('No trade depot available.')
        end
    end
    return jobPos
end

local function AssignJob(item, unit, jobPos)
    local job = df.job:new()
    job.job_type = df.job_type.StoreOwnedItem
    job.pos = jobPos
    dfhack.job.attachJobItem(job, item, df.job_role_type.Hauled, -1, -1)
    dfhack.job.addWorker(job, unit)
    dfhack.job.linkIntoWorld(job, true)
    local strUnitName = unit and dfhack.units.getReadableName(unit)
    local strItemName = item and dfhack.items.getReadableDescription(item)
    print(('%s has been tasked to store away %s.'):format(strUnitName, strItemName))
end

local function RemoveFromUniform(item, unit, options)
    if options.discard then
        local strItemName = item and dfhack.items.getReadableDescription(item)
        local strUnitName = unit and dfhack.units.getReadableName(unit)
        dfhack.items.setOwner(item, nil)
        print(('Ownership of %s was removed from %s.'):format(strItemName, strUnitName))
    end
    local uniforms = {
        unit.uniform.uniforms.CLOTHING,
        unit.uniform.uniforms.REGULAR,
        unit.uniform.uniforms.TRAINING,
        unit.uniform.uniforms.TRAINING_RANGED
    }
    for _, uniform in ipairs(uniforms) do
        local idx = utils.linear_index(uniform, item.id)
        if idx then uniform:erase(idx) end
    end
end

local function ParseCommandLine(args)
    local options = {
        help = false,
        dorm = false,
        depot = false,
        discard = false
    }
    local positionals = argparse.processArgsGetopt(args, {
        {'h', 'help', handler = function() options.help = true end},
        {'', 'dorm', handler = function() options.dorm = true end},
        {'', 'depot', handler = function() options.depot = true
        options.dorm = false end},
        {'', 'discard', handler = function() options.discard = true
        options.dorm = false options.depot = false end},
    })
    return options
end

local function Main(args)
    local options = ParseCommandLine(args)
    if args[1] == 'help' or options.help then
        print(dfhack.script_help())
        return
    end
    local item = dfhack.gui.getSelectedItem(true)
    if not item then
        qerror('No item selected.')
    end
    local unit = GetUnit(item, options)
    local strCannotStore = 'Unable to task selected item for storage.'
    if unit and not options.discard then
        local validItem = isValidItem(item, unit)
        if not validItem then
            qerror(strCannotStore)
        end
        local jobPos = GetJobPos(unit, item, options)
        if not jobPos then
            qerror('Unable to store selected item in any owned room, dormitory, or trade depot.')
        end
        AssignJob(item, unit, jobPos)
    elseif not unit and not options.discard then
        qerror(strCannotStore)
    else
        if not unit then
            qerror('Cannot remove ownership of an ownerless item.')
        end
    end
    RemoveFromUniform(item, unit, options)
end

if not dfhack.isSiteLoaded() and not dfhack.world.isFortressMode() then
    qerror('This script requires the game to be in fortress mode.')
end

Main({...})
