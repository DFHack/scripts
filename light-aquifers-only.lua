-- Changes heavy aquifers to light globally pre embark or locally post embark

local args = {...}

if args[1] == 'help' then
    print(dfhack.script_help())
    return
end

if not dfhack.isWorldLoaded() then
    qerror('This script requires a world to be loaded.')
end

if dfhack.isMapLoaded() then
    dfhack.run_command('aquifer', 'convert', 'light', '--all')
    return
end

-- pre-embark
for i = 0, df.global.world.world_data.world_width - 1 do
    for k = 0, df.global.world.world_data.world_height - 1 do
        local tile = df.global.world.world_data.region_map[i]:_displace(k)
        if tile.drainage % 20 == 7 then
            tile.drainage = tile.drainage + 1
        end
    end
end
