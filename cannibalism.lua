--Need to get rid of a body? Hope you're hungry, because you can eat the whole thing with this.
local scrn=dfhack.gui.getCurViewscreen()
local meat
if df.viewscreen_itemst:is_instance(scrn) then
    meat=scrn.item
    meat.flags.dead_dwarf=false
elseif df.viewscreen_dungeon_monsterstatusst:is_instance(scrn) then
    meat=scrn.inventory
    for k,v in ipairs(meat) do
        meat[k].item.flags.dead_dwarf=false
    end
elseif df.global.ui_advmode.menu==5 then
    meat=df.global.world.units.active[0].inventory
    for k,v in ipairs(meat) do
        meat[k].item.flags.dead_dwarf=false
    end
end
