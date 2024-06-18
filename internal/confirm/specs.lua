--@module = true

-- if adding a new spec, just run `confirm` to load it and make it live
--
-- remember to reload the overlay when adding/changing specs that have
-- intercept_frames defined

local json = require('json')

local CONFIG_FILE = 'dfhack-config/confirm.json'

-- populated by ConfirmSpec constructor below
REGISTRY = {}

ConfirmSpec = defclass(ConfirmSpec)
ConfirmSpec.ATTRS{
    id=DEFAULT_NIL,
    title='DFHack confirm',
    message='Are you sure?',
    intercept_keys={},
    intercept_frame=DEFAULT_NIL,
    debug_frame=false, -- set to true when debugging frame positioning
    context=DEFAULT_NIL,
    predicate=DEFAULT_NIL,
    on_propagate=DEFAULT_NIL, -- called if prompt is bypassed (Ok clicked or paused)
    pausable=false,
}

function ConfirmSpec:init()
    if not self.id then
        error('must set id to a unique string')
    end
    if type(self.intercept_keys) ~= 'table' then
        self.intercept_keys = {self.intercept_keys}
    end
    for _, key in ipairs(self.intercept_keys) do
        if key ~= '_MOUSE_L' and key ~= '_MOUSE_R' and not df.interface_key[key] then
            error('Invalid key: ' .. tostring(key))
        end
    end
    if not self.context then
        error('context must be set to a bounding focus string')
    end

    -- protect against copy-paste errors when defining new specs
    if REGISTRY[self.id] then
        error('id already registered: ' .. tostring(self.id))
    end

    -- auto-register
    REGISTRY[self.id] = self
end

local mi = df.global.game.main_interface
local plotinfo = df.global.plotinfo

local function trade_goods_any_selected(which)
    for _, sel in ipairs(mi.trade.goodflag[which]) do
        if sel == 1 then return true end
    end
end

local function trade_goods_all_selected(which)
    for _, sel in ipairs(mi.trade.goodflag[which]) do
        if sel ~= 1 then return false end
    end
    return true
end

local function trade_agreement_items_any_selected()
    local diplomacy = mi.diplomacy
    for _, tab in ipairs(diplomacy.environment.meeting.sell_requests.priority) do
        for _, priority in ipairs(tab) do
            if priority ~= 0 then
                return true
            end
        end
    end
end

local function has_caravans()
    for _, caravan in pairs(df.global.plotinfo.caravans) do
        if caravan.time_remaining > 0 then
            return true
        end
    end
end

local function get_num_uniforms()
    local site = dfhack.world.getCurrentSite() or {}
    for _, entity_site_link in ipairs(site.entity_links or {}) do
        local he = df.historical_entity.find(entity_site_link.entity_id)
        if he and he.type == df.historical_entity_type.SiteGovernment then
            return #he.uniforms
        end
    end
    return 0
end

ConfirmSpec{
    id='trade-cancel',
    title='Cancel trade',
    message='Are you sure you want leave this screen? Selected items will not be saved.',
    intercept_keys={'LEAVESCREEN', '_MOUSE_R'},
    context='dwarfmode/Trade',
    predicate=function() return trade_goods_any_selected(0) or trade_goods_any_selected(1) end,
}

ConfirmSpec{
    id='trade-mark-all-fort',
    title='Mark all fortress goods',
    message='Are you sure you want mark all fortress goods at the depot? Your current fortress goods selections will be lost.',
    intercept_keys='_MOUSE_L',
    intercept_frame={r=47, b=7, w=12, h=3},
    context='dwarfmode/Trade',
    predicate=function() return trade_goods_any_selected(1) and not trade_goods_all_selected(1) end,
    pausable=true,
}

ConfirmSpec{
    id='trade-unmark-all-fort',
    title='Unmark all fortress goods',
    message='Are you sure you want unmark all fortress goods at the depot? Your current fortress goods selections will be lost.',
    intercept_keys='_MOUSE_L',
    intercept_frame={r=30, b=7, w=14, h=3},
    context='dwarfmode/Trade',
    predicate=function() return trade_goods_any_selected(1) and not trade_goods_all_selected(1) end,
    pausable=true,
}

ConfirmSpec{
    id='trade-mark-all-merchant',
    title='Mark all merchant goods',
    message='Are you sure you want mark all merchant goods at the depot? Your current merchant goods selections will be lost.',
    intercept_keys='_MOUSE_L',
    intercept_frame={l=0, r=72, b=7, w=12, h=3},
    context='dwarfmode/Trade',
    predicate=function() return trade_goods_any_selected(0) and not trade_goods_all_selected(0) end,
    pausable=true,
}

ConfirmSpec{
    id='trade-unmark-all-merchant',
    title='Mark all merchant goods',
    message='Are you sure you want mark all merchant goods at the depot? Your current merchant goods selections will be lost.',
    intercept_keys='_MOUSE_L',
    intercept_frame={l=0, r=40, b=7, w=14, h=3},
    context='dwarfmode/Trade',
    predicate=function() return trade_goods_any_selected(0) and not trade_goods_all_selected(0) end,
    pausable=true,
}

ConfirmSpec{
    id='trade-confirm-trade',
    title='Confirm trade',
    message="Are you sure you want to trade the selected goods?",
    intercept_keys='_MOUSE_L',
    intercept_frame={l=0, r=23, b=4, w=11, h=3},
    context='dwarfmode/Trade',
    predicate=function() return trade_goods_any_selected(0) and trade_goods_any_selected(1) end,
    pausable=true,
}

ConfirmSpec{
    id='trade-seize',
    title='Seize merchant goods',
    message='Are you sure you want seize marked merchant goods? This will make the merchant unwilling to trade further and will damage relations with the merchant\'s civilization.',
    intercept_keys='_MOUSE_L',
    intercept_frame={l=0, r=73, b=4, w=11, h=3},
    context='dwarfmode/Trade',
    predicate=function() return mi.trade.mer.mood > 0 and trade_goods_any_selected(0) end,
    pausable=true,
}

ConfirmSpec{
    id='trade-offer',
    title='Offer fortress goods',
    message='Are you sure you want to offer these goods? You will receive no payment.',
    intercept_keys='_MOUSE_L',
    intercept_frame={l=40, r=5, b=4, w=19, h=3},
    context='dwarfmode/Trade',
    predicate=function() return trade_goods_any_selected(1) end,
    pausable=true,
}

ConfirmSpec{
    id='diplomacy-request',
    title='Cancel trade agreement',
    message='Are you sure you want to leave this screen? The trade agreement selection will not be saved until you hit the "Done" button at the bottom of the screen.',
    intercept_keys={'LEAVESCREEN', '_MOUSE_R'},
    context='dwarfmode/Diplomacy/Requests',
    predicate=trade_agreement_items_any_selected,
}

ConfirmSpec{
    id='haul-delete-route',
    title='Delete hauling route',
    message='Are you sure you want to delete this route?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Hauling',
    predicate=function() return mi.current_hover == df.main_hover_instruction.RouteRemove end,
    pausable=true,
}

ConfirmSpec{
    id='haul-delete-stop',
    title='Delete hauling stop',
    message='Are you sure you want to delete this stop?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Hauling',
    predicate=function() return mi.current_hover == df.main_hover_instruction.StopRemove end,
    pausable=true,
}

ConfirmSpec{
    id='depot-remove',
    title='Remove depot',
    message='Are you sure you want to remove this depot? Merchants are present and will lose profits.',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/ViewSheets/BUILDING/TradeDepot',
    predicate=function()
        return mi.current_hover == df.main_hover_instruction.BuildingRemove and has_caravans()
    end,
}

ConfirmSpec{
    id='squad-disband',
    title='Disband squad',
    message='Are you sure you want to disband this squad?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Squads',
    predicate=function() return mi.current_hover == df.main_hover_instruction.SquadDisband end,
    pausable=true,
}

ConfirmSpec{
    id='uniform-delete',
    title='Delete uniform',
    message='Are you sure you want to delete this uniform?',
    intercept_keys='_MOUSE_L',
    intercept_frame={r=131, t=23, w=6, h=27},
    context='dwarfmode/AssignUniform',
    predicate=function(_, mouse_offset)
        local num_uniforms = get_num_uniforms()
        if num_uniforms == 0 then return false end
        -- adjust detection area depending on presence of scrollbar
        if num_uniforms > 8 and mouse_offset.x > 2 then
            return false
        elseif num_uniforms <= 8 and mouse_offset.x <= 1 then
            return false
        end
        -- exclude the "No uniform" option (which has no delete button)
        return mouse_offset.y // 3 < num_uniforms - mi.assign_uniform.scroll_position
    end,
    pausable=true,
}

local se = mi.squad_equipment
local uniform_starting_state = nil

local function uniform_has_changes()
    for k, v in pairs(uniform_starting_state or {}) do
        if type(v) == table then
            if #v + 1 ~= #se[k] then return true end
            for k2, v2 in pairs(v) do
                if v2 ~= se[k][k2] then return true end
            end
        else
            if v ~= se[k] then return true end
        end
    end
    return false
end

local function ensure_uniform_record()
    if uniform_starting_state then return end
    uniform_starting_state = {
        cs_cat=copyall(se.cs_cat),
        cs_it_spec_item_id=copyall(se.cs_it_spec_item_id),
        cs_it_type=copyall(se.cs_it_type),
        cs_it_subtype=copyall(se.cs_it_subtype),
        cs_civ_mat=copyall(se.cs_civ_mat),
        cs_spec_mat=copyall(se.cs_spec_mat),
        cs_spec_matg=copyall(se.cs_spec_matg),
        cs_color_pattern_index=copyall(se.cs_color_pattern_index),
        cs_icp_flag=copyall(se.cs_icp_flag),
        cs_assigned_item_number=copyall(se.cs_assigned_item_number),
        cs_assigned_item_id=copyall(se.cs_assigned_item_id),
        cs_uniform_flag=se.cs_uniform_flag,
    }
end

local function clear_uniform_record()
    uniform_starting_state = nil
end

local function clicked_on_confirm_button(mouse_offset)
    -- buttons are all in the top 3 lines
    if mouse_offset.y > 2 then return false end
    -- clicking on the Confirm button saves the uniform and closes the panel
    if mouse_offset.x >= 38 and mouse_offset.x <= 46 then return true end
    -- the "Confirm and save uniform" button does the same thing, but it is
    -- only enabled if a name has been entered
    if #mi.squad_equipment.customizing_squad_uniform_nickname == 0 then
        return false
    end
    return mouse_offset.x >= 74 and mouse_offset.x <= 99
end

ConfirmSpec{
    id='uniform-discard-changes',
    title='Discard uniform changes',
    message='Are you sure you want to discard changes to this uniform?',
    intercept_keys={'_MOUSE_L', '_MOUSE_R'},
    -- sticks out the left side so it can move with the panel
    -- when the screen is resized too narrow
    intercept_frame={r=32, t=19, w=101, b=3},
    context='dwarfmode/SquadEquipment/Customizing/Default',
    predicate=function(keys, mouse_offset)
        if keys._MOUSE_R then
            return uniform_has_changes()
        end
        if clicked_on_confirm_button(mouse_offset) then
            print('confirm click detected')
            clear_uniform_record()
        else
            ensure_uniform_record()
        end
        return false
    end,
    on_propagate=clear_uniform_record,
}

local hotkey_reset_action = 'reset'
local num_hotkeys = 16
ConfirmSpec{
    id='hotkey-reset',
    title='Reassign or clear zoom hotkeys',
    message=function() return ('Are you sure you want to %s this zoom hotkey?'):format(hotkey_reset_action) end,
    intercept_keys='_MOUSE_L',
    intercept_frame={r=32, t=11, w=12, b=9},
    context='dwarfmode/Hotkey',
    predicate=function(_, mouse_offset)
        local _, sh = dfhack.screen.getWindowSize()
        local num_sections = (sh - 20) // 3
        local selected_section = mouse_offset.y // 3
        -- if this isn't a button section, exit early
        if selected_section % 2 ~= 0 then return false end
        -- if this hotkey isn't set, then all actions are ok
        local selected_offset = selected_section // 2
        local selected_idx = selected_offset + mi.hotkey.scroll_position
        local max_visible_buttons = num_sections // 2
        if selected_offset >= max_visible_buttons or
            selected_idx >= num_hotkeys or
            plotinfo.main.hotkeys[selected_idx].cmd == df.ui_hotkey.T_cmd.None
        then
            return false
        end
        -- adjust detection area depending on presence of scrollbar
        if max_visible_buttons < num_hotkeys then
            if mouse_offset.x > 7 then
                return false
            elseif mouse_offset.x <= 3 then
                hotkey_reset_action = 'reassign'
            else
                hotkey_reset_action = 'clear'
            end
        elseif max_visible_buttons >= num_hotkeys then
            if mouse_offset.x <= 1 then
                return false
            elseif mouse_offset.x <= 5 then
                hotkey_reset_action = 'reassign'
            else
                hotkey_reset_action = 'clear'
            end
        end
        return true
    end,
    pausable=true,
}

local selected_convict_name = 'this creature'
ConfirmSpec{
    id='convict',
    title='Confirm conviction',
    message=function()
        return ('Are you sure you want to convict %s? This action is irreversible.'):format(selected_convict_name)
    end,
    intercept_keys={'_MOUSE_L', 'SELECT'},
    context='dwarfmode/Info/JUSTICE/Convicting',
    predicate=function(keys)
        local convict = dfhack.gui.getWidget(mi.info.justice, 'Tabs', 'Open cases', 'Right panel', 'Convict')
        local scroll_rows = dfhack.gui.getWidget(convict, 'Unit List', 1)
        local selected_pos
        if keys.SELECT then
            selected_pos = convict.cursor_idx
        else
            local visible_rows = scroll_rows.num_visible
            if visible_rows == 0 then return false end
            local scroll_pos = scroll_rows.scroll
            local first_portrait_rect = dfhack.gui.getWidget(scroll_rows, scroll_pos, 0).rect
            local last_name_rect = dfhack.gui.getWidget(scroll_rows, scroll_pos+visible_rows-1, 1).rect
            local x, y = dfhack.screen.getMousePos()
            if x < first_portrait_rect.x1 or x > last_name_rect.x2 or
                y < first_portrait_rect.y1 or y >= first_portrait_rect.y1+3*visible_rows
            then
                return false
            end
            selected_pos = scroll_pos + (y - first_portrait_rect.y1) // 3
        end
        local unit = dfhack.gui.getWidget(scroll_rows, selected_pos, 0).u
        selected_convict_name = dfhack.TranslateName(dfhack.units.getVisibleName(unit))
        if selected_convict_name == '' then
            selected_convict_name = 'this creature'
        end
        return true
    end,
}

ConfirmSpec{
    id='order-remove',
    title='Remove manger order',
    message='Are you sure you want to remove this manager order?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Info/WORK_ORDERS/Default',
    predicate=function() return mi.current_hover == df.main_hover_instruction.ManagerOrderRemove end,
    pausable=true,
}

ConfirmSpec{
    id='zone-remove',
    title='Remove zone',
    message='Are you sure you want to remove this zone?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Zone', -- this is just Zone and not Zone/Some so we can pause across zones
    predicate=function() return dfhack.gui.matchFocusString('dwarfmode/Zone/Some') end,
    intercept_frame={l=40, t=8, w=4, h=3},
    pausable=true,
}

ConfirmSpec{
    id='burrow-remove',
    title='Remove burrow',
    message='Are you sure you want to remove this burrow?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Burrow',
    predicate=function()
        return mi.current_hover == df.main_hover_instruction.BurrowRemove or
            mi.current_hover == df.main_hover_instruction.BurrowRemovePaint
    end,
    pausable=true,
}

ConfirmSpec{
    id='stockpile-remove',
    title='Remove stockpile',
    message='Are you sure you want to remove this stockpile?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Stockpile',
    predicate=function() return mi.current_hover == df.main_hover_instruction.StockpileRemove end,
    pausable=true,
}

ConfirmSpec{
    id='embark-site-finder',
    title='Re-run finder',
    message='Are you sure you want to re-run the site finder? Your current map highlights will be lost.',
    intercept_keys='_MOUSE_L',
    intercept_frame={r=2, t=36, w=7, h=3},
    context='choose_start_site/SiteFinder',
    predicate=function()
        return dfhack.gui.getDFViewscreen(true).find_results ~= df.viewscreen_choose_start_sitest.T_find_results.None
    end,
    pausable=true,
}

--------------------------
-- Config file management
--

local function get_config()
    local f = json.open(CONFIG_FILE)
    local updated = false
    -- scrub any invalid data
    for id in pairs(f.data) do
        if not REGISTRY[id] then
            updated = true
            f.data[id] = nil
        end
    end
    -- add any missing confirmation ids
    for id in pairs(REGISTRY) do
        if not f.data[id] then
            updated = true
            f.data[id] = {
                id=id,
                enabled=true,
            }
        end
    end
    if updated then
        f:write()
    end
    return f
end

config = get_config()
