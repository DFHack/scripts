function undump_buildings()
    local undumped = 0
    for _, building in ipairs(df.global.world.buildings.all) do
        -- Zones and stockpiles don't have the contained_items field.
        if not df.building_actual:is_instance(building) then goto continue end
        for _, contained in ipairs(building.contained_items) do
            if contained.use_mode == df.building_item_role_type.PERM and
                contained.item.flags.dump
            then
                undumped = undumped + 1
                contained.item.flags.dump = false
            end
        end
        ::continue::
    end

    if undumped > 0 then
        local s = undumped == 1 and '' or 's'
        print(('Undumped %s in-use building item%s'):format(undumped, s))
    end
end

undump_buildings()
