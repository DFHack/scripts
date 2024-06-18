if not dfhack.world.isAdventureMode() then
    qerror('This script must be used in adventure mode')
end

local unit = dfhack.world.getAdventurer()
if unit then
    if unit.flags1.inactive then
        unit.flags1.inactive = false
        unit.flags3.ghostly = true
    elseif unit.body.components.body_part_status[0].missing then
        unit.flags1.inactive = true
        unit.flags3.ghostly = false
    else
        unit.flags3.ghostly = not unit.flags3.ghostly
    end
end
