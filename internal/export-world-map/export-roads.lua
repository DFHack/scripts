--@ module = true
local json = require('json')
local util = reqscript('internal/export-world-map/util')

local function getConstructionAndGeometryType(construction)
    if df.world_construction_roadst:is_instance(construction) then
        local subtype = ""
        if df.item_type[construction.square_obj[0]["item_type"]] == "BLOCKS" then
            subtype = "paved"
        else
            subtype = "dirt"
        end
        return "road", "LineString", subtype
    elseif df.world_construction_bridgest:is_instance(construction) then
        return "bridge", "Point", ""
    elseif df.world_construction_tunnelst:is_instance(construction) then
        return "tunnel", "LineString", ""
    else
        qerror("unknown construction type")
    end
end

local function gatherFeatures()
    local features = {}
    for _, construction in ipairs(df.global.world.world_data.constructions.list) do
        local type, geometry_type, subtype = getConstructionAndGeometryType(construction)

        local coordinates
        if geometry_type == "Point" then
            -- only world tile - not sure where to get region tile coordinates from
            -- perhaps it gets them from neighbouring roads?
            coordinates = {
                construction.square_pos["x"][0]*768,
                -(construction.square_pos["y"][0]*768)
            }
        else
            coordinates = {}
            for _,square_obj in ipairs(construction.square_obj) do
                for i=0,#square_obj.embark_x-1 do
                    table.insert(coordinates, {
                        square_obj.region_pos["x"]*768+square_obj.embark_x[i]*48+24,
                        -(square_obj.region_pos["y"]*768+square_obj.embark_y[i]*48+24)
                    })
                end
            end
        end

        table.insert(features, {
            type = "Feature",
            properties = {
                id = construction.id,
                name_df = dfhack.df2utf(dfhack.translation.translateName(construction["name"],false)),
                name_en = dfhack.df2utf(dfhack.translation.translateName(construction["name"],true)),
                construction_type = type,
                construction_subtype = subtype,
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
            util.getOutputFolder(by_world, by_date).."roads.geojson"
        )
    end
end
