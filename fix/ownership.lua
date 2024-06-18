-- unit thinks they own the item but the item doesn't hold the proper
-- ref that actually makes this true
local function owner_not_recognized()
    for _,unit in ipairs(dfhack.units.getCitizens()) do
        for index = #unit.owned_items-1, 0, -1 do
            local item = df.item.find(unit.owned_items[index])
            if not item then goto continue end

            for _, ref in ipairs(item.general_refs) do
                if df.general_ref_unit_itemownerst:is_instance(ref) then
                    -- make sure the ref belongs to unit
                    if ref.unit_id == unit.id then goto continue end
                end
            end
            print('Erasing ' .. dfhack.TranslateName(unit.name) .. ' invalid claim on item #' .. item.id)
            unit.owned_items:erase(index)
            ::continue::
        end
    end
end

local args = {...}

if args[1] == "help" then
    print(dfhack.script_help())
    return
end

owner_not_recognized()
