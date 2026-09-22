--@ module = true
local util = reqscript('internal/export-world-map/util')

local plants_filename = "plant_pops.csv"
local creature_filename = "creature_pops.csv"
local vermin_filename = "vermin_pops.csv"
local column_headers = "region_id;population_type;raw_id;pop_count_min;pop_count_max\n"

function writeOutput(base_folder)
    local plants = io.open(base_folder..plants_filename, 'w')
    local creatures = io.open(base_folder..creature_filename, 'w')
    local vermin = io.open(base_folder..vermin_filename, 'w')

    plants:write(column_headers)
    creatures:write(column_headers)
    vermin:write(column_headers)

    for _, region in ipairs(df.global.world.world_data.regions) do
        for _, pop in ipairs(region.population) do
            local raw_id
            local out
            if
                pop.type == df.world_population_type.Tree or
                pop.type == df.world_population_type.Grass or
                pop.type == df.world_population_type.Bush
            then
                raw_id = df.plant_raw.find(pop.plant).id
                out = plants
            else
                raw_id = df.creature_raw.find(pop.plant).creature_id
                if
                    pop.type == df.world_population_type.Vermin or
                    pop.type == df.world_population_type.VerminInnumerable
                then
                    out = vermin
                else
                    out = creatures
                end
            end

            if out then
                out:write(('%s;%s;%s;%s;%s\n'):format(
                    region.index,
                    df.world_population_type[pop.type],
                    raw_id,
                    pop.count_min,
                    pop.count_max
                ))
            end
        end
    end

    plants:close()
    vermin:close()
    creatures:close()
end

--- export animal and plant populations
function export(by_world, by_date)
    return function()
        writeOutput(util.getOutputFolder(by_world, by_date))
    end
end
