-- Scan the map for ore veins

local argparse = require('argparse')

local function extractKeys(target_table)
    local keyset = {}
    for k, _ in pairs(target_table) do
        table.insert(keyset, k)
    end
    return keyset
end

local function getRandomTableKey(target_table)
    if not target_table then
        return nil
    end

    local keyset = extractKeys(target_table)
    if #keyset == 0 then
        return nil
    end

    return keyset[math.random(#keyset)]
end

local function getRandomFromTable(target_table)
    if not target_table then
        return nil
    end

    local key = getRandomTableKey(target_table)
    if not key then
        return nil
    end

    return target_table[key]
end

local function sortTableBy(tbl, sort_func)
    local sorted = {}
    for _, value in pairs(tbl) do
        table.insert(sorted, value)
    end

    table.sort(sorted, sort_func)

    return sorted
end

local function matchesMetalOreById(mat_indices, target_ore)
    for _, mat_index in ipairs(mat_indices) do
        local metal_raw = df.global.world.raws.inorganics[mat_index]
        if metal_raw ~= nil and string.lower(metal_raw.id) == target_ore then
            return true
        end
    end

    return false
end

local tile_attrs = df.tiletype.attrs

local function isValidMineralTile(opts, pos, check_designation)
    if not opts.all and not dfhack.maps.isTileVisible(pos) then return false end
    local tt = dfhack.maps.getTileType(pos)
    if not tt then return false end
    return tile_attrs[tt].material == df.tiletype_material.MINERAL and
        (not check_designation or dfhack.maps.getTileFlags(pos).dig == df.tile_dig_designation.No) and
        tile_attrs[tt].shape == df.tiletype_shape.WALL
end

local function findOres(opts, check_designation, target_ore)
    local ore_types = {}
    for _, block in ipairs(df.global.world.map.map_blocks) do
        for _, bevent in ipairs(block.block_events) do
            if bevent:getType() ~= df.block_square_event_type.mineral then
                goto skipevent
            end

            local ino_raw = df.global.world.raws.inorganics[bevent.inorganic_mat]
            if not ino_raw.flags.METAL_ORE then
                goto skipevent
            end

            if not opts.all and not bevent.flags.discovered then
                goto skipevent
            end

            local lower_raw = string.lower(ino_raw.id)
            if not target_ore or lower_raw == target_ore or matchesMetalOreById(ino_raw.metal_ore.mat_index, target_ore) then
                local positions = ensure_key(ore_types, bevent.inorganic_mat, {
                        inorganic_id = ino_raw.id,
                        inorganic_mat = bevent.inorganic_mat,
                        metal_ore = ino_raw.metal_ore,
                        positions = {}
                    }).positions
                local block_pos = block.map_pos
                for y=0,15 do
                    local row = bevent.tile_bitmask.bits[y]
                    for x=0,15 do
                        if row & (1 << x) == 1 then
                            local pos = xyz2pos(block_pos.x + x, block_pos.y + y, block_pos.z)
                            if isValidMineralTile(opts, pos, check_designation) then
                                table.insert(positions, pos)
                            end
                        end
                    end
                end
            end
            :: skipevent ::
        end
    end

    -- trim veins with zero valid tiles
    for key,vein in pairs(ore_types) do
        if #vein.positions == 0 then
            ore_types[key] = nil
        end
    end

    return ore_types
end

local function designateDig(pos)
    local designation = dfhack.maps.getTileFlags(pos)
    designation.dig = df.tile_dig_designation.Default
    dfhack.maps.getTileBlock(pos).flags.designated = true
end

local function getOreDescription(opts, vein)
    local visible = opts.all and '' or 'visible '
    local str = ('%5d %stile(s) of %s ('):format(#vein.positions, visible, tostring(vein.inorganic_id):lower())
    for _, mat_index in ipairs(vein.metal_ore.mat_index) do
        local metal_raw = df.global.world.raws.inorganics[mat_index]
        str = ('%s%s, '):format(str, string.lower(metal_raw.id))
    end

    str = str:gsub(', %s*$', '') .. ')'
    return str
end

local function selectOreTile(opts, target_ore)
    local ore_types = findOres(opts, true, target_ore)
    local target_vein = getRandomFromTable(ore_types)
    if target_vein == nil then
        local visible = opts.all and '' or 'visible '
        qerror('Cannot find any undesignated ' .. visible .. target_ore)
    end
    local target_pos = target_vein.positions[math.random(#target_vein.positions)]
    dfhack.gui.revealInDwarfmodeMap(target_pos, true, true)
    designateDig(target_pos)
    print(('Here is some %s'):format(target_vein.inorganic_id))
end

local opts = {
    all=false,
    help=false,
}

local positionals = argparse.processArgsGetopt({...}, {
    {'a', 'all', handler=function() opts.all = true end},
    {'h', 'help', handler=function() opts.help = true end},
})

local target_ore = positionals[1]
if target_ore == 'help' or opts.help then
    print(dfhack.script_help())
    return
end

if not target_ore or target_ore == 'list' then
    local ore_types = findOres(opts, false)
    local sorted = sortTableBy(ore_types, function(a, b) return #a.positions < #b.positions end)

    for _,ore_type in ipairs(sorted) do
        print('  ' .. getOreDescription(opts, ore_type))
    end
else
    selectOreTile(opts, positionals[1]:lower())
end
