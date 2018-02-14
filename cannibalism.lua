--Allows consumption of sapient corpses.
--[====[

cannibalism
===========
Allows consumption of sapient corpses. Use from an adventurer's inventory screen
or an individual item's detail screen.

]====]

function unmark_inventory(inventory)
    for _, entry in ipairs(inventory) do
        entry.item.flags.dead_dwarf = false
    end
end

local scrn = dfhack.gui.getCurViewscreen()
if df.viewscreen_itemst:is_instance(scrn) then
    scrn.item.flags.dead_dwarf = false
elseif df.viewscreen_dungeon_monsterstatusst:is_instance(scrn) then
    unmark_inventory(scrn.inventory)
elseif df.global.ui_advmode.menu == df.ui_advmode_menu.Inventory then
    unmark_inventory(df.global.world.units.active[0].inventory)
else
    qerror('Unsupported context')
end
