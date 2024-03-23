local argparse = require('argparse')

local zmin = 0
local zmax = df.global.world.map.z_count - 1
local aqtype = null

local function drain()
    local layers = {} --as:bool[]
    local layer_count = 0
    local tile_count = 0
    local aqTypeToDrain = 3
    if aqtype == "light" then
      aqTypeToDrain = 1
    elseif aqtype == "heavy" then
      aqTypeToDrain = 2
    elseif aqtype ~= nil then
      qerror("Invalid aquifer type "..aqtype)
    end
    
    for _, block in ipairs(df.global.world.map.map_blocks) do
        local aquiferInBlock = false

        if not block.flags.has_aquifer then goto continue end
        if block.map_pos.z < zmin or block.map_pos.z > zmax then goto continue end
        local oldTileCount = tile_count
        for i, row in ipairs(block.designation) do
            for j, tile in ipairs(row) do
                if (aqTypeToDrain == 3 or 
                  (block.occupancy[i][j].heavy_aquifer and aqTypeToDrain == 2) or
                  (not block.occupancy[i][j].heavy_aquifer and aqTypeToDrain == 1)) and  
                  tile.water_table then
                    tile.water_table = false
                    tile_count = tile_count + 1
                end
                if tile.water_table then
                  aquiferInBlock = true
                end
            end
        end

        if not layers[block.map_pos.z] then
            layers[block.map_pos.z] = true
            layer_count = layer_count + 1
        end

        if aquiferInBlock == false then
          block.flags.has_aquifer = false
          block.flags.check_aquifer = false
        end

        ::continue::
    end

    print(('Cleared %d aquifer tile%s in %d layer%s.'):format(
        tile_count, (tile_count ~= 1) and 's' or '', layer_count, (layer_count ~= 1) and 's' or ''))
end

local help = false
local top = 0

local positionals = argparse.processArgsGetopt({...}, {
    {'h', 'help', handler=function() help = true end},
    {'t', 'top', hasArg=true, handler=function(optarg) top = argparse.nonnegativeInt(optarg, 'top') end},
    {'d', 'zdown', handler=function() zmax = df.global.window_z end},
    {'u', 'zup', handler=function() zmin = df.global.window_z end},
    {'z', 'cur-zlevel', handler=function() zmax, zmin = df.global.window_z, df.global.window_z end},
    {'f', 'filter', hasArg=true, handler=function(fil) aqtype = string.lower(fil) end},
})

if help or positionals[1] == 'help' then
    print(dfhack.script_help())
    return
end

if top > 0 then
    zmax = -1
    for _, block in ipairs(df.global.world.map.map_blocks) do
        if block.flags.has_aquifer and zmax < block.map_pos.z then
            zmax = block.map_pos.z
        end
    end
    zmax = zmax - top
    if zmax < zmin then
        print('No aquifer levels need draining')
        return
    end
end

drain()
