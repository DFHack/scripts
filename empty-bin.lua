-- Empty a bin onto the floor
-- Based on "emptybin" by StoneToad
-- https://gist.github.com/stonetoad/11129025
-- http://dwarffortresswiki.org/index.php/DF2014_Talk:Bin

local function moveItem(item, to_pos)
    print('  ' .. dfhack.items.getReadableDescription(item))
    dfhack.items.moveToGround(item, to_pos)
end

local function emptyContainer(container)
    local items = dfhack.items.getContainedItems(container)

    if #items > 0 then
        print('Emptying ' .. dfhack.items.getReadableDescription(container))
        local pos = xyz2pos(dfhack.items.getPosition(container))
        for _, item in ipairs(items) do
            moveItem(item, pos)
        end
    end
end

local viewsheets = df.global.game.main_interface.view_sheets

local stockpile = dfhack.gui.getSelectedStockpile(true)
local selectedItem = dfhack.gui.getSelectedItem(true)
local selectedBuilding = dfhack.gui.getSelectedBuilding(true)
if stockpile then
    local contents = dfhack.buildings.getStockpileContents(stockpile)
    for _, container in ipairs(contents) do
        emptyContainer(container)
    end
elseif selectedItem then
    emptyContainer(selectedItem)
elseif selectedBuilding then
    if not df.building_actual:is_instance(selectedBuilding) then return end
    for _, contained in ipairs(selectedBuilding.contained_items) do
        if contained.use_mode == df.building_item_role_type.TEMP then
            emptyContainer(contained.item)
        end
    end
elseif viewsheets.open then
    for _, item_id in ipairs(viewsheets.viewing_itid) do
        local item = df.item.find(item_id)
        emptyContainer(item)
    end
else
    qerror("Please select a container, building, stockpile, or tile with a list of items.")
end
