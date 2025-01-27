local utils = require('utils')

-- unit thinks they own the item but the item doesn't hold the proper
-- ref that actually makes this true
local function clean_item_ownership()
    for _,unit in ipairs(dfhack.units.getCitizens()) do
        for index = #unit.owned_items-1, 0, -1 do
            local item_id = unit.owned_items[index]
            local item = df.item.find(item_id)
            if item then
                for _, ref in ipairs(item.general_refs) do
                    if df.general_ref_unit_itemownerst:is_instance(ref) then
                        -- make sure the ref belongs to unit
                        if ref.unit_id == unit.id then goto continue end
                    end
                end
            end
            print(('fix/ownership: Erasing invalid claim on item #%d for %s'):format(
                item_id, dfhack.df2console(dfhack.units.getReadableName(unit))))
            unit.owned_items:erase(index)
            ::continue::
        end
    end
end

local other = df.global.world.buildings.other
local zone_vecs = {
    other.ZONE_BEDROOM,
    other.ZONE_OFFICE,
    other.ZONE_DINING_HALL,
    other.ZONE_TOMB,
}
local function relink_zones()
    for _,zones in ipairs(zone_vecs) do
        for _,zone in ipairs(zones) do
            local unit = zone.assigned_unit
            if not unit then goto continue end
            if not utils.linear_index(unit.owned_buildings, zone.id, 'id') then
                print(('fix/ownership: Restoring %s ownership link for %s'):format(
                    df.civzone_type[zone:getSubtype()], dfhack.df2console(dfhack.units.getReadableName(unit))))
                dfhack.buildings.setOwner(zone, nil)
                dfhack.buildings.setOwner(zone, unit)
            end
            ::continue::
        end
    end
end

local args = {...}

if args[1] == "help" then
    print(dfhack.script_help())
    return
end

clean_item_ownership()
relink_zones()
