--@ module = true
local json = require('json')
local util = reqscript('internal/export-world-map/util')

local constructions = df.global.world.world_data.constructions

local function getConstructionAndGeometryType(construction, bridge_squares_by_id)
    if construction:getType() == df.world_construction_type.ROAD then
        local square = construction.square_obj[0] -- df populates square_obj for roads and tunnels (only)
        local subtype = ""
        local material = ""

        if df.item_type[square.item_type] == "BLOCKS" then
            subtype = "paved"
            material = dfhack.matinfo.decode(square):toString()
        elseif df.item_type[square.item_type] == "NONE" then
            subtype = "dirt"
        end

        return "road", "LineString", subtype, material
    elseif construction:getType() == df.world_construction_type.BRIDGE then
        local square = bridge_squares_by_id[construction.id] -- df does NOT populate square_obj for bridges
        local subtype = ""
        local material = ""

        if df.item_type[square.item_type] == "WOOD" then
            subtype = "wooden"
            material = dfhack.matinfo.decode(square):toString()
        elseif df.item_type[square.item_type] == "BLOCKS" then
            subtype = "stone"
            material = dfhack.matinfo.decode(square):toString()
        end

        return "bridge", "Point", subtype, material
    elseif construction:getType() == df.world_construction_type.TUNNEL then
        -- df assigns world construction squares to tunnels like it does to roads,
        -- but tunnel squares have nothing besides positional data: no material info, no nothing.
        return "tunnel", "LineString", "", ""
    else
        qerror("unknown construction type")
    end
end

local function listBridgeSquaresById()
    local squares = {}

    local tile_array_width = constructions.width
    local tile_array_height = constructions.height

    for i = 0, (tile_array_width - 1) do
        for j = 0, (tile_array_height - 1) do
            for _, square in ipairs(constructions.map[i]:_displace(j).square) do
                if df.world_construction_square_bridgest:is_instance(square) then
                    squares[square.construction_id] = square
                end
            end
        end
    end

    return squares
end

local function gatherFeatures()
    local features = {}

    local bridge_squares_by_id = listBridgeSquaresById()

    for _, construction in ipairs(constructions.list) do
        local type, geometry_type, subtype, material = getConstructionAndGeometryType(construction, bridge_squares_by_id)

        local coordinates
        if geometry_type == "Point" then
            -- dwarf fortress doesn't populate square_obj for bridges, only for roads and tunnels.
            -- but all world tiles are listed in df.global.world.world_data.constructions.map (not list),
            -- a 2D array that has to be iterated over with _displace()
            local region_x = construction.square_pos.y[0]
            local region_y = construction.square_pos.y[0]
            local midmap_x = bridge_squares_by_id[construction.id].embark_x[0]
            local midmap_y = bridge_squares_by_id[construction.id].embark_y[0]

            coordinates = {
                region_x * 768 + midmap_x * 48 + 24,
                -(region_y * 768 + midmap_y * 48 + 24)
            }
        else
            coordinates = {}
            for _, square_obj in ipairs(construction.square_obj) do
                for i = 0, #square_obj.embark_x - 1 do
                    table.insert(coordinates, {
                        square_obj.region_pos.x * 768 + square_obj.embark_x[i] * 48 + 24,
                        -(square_obj.region_pos.y * 768 + square_obj.embark_y[i] * 48 + 24)
                    })
                end
            end
        end

        table.insert(features, {
            type = "Feature",
            properties = {
                id = construction.id,
                name_df = dfhack.df2utf(dfhack.translation.translateName(construction.name, false)),
                name_en = dfhack.df2utf(dfhack.translation.translateName(construction.name, true)),
                construction_type = type,
                construction_subtype = subtype,
                construction_material = material,
            },
            geometry = {
                type = geometry_type,
                coordinates = coordinates
            }
        })
    end
    return features
end

-- export roads as GeoJson
function export(by_world, by_date)
    return function()
        json.encode_file(
            { type = "FeatureCollection", features = gatherFeatures() },
            util.getOutputFolder(by_world, by_date) .. "roads.geojson"
        )
    end
end
