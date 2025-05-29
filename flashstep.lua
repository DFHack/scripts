local function reveal_tile(pos)
    local block = dfhack.maps.getTileBlock(pos)
    local des = block.designation[pos.x%16][pos.y%16]
    des.hidden = false
    des.pile = true  -- reveal the tile on the map
end

local function flashstep()
    local unit = dfhack.world.getAdventurer()
    if not unit then return end
    local pos = dfhack.gui.getMousePos()
    if not pos then return end
    if dfhack.units.teleport(unit, pos) then
        reveal_tile(xyz2pos(pos.x-1, pos.y-1, pos.z))
        reveal_tile(xyz2pos(pos.x,   pos.y-1, pos.z))
        reveal_tile(xyz2pos(pos.x+1, pos.y-1, pos.z))
        reveal_tile(xyz2pos(pos.x-1, pos.y,   pos.z))
        reveal_tile(pos)
        reveal_tile(xyz2pos(pos.x+1, pos.y,   pos.z))
        reveal_tile(xyz2pos(pos.x-1, pos.y+1, pos.z))
        reveal_tile(xyz2pos(pos.x,   pos.y+1, pos.z))
        reveal_tile(xyz2pos(pos.x+1, pos.y+1, pos.z))
    end
end

flashstep()
