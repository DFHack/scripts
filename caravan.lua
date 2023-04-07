-- Adjusts properties of caravans and provides overlay for enhanced trading
--@ module = true

-- TODO: the category checkbox that indicates whether all items in the category
-- are selected can be incorrect after the overlay adjusts the container
-- selection. the state is in trade.current_type_a_flag, but figuring out which
-- index to modify is non-trivial.

local gui = require('gui')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

trader_selected_state = trader_selected_state or {}
broker_selected_state = broker_selected_state or {}
handle_ctrl_click_on_render = handle_ctrl_click_on_render or false
handle_shift_click_on_render = handle_shift_click_on_render or false

dfhack.onStateChange.caravanTradeOverlay = function(code)
    if code == SC_WORLD_UNLOADED then
        trader_selected_state = {}
        broker_selected_state = {}
        handle_ctrl_click_on_render = false
        handle_shift_click_on_render = false
    end
end

local GOODFLAG = {
    UNCONTAINED_UNSELECTED = 0,
    UNCONTAINED_SELECTED = 1,
    CONTAINED_UNSELECTED = 2,
    CONTAINED_SELECTED = 3,
    CONTAINER_COLLAPSED_UNSELECTED = 4,
    CONTAINER_COLLAPSED_SELECTED = 5,
}

local trade = df.global.game.main_interface.trade

local MARGIN_HEIGHT = 26 -- screen height *other* than the list

function set_height(list_index, delta)
    trade.i_height[list_index] = trade.i_height[list_index] + delta
    if delta >= 0 then return end
    _,screen_height = dfhack.screen.getWindowSize()
    -- list only increments in three tiles at a time
    local page_height = ((screen_height - 26) // 3) * 3
    trade.scroll_position_item[list_index] = math.max(0,
            math.min(trade.scroll_position_item[list_index],
                     trade.i_height[list_index] - page_height))
end

function select_shift_clicked_container_items(new_state, old_state, list_index)
    -- if ctrl is also held, collapse the container too
    local also_collapse = dfhack.internal.getModifiers().ctrl
    local collapsed_item_count, collapsing_container, in_container = 0, false, false
    for k, goodflag in ipairs(new_state) do
        if in_container then
            if goodflag <= GOODFLAG.UNCONTAINED_SELECTED
                    or goodflag >= GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED then
                break
            end

            new_state[k] = GOODFLAG.CONTAINED_SELECTED

            if collapsing_container then
                collapsed_item_count = collapsed_item_count + 1
            end
            goto continue
        end

        if goodflag == old_state[k] then goto continue end
        local is_container = df.item_binst:is_instance(trade.good[list_index][k])
        if not is_container then goto continue end

        -- deselect the container itself
        if also_collapse or
                old_state[k] == GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED or
                old_state[k] == GOODFLAG.CONTAINER_COLLAPSED_SELECTED then
            collapsing_container = goodflag == GOODFLAG.UNCONTAINED_SELECTED
            new_state[k] = GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED
        else
            new_state[k] = GOODFLAG.UNCONTAINED_UNSELECTED
        end
        in_container = true

        ::continue::
    end

    if collapsed_item_count > 0 then
        set_height(list_index, collapsed_item_count * -3)
    end
end

local CTRL_CLICK_STATE_MAP = {
    [GOODFLAG.UNCONTAINED_UNSELECTED] = GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED,
    [GOODFLAG.UNCONTAINED_SELECTED] = GOODFLAG.CONTAINER_COLLAPSED_SELECTED,
    [GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED] = GOODFLAG.UNCONTAINED_UNSELECTED,
    [GOODFLAG.CONTAINER_COLLAPSED_SELECTED] = GOODFLAG.UNCONTAINED_SELECTED,
}

-- collapses uncollapsed containers and restores the selection state for the container
-- and contained items
function toggle_ctrl_clicked_containers(new_state, old_state, list_index)
    local toggled_item_count, in_container, is_collapsing = 0, false, false
    for k, goodflag in ipairs(new_state) do
        if in_container then
            if goodflag <= GOODFLAG.UNCONTAINED_SELECTED
                    or goodflag >= GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED then
                break
            end
            toggled_item_count = toggled_item_count + 1
            new_state[k] = old_state[k]
            goto continue
        end

        if goodflag == old_state[k] then goto continue end
        local is_contained = goodflag == GOODFLAG.CONTAINED_UNSELECTED or goodflag == GOODFLAG.CONTAINED_SELECTED
        if is_contained then goto continue end
        local is_container = df.item_binst:is_instance(trade.good[list_index][k])
        if not is_container then goto continue end

        new_state[k] = CTRL_CLICK_STATE_MAP[old_state[k]]
        in_container = true
        is_collapsing = goodflag == GOODFLAG.UNCONTAINED_UNSELECTED or goodflag == GOODFLAG.UNCONTAINED_SELECTED

        ::continue::
    end

    if toggled_item_count > 0 then
        set_height(list_index, toggled_item_count * 3 * (is_collapsing and -1 or 1))
    end
end

function collapseTypes(types_list, list_index)
    local type_on_count = 0

    for k in ipairs(types_list) do
        local type_on = trade.current_type_a_on[list_index][k]
        if type_on then
            type_on_count = type_on_count + 1
        end
        types_list[k] = false
    end

    trade.i_height[list_index] = type_on_count * 3
    trade.scroll_position_item[list_index] = 0
end

function collapseAllTypes()
   collapseTypes(trade.current_type_a_expanded[0], 0)
   collapseTypes(trade.current_type_a_expanded[1], 1)
end

function collapseContainers(item_list, list_index)
    local num_items_collapsed = 0
    for k, goodflag in ipairs(item_list) do
        if goodflag == GOODFLAG.CONTAINED_UNSELECTED
                or goodflag == GOODFLAG.CONTAINED_SELECTED then
            goto continue
        end

        local item = trade.good[list_index][k]
        local is_container = df.item_binst:is_instance(item)
        if not is_container then goto continue end

        local collapsed_this_container = false
        if goodflag == GOODFLAG.UNCONTAINED_SELECTED then
            item_list[k] = GOODFLAG.CONTAINER_COLLAPSED_SELECTED
            collapsed_this_container = true
        elseif goodflag == GOODFLAG.UNCONTAINED_UNSELECTED then
            item_list[k] = GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED
            collapsed_this_container = true
        end

        if collapsed_this_container then
            num_items_collapsed = num_items_collapsed + #dfhack.items.getContainedItems(item)
        end
        ::continue::
    end

    if num_items_collapsed > 0 then
        set_height(list_index, num_items_collapsed * -3)
    end
end

function collapseAllContainers()
    collapseContainers(trade.goodflag[0], 0)
    collapseContainers(trade.goodflag[1], 1)
end

function collapseEverything()
    collapseAllContainers()
    collapseAllTypes()
end

function copyGoodflagState()
    trader_selected_state = copyall(trade.goodflag[0])
    broker_selected_state = copyall(trade.goodflag[1])
end

CaravanTradeOverlay = defclass(CaravanTradeOverlay, overlay.OverlayWidget)
CaravanTradeOverlay.ATTRS{
    default_pos={x=-3,y=-12},
    default_enabled=true,
    viewscreens='dwarfmode/Trade',
    frame={w=27, h=13},
    frame_style=gui.MEDIUM_FRAME,
    frame_background=gui.CLEAR_PEN,
}

function CaravanTradeOverlay:init()
    self:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text={
                {text='Shift+Click checkbox', pen=COLOR_LIGHTGREEN}, ':',
                NEWLINE,
                '  select items inside bin',
            },
        },
        widgets.Label{
            frame={t=3, l=0},
            text={
                {text='Ctrl+Click checkbox', pen=COLOR_LIGHTGREEN}, ':',
                NEWLINE,
                '  collapse/expand bin',
            },
        },
        widgets.HotkeyLabel{
            frame={t=6, l=0},
            label='collapse bins',
            key='CUSTOM_CTRL_C',
            on_activate=collapseAllContainers,
        },
        widgets.HotkeyLabel{
            frame={t=7, l=0},
            label='collapse all',
            key='CUSTOM_CTRL_X',
            on_activate=collapseEverything,
        },
        widgets.Label{
            frame={t=9, l=0},
            text = 'Shift+Scroll',
            text_pen=COLOR_LIGHTGREEN,
        },
        widgets.Label{
            frame={t=9, l=12},
            text = ': fast scroll',
        },
    }
end

-- do our alterations *after* the vanilla response to the click has registered. otherwise
-- it's very difficult to figure out which item has been clicked
function CaravanTradeOverlay:onRenderBody(dc)
    if handle_shift_click_on_render then
        handle_shift_click_on_render = false
        select_shift_clicked_container_items(trade.goodflag[0], trader_selected_state, 0)
        select_shift_clicked_container_items(trade.goodflag[1], broker_selected_state, 1)
    elseif handle_ctrl_click_on_render then
        handle_ctrl_click_on_render = false
        toggle_ctrl_clicked_containers(trade.goodflag[0], trader_selected_state, 0)
        toggle_ctrl_clicked_containers(trade.goodflag[1], broker_selected_state, 1)
    end
end

function CaravanTradeOverlay:onInput(keys)
    if CaravanTradeOverlay.super.onInput(self, keys) then return true end

    if keys._MOUSE_L_DOWN then
        if dfhack.internal.getModifiers().shift then
            handle_shift_click_on_render = true
            copyGoodflagState()
        elseif dfhack.internal.getModifiers().ctrl then
            handle_ctrl_click_on_render = true
            copyGoodflagState()
        end
    end
end

OVERLAY_WIDGETS = {
    tradeScreenExtension=CaravanTradeOverlay,
}

INTERESTING_FLAGS = {
    casualty = 'Casualty',
    hardship = 'Encountered hardship',
    seized = 'Goods seized',
    offended = 'Offended'
}
local caravans = df.global.plotinfo.caravans

local function caravans_from_ids(ids)
    if not ids or #ids == 0 then
        return caravans
    end

    local c = {} --as:df.caravan_state[]
    for _,id in ipairs(ids) do
        id = tonumber(id)
        if id then
            c[id] = caravans[id]
        end
    end
    return c
end

function bring_back(car)
    if car.trade_state ~= df.caravan_state.T_trade_state.AtDepot then
        car.trade_state = df.caravan_state.T_trade_state.Approaching
    end
end

local commands = {}

function commands.list()
    for id, car in pairs(caravans) do
        print(dfhack.df2console(('%d: %s caravan from %s'):format(
            id,
            df.creature_raw.find(df.historical_entity.find(car.entity).race).name[2], -- adjective
            dfhack.TranslateName(df.historical_entity.find(car.entity).name)
        )))
        print('  ' .. (df.caravan_state.T_trade_state[car.trade_state] or ('Unknown state: ' .. car.trade_state)))
        print(('  %d day(s) remaining'):format(math.floor(car.time_remaining / 120)))
        for flag, msg in pairs(INTERESTING_FLAGS) do
            if car.flags[flag] then
                print('  ' .. msg)
            end
        end
    end
end

function commands.extend(days, ...)
    days = tonumber(days or 7) or qerror('invalid number of days: ' .. days) --luacheck: retype
    for id, car in pairs(caravans_from_ids{...}) do
        car.time_remaining = car.time_remaining + (days * 120)
        bring_back(car)
    end
end

function commands.happy(...)
    for id, car in pairs(caravans_from_ids{...}) do
        -- all flags default to false
        car.flags.whole = 0
        bring_back(car)
    end
end

function commands.leave(...)
    for id, car in pairs(caravans_from_ids{...}) do
        car.trade_state = df.caravan_state.T_trade_state.Leaving
    end
end

local function isDisconnectedPackAnimal(unit)
    if unit.following then
        local dragger = unit.following
        return (
            unit.relationship_ids[ df.unit_relationship_type.Dragger ] == -1 and
            dragger.relationship_ids[ df.unit_relationship_type.Draggee ] == -1
        )
    end
end

local function getPrintableUnitName(unit)
    local visible_name = dfhack.units.getVisibleName(unit)
    local profession_name = dfhack.units.getProfessionName(unit)
    if visible_name.has_name then
        return ('%s (%s)'):format(dfhack.TranslateName(visible_name), profession_name)
    end
    return profession_name  -- for unnamed animals
end

local function rejoin_pack_animals()
    print('Reconnecting disconnected pack animals...')
    local found = false
    for _, unit in pairs(df.global.world.units.active) do
        if unit.flags1.merchant and isDisconnectedPackAnimal(unit) then
            local dragger = unit.following
            print(('  %s  <->  %s'):format(
                dfhack.df2console(getPrintableUnitName(unit)),
                dfhack.df2console(getPrintableUnitName(dragger))
            ))
            unit.relationship_ids[ df.unit_relationship_type.Dragger ] = dragger.id
            dragger.relationship_ids[ df.unit_relationship_type.Draggee ] = unit.id
            found = true
        end
    end
    if (found) then
        print('All pack animals reconnected.')
    else
        print('No disconnected pack animals found.')
    end
end

function commands.unload()
    rejoin_pack_animals()
end

function commands.help()
    print(dfhack.script_help())
end

function main(args)
    local command = table.remove(args, 1) or 'list'
    if commands[command] then
        commands[command](table.unpack(args))
    else
        commands.help()
        print()
        qerror("No such command: " .. command)
    end
end

if not dfhack_flags.module then
    main{...}
end
