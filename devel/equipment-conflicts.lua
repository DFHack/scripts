--[[

This script analyzes uniforms of squad members and reports items that are
claimed by more than one squad member.

--]]

local assignments = {}

-- TODO: gather the item assignments we would like to remove.
-- TOTHINK: just removing them from the uniform and pick-up tables is insufficient.
-- conflicting items just get added back.
-- local release = {}

local function addToNestedTable(outer_table, outer_key, value)
    if outer_table[outer_key] then
        table.insert(outer_table[outer_key],value)
    else
        outer_table[outer_key] = { value }
    end
end

-- analyze uniforms of squad members
for _, unit in pairs(dfhack.units.getCitizens(true)) do
    local squad_id = unit.military.squad_id
    if 0 <= squad_id then
        for _, item_id in ipairs(unit.military.uniforms[unit.military.cur_uniform]) do
            addToNestedTable(assignments,item_id,unit.id)
        end
    end
end

-- check for and report conflicts
for item_id,unit_ids in pairs(assignments) do
    if #unit_ids > 1 then
        local item = df.item.find(item_id)
        if item then
            local holder = dfhack.items.getHolderUnit(item)
            local found = false
            print(dfhack.items.getDescription(item, 0, true),'(',item_id,') claimed by:')
            for _,unit_id in pairs(unit_ids) do
                local unit = df.unit.find(unit_id)
                if unit then
                    dfhack.print(
                        '   ', dfhack.TranslateName(unit.name),'in',
                        dfhack.military.getSquadName(unit.military.squad_id)
                    )
                    if holder and unit.id == holder.id then
                        found = true
                        print (' (equipped)')
                    else
                        print()
                        -- addToNestedTable(release,unit.id,item_id)
                    end
                end
            end
            if not found then
                if holder then
                    print('    carried by', dfhack.TranslateName(holder.name))
                else
                    print('    no current holder')
                end
            end
            print()
        else
            error('assigned item does not exist')
        end
    end
end
