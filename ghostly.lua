--Turn ghost on or off
--[====[

ghostly
=====
Toggles being a ghost for walking through walls, avoiding attacks, or recovering after a death.
    
]====]
local unit = df.global.world.units.active[0]
if unit then
    if unit.flags1.dead then
        unit.flags1.dead = false
        unit.flags3.ghostly = true
    elseif unit.body.components.body_part_status[0].missing then
        unit.flags1.dead = true
        unit.flags3.ghostly = false
    else
        unit.flags3.ghostly = not unit.flags3.ghostly
    end
end
