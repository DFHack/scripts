config = {
    mode = 'fortress',
}

local t = reqscript('teleport')

function test.teleport()
    local unit = df.global.world.units.active[0]
    local newpos = {x=unit.pos.x+1, y=unit.pos.y+1, z=unit.pos.z}
    t.teleport(unit, newpos)
    expect.table_eq(newpos, unit.pos)
end
