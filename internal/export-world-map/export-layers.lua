--@ module = true
local util = reqscript('internal/export-world-map/util')

function writeOutput(out)
    local column_headers = "geo_index;type;material;top_height;bottom_height\n"
    out:write(column_headers)

    for _, geo_biome in ipairs(df.global.world.world_data.geo_biomes) do
        for _, layer in ipairs(geo_biome.layers) do
            out:write(('%s;%s;%s;%s;%s\n'):format(
                geo_biome.index,
                "LAYER",
                df.inorganic_raw.find(layer.mat_index).id,
                layer.top_height,
                layer.bottom_height
            ))
            for i = 0, #layer.vein_mat - 1 do
                local material = df.inorganic_raw[layer.vein_mat[i]]
                out:write(('%s;%s;%s;%s;%s\n'):format(
                    geo_biome.index,
                    df.inclusion_type[layer.vein_type[i]],
                    df.inorganic_raw.find(layer.vein_mat[i]).id,
                    layer.top_height,
                    layer.bottom_height
                ))
            end
        end
    end
end

--- export geological layers
function export(by_world, by_date)
    return function()
        local out = io.open(util.getOutputFolder(by_world, by_date).."layers.csv", 'w')
        writeOutput(out)
        out:close()
    end
end
