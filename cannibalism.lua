function unmark_inventory(inventory)
    for _, entry in ipairs(inventory) do
        entry.item.flags.dead_dwarf = false
    end
end

local scrn = dfhack.gui.getCurViewscreen()
if df.viewscreen_itemst:is_instance(scrn) then
    scrn.item.flags.dead_dwarf = false --hint:df.viewscreen_itemst
elseif df.viewscreen_dungeon_monsterstatusst:is_instance(scrn) then
    unmark_inventory(scrn.inventory) --hint:df.viewscreen_dungeon_monsterstatusst
elseif df.global.adventure.menu == df.ui_advmode_menu.Inventory then
    unmark_inventory(dfhack.world.getAdventurer().inventory)
else
    qerror('Unsupported context')
end
