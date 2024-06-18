--Lights things on fire: items, locations, entire inventories even!

local guidm = require('gui.dwarfmode')

if dfhack.gui.getSelectedItem(true) then
    dfhack.gui.getSelectedItem(true).flags.on_fire = true
elseif dfhack.gui.getSelectedUnit(true) then
    for _, entry in ipairs(dfhack.gui.getSelectedUnit(true).inventory) do
        entry.item.flags.on_fire = true
    end
elseif guidm.getCursorPos() then
    df.global.world.event.fires:insert('#', {
        new=df.fire,
        timer=1000,
        pos=guidm.getCursorPos(),
        inner_temp_cur=60000,
        outer_temp_cur=60000,
        inner_temp_max=60000,
        outer_temp_max=60000,
    })
end
