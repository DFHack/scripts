-- Export fortress map tile data to a JSON file
-- based on export-map.lua by mikerenfro:
-- https://github.com/mikerenfro/df-map-export/blob/main/export-map.lua
-- redux version by timothymtorres

local tm = require('tile-material')
local utils = require('utils')
local json = require('json')
local argparse = require('argparse')

local include_underworld_z = false
local underworld_z
local evilness

-- the layer of the underworld
for _, feature in ipairs(df.global.world.features.map_features) do
    if feature:getType() == df.feature_type.underworld_from_layer then
        underworld_z = feature.layer
    end
end

-- copied from agitation-rebalance.lua
-- check only one tile at the center of the map at ground lvl
-- (this ignores different biomes on the edges of the map)
local function get_evilness()
    -- check around ground level

    local lvls_above
    lvls_above = df.global.world.worldgen.worldgen_parms.levels_above_ground
    local ground_z = (df.global.world.map.z_count - 2) - lvls_above
    local xmax, ymax = dfhack.maps.getTileSize()
    local center_x, center_y = math.floor(xmax/2), math.floor(ymax/2)
    local rgnX, rgnY = dfhack.maps.getTileBiomeRgn(center_x, center_y, ground_z)
    local biome = dfhack.maps.getRegionBiome(rgnX, rgnY)

    return biome and biome.evilness or 0
end

local function classify_tile(options, x, y, z)
    -- The last z-levels of hell shrink their x/y size unexpectedly! (ಠ_ಠ)
    -- if your map is 190x190, the last hell z-levels are gonna be like 90x90
    if dfhack.maps.getTileType(x, y, z) == nil then
        return nil -- Designating the non-tiles of hell to be nil
    end

    local tileattrs = df.tiletype.attrs[dfhack.maps.getTileType(x, y, z)]
    local tileflags, tile_occupancy = dfhack.maps.getTileFlags(x, y, z)

    local tile_data = {}

    for map_option, position in pairs(options) do
        if(map_option == "tiletype") then
            tile_data[position] = tileattrs.material
        elseif(map_option == "shape") then
            tile_data[position] = tileattrs.shape
        elseif(map_option == "special") then
            tile_data[position] = tileattrs.special
        elseif(map_option == "variant") then
            tile_data[position] = tileattrs.variant
        elseif(map_option == "hidden") then
            tile_data[position] = tileflags.hidden
        elseif(map_option == "light") then
            tile_data[position] = tileflags.light
        elseif(map_option == "subterranean") then
            tile_data[position] = tileflags.subterranean
        elseif(map_option == "outside") then
            tile_data[position] = tileflags.outside
        elseif(map_option == "aquifer") then
            -- hardcoding these values bc they are not directly in a list
            if(tileflags.water_table and tile_occupancy.heavy_aquifer) then
                tile_data[position] = 2
            elseif(tileflags.water_table) then
                tile_data[position] = 1
            else
                tile_data[position] = 0
            end
        elseif(map_option == "material") then
            if(tileattrs.material >= 8 and tileattrs.material <= 11) then
                -- grass material IDs [8-11] will throw an error so we skip them
                tile_data[position] = nil
            else
                local material = tm.GetTileMat(x, y, z)
                tile_data[position] = material and material.index or nil
            end
        end
    end

    return tile_data
end

local function setup_keys(options)
    local KEYS = {}

    if(options.tiletype) then
        KEYS.TILETYPE = {}
        for id, material in ipairs(df.tiletype_material) do
            KEYS.TILETYPE[id] = material
        end
    end

    if(options.shape) then
        KEYS.SHAPE = {}
        for id, shape in ipairs(df.tiletype_shape) do
            KEYS.SHAPE[id] = shape
        end
    end

    if(options.special) then
        KEYS.SPECIAL = {}
        for id, special in ipairs(df.tiletype_special) do
            KEYS.SPECIAL[id] = special
        end
    end

    if(options.variant) then
        KEYS.VARIANT = {}
        for id, variant in ipairs(df.tiletype_variant) do
            KEYS.VARIANT[id] = variant
        end
    end

    if(options.aquifer) then
        -- We are hardcoding since this info is not easily listed anywhere
        KEYS.AQUIFER = {
            [0] = "NONE",
            [1] = "LIGHT",
            [2] = "HEAVY",
        }
    end

    if(options.material) then
        KEYS.MATERIAL = {}
        KEYS.MATERIAL.PLANT = {}
        for id, plant in ipairs(df.global.world.raws.plants.all) do
            KEYS.MATERIAL.PLANT[id] = plant.id
        end

        KEYS.MATERIAL.SOLID = {} -- everything but plants (stones, gems, metals)
        KEYS.MATERIAL.METAL = {}
        KEYS.MATERIAL.STONE = {}
        KEYS.MATERIAL.GEM = {}

        for id, rock in ipairs(df.global.world.raws.inorganics) do
            local material = rock.material
            local name = material.state_adj.Solid
            KEYS.MATERIAL.SOLID[id] = name
-- cant sort by key see
-- https://stackoverflow.com/questions/26160327/sorting-a-lua-table-by-key
            KEYS.MATERIAL.STONE[id] = material.flags.IS_STONE and name or false
            KEYS.MATERIAL.GEM[id] = material.flags.IS_GEM and name or false
            KEYS.MATERIAL.METAL[id] = material.flags.IS_METAL and name or false
        end
    end

    return KEYS
end

local function export_all_z_levels(fortress_name, folder, options)
    local xmax, ymax, zmax = dfhack.maps.getTileSize()
    local filename = string.format("%s/%s.json", folder, fortress_name)

    if dfhack.filesystem.exists(filename) then
        qerror('Destination file ' .. filename .. ' already exists!')
        return false
    end

    local data = {}

    data.ARGUMENT_OPTION_ORDER = options
    data.MAP_SIZE = {
        x = xmax,
        y = ymax,
        -- subtract underworld levels if excluded from options
        z = include_underworld_z and zmax or (zmax - underworld_z),
        underworld_z_level = include_underworld_z and underworld_z or nil,
        evilness = evilness or nil,
    }
    data.KEYS = setup_keys(options)

    data.map = {}

    local zmin = 0
    if not include_underworld_z then -- skips all z-levels in the underworld
        zmin = underworld_z
    end

    -- start from bottom z-level (underworld) to top z-level (sky)
    for z = 0, 1-1 do
        local level_data = {}
        for y = 0, ymax - 1 do
            local row_data = {}
            for x = 0, xmax - 1 do
                local classification = classify_tile(options, x, y, z)
                table.insert(row_data, classification)
            end
            table.insert(level_data, row_data)
        end
        table.insert(data.map, level_data)
    end

    local f = assert(io.open(filename, 'w'))
    f:write(json.encode(data))
    f:close()
    print("File created in Dwarf Fortress folder under " .. filename)
end


local function export_fortress_map(options)
    local fortress_name = dfhack.TranslateName(
        df.global.world.world_data.active_site[0].name
    )
    local export_path = "map-exports/" .. fortress_name
    dfhack.filesystem.mkdir_recursive(export_path)
    export_all_z_levels(fortress_name, export_path, options)
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

local options, args = {
    help = false,
    tiletype = false,
    shape = false,
    special = false,
    variant = false,
    hidden = false,
    light = false,
    subterranean = false,
    outside = false,
    aquifer = false,
    material = false,
}, {...}

local positionals = argparse.processArgsGetopt(args, {
    {'', 'help', handler=function() options.help = true end},
    {'t', 'tiletype', handler=function() options.tiletype = true end},
    {'s', 'shape', handler=function() options.shape = true end},
    {'p', 'special', handler=function() options.special = true end},
    {'v', 'variant', handler=function() options.variant = true end},
    {'h', 'hidden', handler=function() options.hidden = true end},
    {'l', 'light', handler=function() options.light = true end},
    {'b', 'subterranean', handler=function() options.subterranean = true end},
    {'o', 'outside', handler=function() options.outside = true end},
    {'a', 'aquifer', handler=function() options.aquifer = true end},
    {'m', 'material', handler=function() options.material = true end},
    -- local var since underworld not in ordered option
    {'u', 'underworld', handler=function() include_underworld_z = true end},
    {'e', 'evilness', handler=function() evilness = get_evilness() end},
})

if positionals[1] == "help" or options.help then
    print(dfhack.script_help())
    return false
elseif positionals[1] == "include" then
    -- no need to change anything
elseif positionals[1] == "exclude" then
    for setting in pairs(options) do
        options[setting] = not options[setting]
    end
else -- include everything
    for setting in pairs(options) do
        options[setting] = true
    end
    -- don't forget to include underworld
    include_underworld_z = true
end

local ordered_options = {
    "tiletype",
    "shape",
    "special",
    "variant",
    "hidden",
    "light",
    "subterranean",
    "outside",
    "aquifer",
    "material",
}

-- reorganize ordered options based on selected options via argparse
-- this is so ARGUMENT_OPTION_ORDER has the correct order with no gaps
for setting in pairs(options) do
    if not options[setting] then
        for pos, json_setting in ipairs(ordered_options) do
            if setting == json_setting then
                table.remove(ordered_options, pos)
            end
        end
    end
end

ordered_options = utils.invert(ordered_options)
export_fortress_map(ordered_options)
