-- Fix quivers and training ammo items to allow archery practice to take place.

local argparse = require("argparse")
local utils = require('utils')

local function GetTrainingSquads()
    local trainingSquads = {}
    for _, squad in ipairs(df.global.world.squads.all) do
        if squad.entity_id == df.global.plotinfo.group_id then
            if #squad.ammo.ammunition > 0 and squad.activity ~= -1 then
                table.insert(trainingSquads, squad)
            end
        end
    end
    return trainingSquads
end

local function isTrainingAmmo(ammoItem, squad)
    for _, ammoSpec in ipairs(squad.ammo.ammunition) do
        if ammoSpec.flags.use_training then
            for _, id in ipairs(ammoSpec.assigned) do
                if ammoItem.id == id then return true end
            end
        end
    end
    return false
end

local function GetTrainingAmmo(quiver, squad)
    local trainingAmmo = {}
    for _, generalRef in ipairs(quiver.general_refs) do
        if df.general_ref_contains_itemst:is_instance(generalRef) then
            local containedAmmo = generalRef
            local ammoItem = containedAmmo and df.item.find(containedAmmo.item_id)
            if ammoItem and
                df.item_ammost:is_instance(ammoItem) and
                isTrainingAmmo(ammoItem, squad)
            then
                table.insert(trainingAmmo, ammoItem)
            end
        end
    end
    return trainingAmmo
end

--[[ The following functions are commented out because the nature
-- of the bug has changed, requiring a different solution.
-- More info: https://discord.com/channels/793331351645323264/873014631315148840/1423311023254933576
local function UnassignAmmo(trainingAmmo, itemToKeep, itemsToRemove, squad, unit)
    local plotEqAssignedAmmo = df.global.plotinfo.equipment.items_assigned.AMMO
    local plotEqUnassignedAmmo = df.global.plotinfo.equipment.items_unassigned.AMMO
    local uniforms = {
        unit.uniform.uniforms.CLOTHING,
        unit.uniform.uniforms.REGULAR,
        unit.uniform.uniforms.TRAINING,
        unit.uniform.uniforms.TRAINING_RANGED
    }
    for _, ammoItem in ipairs(trainingAmmo) do
        if ammoItem ~= itemToKeep then
            local idx
            local assignedAmmo
            for _, ammoSpec in ipairs(squad.ammo.ammunition) do
                if ammoSpec.flags.use_training then
                    idx = utils.linear_index(ammoSpec.assigned, ammoItem.id)
                    if idx then
                        assignedAmmo = ammoSpec.assigned
                        goto unassignAmmo
                    end
                end
            end
            ::unassignAmmo::
            if assignedAmmo and idx then
                -- Unassign ammo item from squad.
                assignedAmmo:erase(idx)
                idx = utils.linear_index(squad.ammo.ammo_items, ammoItem.id)
                if idx then
                    -- Remove item/unit pairings.
                    squad.ammo.ammo_items:erase(idx)
                    squad.ammo.ammo_units:erase(idx)
                end
                idx = utils.linear_index(plotEqAssignedAmmo, ammoItem.id)
                if idx then
                    -- Move ammo item from assigned ammo list to unassigned ammo list.
                    plotEqAssignedAmmo:erase(idx)
                    plotEqUnassignedAmmo:insert('#', ammoItem.id)
                    utils.sort_vector(plotEqUnassignedAmmo)
                end
            end
            for _, uniform in ipairs(uniforms) do
                -- Remove ammo item from uniform.
                idx = utils.linear_index(uniform, ammoItem.id)
                if idx then uniform:erase(idx) end
            end
            if not utils.linear_index(itemsToRemove, ammoItem) then
                -- Force drop ammo item to avoid issue recurring if game reassigns the ammo item to squad.
                -- unit.uniform.uniform_drop:insert('#', ammoItem.id)
                -- Units that choose to haul the surplus ammo items to stockpiles instead of just dropping them
                -- on the ground will cancel their archery practice and put away the ammo item they were supposed
                -- to train with as well. Force dropping the surplus item with moveToGround circumvents this.
                local pos = unit and xyz2pos(dfhack.units.getPosition(unit))
                dfhack.items.moveToGround(ammoItem, pos)
            end
        end
    end
    -- Prompt unit to drop item.
    -- unit.uniform.pickup_flags.update = true
end

-- For practicality, item material, quality, and its creator (for masterworks), is ignored
-- for the purpose of combining the limited number of ammo items inside a quiver.
local function ConsolidateAmmo(trainingAmmo, squad, unit)
    local itemToKeep
    local itemsToRemove = {}
    -- Check first if any training ammo item already has a stack size of 25 or higher.
    for _, ammoItem in ipairs(trainingAmmo) do
        if ammoItem.stack_size >= 25 then
            itemToKeep = ammoItem
            goto unassignAmmo
        end
    end
    for _, ammoItem in ipairs(trainingAmmo) do
        if not itemToKeep then
            -- Keep the first item.
            itemToKeep = ammoItem
            goto nextItem
        end
        if itemToKeep and ammoItem ~= itemToKeep and itemToKeep.stack_size < 25 then
            local combineSize = 25 - itemToKeep.stack_size
            if ammoItem.stack_size > combineSize then
                itemToKeep.stack_size = itemToKeep.stack_size + combineSize
                ammoItem.stack_size = ammoItem.stack_size - combineSize
            else
                itemToKeep.stack_size = itemToKeep.stack_size + ammoItem.stack_size
                itemsToRemove[#itemsToRemove + 1] = ammoItem
            end
        end
        ::nextItem::
    end
    ::unassignAmmo::
    -- Unassign surplus ammo items first before removing any from the game.
    UnassignAmmo(trainingAmmo, itemToKeep, itemsToRemove, squad, unit)
    if #itemsToRemove > 0 then
        for _, item in ipairs(itemsToRemove) do
            dfhack.items.remove(item)
        end
    end
end
-- End of commented out functions ]]

-- Currently, only assignment to squad is practical, as pairing ammo items with
-- units directly has a tendency to cause the game to reshuffle the pairings.
local function AssignAmmoToSquad(newItems, item, squad)
    local plotEqAssignedAmmo = df.global.plotinfo.equipment.items_assigned.AMMO
    local assignedAmmo
    for _, ammoSpec in ipairs(squad.ammo.ammunition) do
        if utils.linear_index(ammoSpec.assigned, item.id) then
            assignedAmmo = ammoSpec
            break
        end
    end
    for _, newItem in ipairs(newItems) do
        assignedAmmo.assigned:insert('#', newItem.id)
        utils.sort_vector(assignedAmmo.assigned)
        plotEqAssignedAmmo:insert('#', newItem.id)
        utils.sort_vector(plotEqAssignedAmmo)
    end
end

local function SplitAmmo(item, squad, unit)
    local pos = unit and xyz2pos(dfhack.units.getPosition(unit))
    local newItems = {}
    repeat
        -- Create in quiver first, in case moving to ground fails.
        newItem = item:splitStack(5, true)
        newItem:categorize(true)
        dfhack.items.moveToGround(newItem, pos)
        table.insert(newItems, newItem)
    until item:getStackSize() <= 5
    AssignAmmoToSquad(newItems, item, squad)
end

local function RemoveQuiverFromInv(unit, quiver)
    local equippedQuiver
    for i, v in ipairs (unit.inventory) do
        -- Remove quiver only if it's not the last item in the inventory.
        if v.item == quiver and i ~= (#unit.inventory - 1) then
            equippedQuiver = v
        end
    end
    if equippedQuiver then
        local idx = utils.linear_index(unit.inventory, equippedQuiver)
        unit.inventory:erase(idx)
        return true
    end
    return false
end

local function MoveQuiverToEnd(unit, quiver)
    local caste = dfhack.units.getCasteRaw(unit)
    -- Re-add quiver to inventory regardless of whether there is a valid body part.
    local bodyPart = -1
    for i, v in ipairs(caste.body_info.body_parts) do
        if v.category == 'BODY_UPPER' then
            bodyPart = i
            break
        end
    end
    dfhack.items.moveToInventory(quiver, unit, df.inv_item_role_type.Worn, bodyPart)
end

local function FixTrainingUnits(trainingSquads, options)
    local splitAmmoCount = 0
    local fixQuiverCount = 0
    for _, squad in ipairs(trainingSquads) do
        for _, position in ipairs(squad.positions) do
            if position.occupant ~= -1 then
                local unit = df.unit.find(df.historical_figure.find(position.occupant).unit_id)
                local quiver = unit and df.item.find(position.equipment.quiver)
                if quiver then
                    local trainingAmmo = GetTrainingAmmo(quiver, squad)
                    local unitName = unit and dfhack.units.getReadableName(unit)
                    if #trainingAmmo == 1 then
                        local item = trainingAmmo[1]
                        -- Split ammo if it's the only training ammo item and its stack size is 25 or larger.
                        if item:getStackSize() >= 25 then
                            if not options.quiet then
                                print(('Splitting training ammo for %s...'):format(unitName))
                            end
                            SplitAmmo(item, squad, unit)
                            splitAmmoCount = splitAmmoCount + 1
                        end
                    end
                    if RemoveQuiverFromInv(unit, quiver) then
                        if not options.quiet then
                            print(('Moving quiver to the end for %s...'):format(unitName))
                        end
                        MoveQuiverToEnd(unit, quiver)
                        fixQuiverCount = fixQuiverCount + 1
                    end
                end
            end
        end
    end
    if not options.quiet then
        if splitAmmoCount > 0 then
            print(('%d stack(s) of ammo item(s) split into stacks of 5.'):format(splitAmmoCount))
        else
            print('No ammo items require splitting.')
        end
        if fixQuiverCount > 0 then
            print(('%d quiver(s) moved to the end of each unit\'s inventory list.'):format(fixQuiverCount))
        else
            print('No inventories require sorting.')
        end
    end
end

local function ParseCommandLine(args)
    local options = {
        help = false,
        quiet = false
    }
    local positionals = argparse.processArgsGetopt(args, {
        {'h', 'help', handler = function() options.help = true end},
        {'q', 'quiet', handler=function() options.quiet = true end}
    })
    return options
end

local function Main(args)
    local options = ParseCommandLine(args)
    if args[1] == 'help' or options.help then
        print(dfhack.script_help())
        return
    end
    local trainingSquads = GetTrainingSquads()
    if #trainingSquads < 1 then
        if not options.quiet then print('No ranged squads are currently training.') end
        return
    end
    FixTrainingUnits(trainingSquads, options)
end

if not dfhack.isSiteLoaded() and not dfhack.world.isFortressMode() then
    qerror('This script requires the game to be in fortress mode.')
end

Main({...})
