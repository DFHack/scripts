-- Creates a pit to the Underworld under the target
-- Based on script by IndigoFenix, @ https://gist.github.com/IndigoFenix/8776696
local help = [====[

hfs-pit
=======
Creates a pit to the underworld at the cursor, taking three numbers as
arguments.  Usage:  ``hfs-pit <size> <walls> <stairs>``

The first argument is size of the (square) pit in all directions.  The second
is ``1`` to wall off the sides of the pit on all layers except the underworld,
or anything else to leave them open.  The third parameter is 1 to add stairs.
Stairs are buggy; they will not reveal the bottom until you dig somewhere,
but underworld creatures will path in.

Examples::

    hfs-pit 1 0 0
        A single-tile wide pit with no walls or stairs.
        This is the default if no numbers are given.

    hfs-pit 4 0 1
        A four-across pit with no stairs but adding walls.

    hfs-pit 2 1 0
        A two-across pit with stairs but no walls.

]====]

local guidm = require('gui.dwarfmode')
local args={...}

if args[1] == '?' or args[1] == 'help' then
    print(help)
    return
end

local pos = guidm.getCursorPos()
local size = tonumber(args[1])
if size == nil or size < 1 then size = 1 end

local wallOff = tonumber(args[2])
local stairs = tonumber(args[3])

--Get the layer of the underworld
local underworldLayer
for index, feature in ipairs(df.global.world.features.map_features) do
    if feature:getType() == df.feature_type.underworld_from_layer then
        underworldLayer = feature.layer --hint:df.feature_init_underworld_from_layerst
    end
end

if not pos then
    qerror("Select a location by placing the cursor")
end
local x = 0
local y = 0
for x=pos.x-size,pos.x+size,1 do
    for y=pos.y-size,pos.y+size,1 do
        local z=1
        local hitAir = false
        local hitCeiling = false
        while z <= pos.z do
            local block = dfhack.maps.ensureTileBlock(x,y,z)
            if block then
                local old_tt = block.tiletype[x%16][y%16]
                if not hitAir and old_tt ~= df.tiletype.FeatureWall and old_tt ~= df.tiletype.EeriePit then
                    hitAir = true
                end
                if hitAir then
                    if not hitCeiling then
                        if block.global_feature ~= underworldLayer or z > 10 then hitCeiling = true end
                        if stairs == 1 and x == pos.x and y == pos.y then
                            if old_tt == df.tiletype.OpenSpace or old_tt == df.tiletype.RampTop then
                                if z == pos.z then
                                    block.tiletype[x%16][y%16] = df.tiletype.StoneStairD
                                else
                                    block.tiletype[x%16][y%16] = df.tiletype.StoneStairUD
                                end
                            else
                                block.tiletype[x%16][y%16] = df.tiletype.StoneStairU
                            end
                        end
                    end
                    if hitCeiling then
                        local needsWall = block.designation[x%16][y%16].flow_size > 0 or wallOff == 1
                        if (x == pos.x-size or x == pos.x+size or y == pos.y-size or y == pos.y+size) and z==pos.z then
                            --Do nothing, this is the lip of the hole
                        elseif x == pos.x-size and y == pos.y-size then if needsWall then block.tiletype[x%16][y%16]=df.tiletype.StoneWallSmoothRD end
                            elseif x == pos.x-size and y == pos.y+size then if needsWall then block.tiletype[x%16][y%16]=df.tiletype.StoneWallSmoothRU end
                            elseif x == pos.x+size and y == pos.y+size then if needsWall then block.tiletype[x%16][y%16]=df.tiletype.StoneWallSmoothLU end
                            elseif x == pos.x+size and y == pos.y-size then if needsWall then block.tiletype[x%16][y%16]=df.tiletype.StoneWallSmoothLD end
                            elseif x == pos.x-size or x == pos.x+size then if needsWall then block.tiletype[x%16][y%16]=df.tiletype.StoneWallSmoothUD end
                            elseif y == pos.y-size or y == pos.y+size then if needsWall then block.tiletype[x%16][y%16]=df.tiletype.StoneWallSmoothLR end
                            elseif stairs == 1 and x == pos.x and y == pos.y then
                                if z == pos.z then block.tiletype[x%16][y%16]=df.tiletype.StoneStairD
                                else block.tiletype[x%16][y%16]=df.tiletype.StoneStairUD end
                            else block.tiletype[x%16][y%16]=df.tiletype.OpenSpace
                        end
                        block.designation[x%16][y%16].flow_size = 0
                        dfhack.maps.enableBlockUpdates(block)
                        block.designation[x%16][y%16].flow_forbid = false
                    end
                end
                block.designation[x%16][y%16].hidden = false
            end
            z = z+1
        end
    end
end
