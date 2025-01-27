--@ module = true

local common = reqscript('internal/caravan/common')
local gui = require('gui')
local overlay = require('plugins.overlay')
local predicates = reqscript('internal/caravan/predicates')
local utils = require('utils')
local widgets = require('gui.widgets')

-- -------------------
-- MoveGoods
--

MoveGoods = defclass(MoveGoods, widgets.Window)
MoveGoods.ATTRS {
    frame_title='Move goods to/from depot',
    frame={w=86, h=46},
    resizable=true,
    resize_min={h=40},
    frame_inset={l=0, t=1, b=1, r=0},
    pending_item_ids=DEFAULT_NIL,
    depot=DEFAULT_NIL,
}

local DIST_COL_WIDTH = 7
local VALUE_COL_WIDTH = 9
local QTY_COL_WIDTH = 5

local function sort_noop(a, b)
    -- this function is used as a marker and never actually gets called
    error('sort_noop should not be called')
end

local function sort_base(a, b)
    return a.data.desc < b.data.desc
end

local function sort_by_name_desc(a, b)
    if a.search_key == b.search_key then
        return sort_base(a, b)
    end
    return a.search_key < b.search_key
end

local function sort_by_name_asc(a, b)
    if a.search_key == b.search_key then
        return sort_base(a, b)
    end
    return a.search_key > b.search_key
end

local function sort_by_value_desc(a, b)
    local value_field = a.item_id and 'per_item_value' or 'total_value'
    if a.data[value_field] == b.data[value_field] then
        return sort_by_name_desc(a, b)
    end
    return a.data[value_field] > b.data[value_field]
end

local function sort_by_value_asc(a, b)
    local value_field = a.item_id and 'per_item_value' or 'total_value'
    if a.data[value_field] == b.data[value_field] then
        return sort_by_name_desc(a, b)
    end
    return a.data[value_field] < b.data[value_field]
end

local function sort_by_dist_desc(a, b)
    local a_unselected = a.data.selected == 0 or (a.item_id and not a.data.items[a.item_id].pending)
    local b_unselected = b.data.selected == 0 or (b.item_id and not b.data.items[b.item_id].pending)
    if a_unselected == b_unselected then
        local a_at_depot = a.data.num_at_depot == a.data.quantity
        local b_at_depot = b.data.num_at_depot == b.data.quantity
        if a_at_depot ~= b_at_depot then
            return a_at_depot
        end
        if a.data.dist == b.data.dist then
            return sort_by_value_desc(a, b)
        end
        return a.data.dist < b.data.dist
    end
    return not a_unselected
end

local function sort_by_dist_asc(a, b)
    local a_unselected = a.data.selected == 0 or (a.item_id and not a.data.items[a.item_id].pending)
    local b_unselected = b.data.selected == 0 or (b.item_id and not b.data.items[b.item_id].pending)
    if a_unselected == b_unselected then
        local a_at_depot = a.data.num_at_depot == a.data.quantity
        local b_at_depot = b.data.num_at_depot == b.data.quantity
        if a_at_depot ~= b_at_depot then
            return b_at_depot
        end
        if a.data.dist == b.data.dist then
            return sort_by_value_desc(a, b)
        end
        return a.data.dist > b.data.dist
    end
    return not b_unselected
end

local function sort_by_quantity_desc(a, b)
    if a.data.quantity == b.data.quantity then
        return sort_by_value_desc(a, b)
    end
    return a.data.quantity > b.data.quantity
end

local function sort_by_quantity_asc(a, b)
    if a.data.quantity == b.data.quantity then
        return sort_by_value_desc(a, b)
    end
    return a.data.quantity < b.data.quantity
end

local function is_active_caravan(caravan)
    if caravan.flags.tribute then return false end
    local trade_state = caravan.trade_state
    return caravan.time_remaining > 0 and
        (trade_state == df.caravan_state.T_trade_state.Approaching or
         trade_state == df.caravan_state.T_trade_state.AtDepot)
end

local function get_ethics_restrictions()
    local animal_ethics, wood_ethics = false, false
    for _,caravan in ipairs(df.global.plotinfo.caravans) do
        if is_active_caravan(caravan) then
            animal_ethics = animal_ethics or common.is_animal_lover_caravan(caravan)
            wood_ethics = wood_ethics or common.is_tree_lover_caravan(caravan)
        end
    end
    return animal_ethics, wood_ethics
end

local function get_export_agreements()
    local export_agreements = {}
    for _,caravan in ipairs(df.global.plotinfo.caravans) do
        if caravan.buy_prices and is_active_caravan(caravan) then
            table.insert(export_agreements, caravan.buy_prices)
        end
    end
    return export_agreements
end

function MoveGoods:init()
    self.value_pending = 0

    self.animal_ethics, self.wood_ethics = get_ethics_restrictions()
    self.banned_items = common.get_banned_items()
    self.risky_items = common.get_risky_items(self.banned_items)
    self.choices_cache = {}

    self.predicate_context = {name='movegoods'}

    self:addviews{
        widgets.CycleHotkeyLabel{
            view_id='sort',
            frame={l=1, t=0, w=21},
            label='Sort by:',
            key='CUSTOM_SHIFT_S',
            options={
                {label='dist'..common.CH_DN, value=sort_by_dist_desc},
                {label='dist'..common.CH_UP, value=sort_by_dist_asc},
                {label='value'..common.CH_DN, value=sort_by_value_desc},
                {label='value'..common.CH_UP, value=sort_by_value_asc},
                {label='qty'..common.CH_DN, value=sort_by_quantity_desc},
                {label='qty'..common.CH_UP, value=sort_by_quantity_asc},
                {label='name'..common.CH_DN, value=sort_by_name_desc},
                {label='name'..common.CH_UP, value=sort_by_name_asc},
            },
            initial_option=sort_by_dist_desc,
            on_change=self:callback('refresh_list', 'sort'),
        },
        widgets.EditField{
            view_id='search',
            frame={l=27, t=0, r=1},
            label_text='Search: ',
            on_char=function(ch) return ch:match('[%l -]') end,
        },
        widgets.Panel{
            frame={t=2, l=0, r=0, h=18},
            frame_style=gui.FRAME_INTERIOR,
            subviews={
                widgets.Panel{
                    frame={t=0, l=0, w=38},
                    subviews=common.get_slider_widgets(self),
                },
                widgets.ToggleHotkeyLabel{
                    view_id='hide_forbidden',
                    frame={t=0, l=40, w=28},
                    label='Hide forbidden items:',
                    key='CUSTOM_SHIFT_F',
                    options={
                        {label='Yes', value=true, pen=COLOR_GREEN},
                        {label='No', value=false}
                    },
                   initial_option=false,
                    on_change=function() self:refresh_list() end,
                },
                widgets.Panel{
                    frame={t=1, l=40, r=0},
                    subviews=common.get_info_widgets(self, get_export_agreements(), false, self.predicate_context),
                },
            },
        },
        widgets.Panel{
            frame={t=21, l=0, r=0, b=7},
            subviews={
                widgets.CycleHotkeyLabel{
                    view_id='sort_dist',
                    frame={t=0, l=DIST_COL_WIDTH+1-7, w=7},
                    options={
                        {label='dist', value=sort_noop},
                        {label='dist'..common.CH_DN, value=sort_by_dist_desc},
                        {label='dist'..common.CH_UP, value=sort_by_dist_asc},
                    },
                    initial_option=sort_by_dist_desc,
                    option_gap=0,
                    on_change=self:callback('refresh_list', 'sort_dist'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_value',
                    frame={t=0, l=DIST_COL_WIDTH+2+VALUE_COL_WIDTH+1-6, w=6},
                    options={
                        {label='value', value=sort_noop},
                        {label='value'..common.CH_DN, value=sort_by_value_desc},
                        {label='value'..common.CH_UP, value=sort_by_value_asc},
                    },
                    option_gap=0,
                    on_change=self:callback('refresh_list', 'sort_value'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_quantity',
                    frame={t=0, l=DIST_COL_WIDTH+2+VALUE_COL_WIDTH+2+QTY_COL_WIDTH+1-4, w=4},
                    options={
                        {label='qty', value=sort_noop},
                        {label='qty'..common.CH_DN, value=sort_by_quantity_desc},
                        {label='qty'..common.CH_UP, value=sort_by_quantity_asc},
                    },
                    option_gap=0,
                    on_change=self:callback('refresh_list', 'sort_quantity'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_name',
                    frame={t=0, l=DIST_COL_WIDTH+2+VALUE_COL_WIDTH+2+QTY_COL_WIDTH+2, w=5},
                    options={
                        {label='name', value=sort_noop},
                        {label='name'..common.CH_DN, value=sort_by_name_desc},
                        {label='name'..common.CH_UP, value=sort_by_name_asc},
                    },
                    option_gap=0,
                    on_change=self:callback('refresh_list', 'sort_name'),
                },
                widgets.FilteredList{
                    view_id='list',
                    frame={l=0, t=2, r=0, b=0},
                    icon_width=2,
                    on_submit=self:callback('toggle_item'),
                    on_submit2=self:callback('toggle_range'),
                    on_select=self:callback('select_item'),
                },
            }
        },
        widgets.Divider{
            frame={b=6, h=1},
            frame_style=gui.FRAME_INTERIOR,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.Panel{
            frame={l=1, r=1, b=0, h=5},
            subviews={
                widgets.Label{
                    frame={l=0, t=0},
                    text={
                        'Total value of items marked for trade:',
                        {gap=1,
                         text=function() return common.obfuscate_value(self.value_pending) end,
                         pen=COLOR_GREEN},
                    },
                },
                widgets.Label{
                    frame={l=0, t=2},
                    text='Click to mark/unmark for trade. Shift click to mark/unmark a range of items.',
                },
                widgets.HotkeyLabel{
                    frame={l=0, b=0},
                    label='Select all/none',
                    key='CUSTOM_CTRL_A',
                    on_activate=self:callback('toggle_visible'),
                    auto_width=true,
                },
                widgets.ToggleHotkeyLabel{
                    view_id='group_items',
                    frame={l=25, b=0, w=24},
                    label='Group items:',
                    key='CUSTOM_CTRL_G',
                    options={
                        {label='Yes', value=true, pen=COLOR_GREEN},
                        {label='No', value=false}
                    },
                    initial_option=true,
                    on_change=function() self:refresh_list() end,
                },
                widgets.ToggleHotkeyLabel{
                    view_id='inside_containers',
                    frame={l=51, b=0, w=30},
                    label='Inside containers:',
                    key='CUSTOM_CTRL_I',
                    options={
                        {label='Yes', value=true, pen=COLOR_GREEN},
                        {label='No', value=false}
                    },
                    initial_option=false,
                    on_change=function() self:refresh_list() end,
                },
            },
        },
    }

    -- replace the FilteredList's built-in EditField with our own
    self.subviews.list.list.frame.t = 0
    self.subviews.list.edit.visible = false
    self.subviews.list.edit = self.subviews.search
    self.subviews.search.on_change = self.subviews.list:callback('onFilterChange')

    self.subviews.list:setChoices(self:get_choices())
end

function MoveGoods:refresh_list(sort_widget, sort_fn)
    sort_widget = sort_widget or 'sort'
    sort_fn = sort_fn or self.subviews.sort:getOptionValue()
    if sort_fn == sort_noop then
        self.subviews[sort_widget]:cycle()
        return
    end
    for _,widget_name in ipairs{'sort', 'sort_dist', 'sort_value', 'sort_quantity', 'sort_name'} do
        self.subviews[widget_name]:setOption(sort_fn)
    end
    local list = self.subviews.list
    local saved_filter = list:getFilter()
    list:setFilter('')
    list:setChoices(self:get_choices(), list:getSelected())
    list:setFilter(saved_filter)
end

local function is_container(item)
    return item and (
        df.item_binst:is_instance(item) or
        item:isFoodStorage()
    )
end

local function is_tradeable_item(item, depot)
    if item.flags.hostile or
        item.flags.removed or
        item.flags.dead_dwarf or
        item.flags.spider_web or
        item.flags.construction or
        item.flags.encased or
        item.flags.murder or
        item.flags.trader or
        item.flags.owned or
        item.flags.garbage_collect or
        item.flags.on_fire
    then
        return false
    end
    if item.flags.in_inventory then
        local gref = dfhack.items.getGeneralRef(item, df.general_ref_type.CONTAINED_IN_ITEM)
        if not gref then return false end
        if not is_container(gref:getItem()) or item:isLiquidPowder() then
            return false
        end
    end
    if item.flags.in_job then
        local spec_ref = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
        if not spec_ref then return true end
        return spec_ref.data.job.job_type == df.job_type.BringItemToDepot
    end
    if item.flags.in_building then
        if dfhack.items.getHolderBuilding(item) ~= depot then return false end
        for _, contained_item in ipairs(depot.contained_items) do
            if contained_item.use_mode == df.building_item_role_type.TEMP then return true end
            -- building construction materials
            if item == contained_item.item then return false end
        end
    end
    return dfhack.maps.canWalkBetween(xyz2pos(dfhack.items.getPosition(item)),
        xyz2pos(depot.centerx, depot.centery, depot.z))
end

local function get_entry_icon(data, item_id)
    if data.selected == 0 then return nil end
    if item_id then
        return data.items[item_id].pending and common.ALL_PEN or nil
    end
    if data.quantity == data.selected then return common.ALL_PEN end
    return common.SOME_PEN
end

local function make_choice_text(at_depot, dist, value, quantity, desc)
    return {
        {width=DIST_COL_WIDTH-2, rjustify=true, text=at_depot and 'depot' or tostring(dist)},
        {gap=2, width=VALUE_COL_WIDTH, rjustify=true, text=common.obfuscate_value(value)},
        {gap=2, width=QTY_COL_WIDTH, rjustify=true, text=quantity},
        {gap=2, text=desc},
    }
end

local function is_ethical_item(item, animal_ethics, wood_ethics)
    return (not animal_ethics or not item:isAnimalProduct()) and
        (not wood_ethics or not common.has_wood(item))
end

local function is_ethical_product(item, animal_ethics, wood_ethics)
    if not animal_ethics and not wood_ethics then return true end

    -- if item is not a container or is an empty container, then the ethics is not mixed
    -- and the ethicality of the item speaks for itself
    local has_ethical = is_ethical_item(item, animal_ethics, wood_ethics)
    local is_mixed = false
    if not item.flags.container then
        return has_ethical, is_mixed
    end
    local contained_items = dfhack.items.getContainedItems(item)
    if #contained_items == 0 then
        return has_ethical, is_mixed
    end

    if df.item_binst:is_instance(item) then
        for _, contained_item in ipairs(contained_items) do
            if is_ethical_item(contained_item, animal_ethics, wood_ethics) then
                if not has_ethical then
                    has_ethical, is_mixed = true, true
                    break
                end
            elseif has_ethical then
                is_mixed = true
                break
            end
        end
    elseif has_ethical then
        -- for other types of containers, any contamination makes it unethical since contained
        -- items cannot be individually selected in the barter screen
        for _, contained_item in ipairs(contained_items) do
            if not is_ethical_item(contained_item, animal_ethics, wood_ethics) then
                has_ethical = false
                break
            end
        end
    end

    return has_ethical, is_mixed
end

local function make_container_search_key(item, desc)
    local words = {}
    common.add_words(words, desc)
    for _, contained_item in ipairs(dfhack.items.getContainedItems(item)) do
        common.add_words(words, dfhack.items.getReadableDescription(contained_item))
    end
    return table.concat(words, ' ')
end

local function get_cache_index(group_items, inside_containers)
    local val = 1
    if group_items then val = val + 1 end
    if inside_containers then val = val + 2 end
    return val
end

local function contains_non_liquid_powder(container)
    for _, item in ipairs(dfhack.items.getContainedItems(container)) do
        if not item:isLiquidPowder() then return true end
    end
    return false
end

local function get_distance(bld, pos)
    return math.max(math.abs(bld.centerx - pos.x), math.abs(bld.centery - pos.y)) + math.abs(bld.z - pos.z)
end

function MoveGoods:cache_choices()
    local group_items = self.subviews.group_items:getOptionValue()
    local inside_containers = self.subviews.inside_containers:getOptionValue()
    local cache_idx = get_cache_index(group_items, inside_containers)
    if self.choices_cache[cache_idx] then return self.choices_cache[cache_idx] end

    local pending = self.pending_item_ids
    local groups = {}
    for _, item in ipairs(df.global.world.items.other.IN_PLAY) do
        if not item or not is_tradeable_item(item, self.depot) then goto continue end
        if inside_containers and is_container(item) and contains_non_liquid_powder(item) then
            goto continue
        elseif not inside_containers and item.flags.in_inventory then
            goto continue
        end
        local item_id = item.id
        local value = common.get_perceived_value(item)
        if value <= 0 then goto continue end
        local dist = get_distance(self.depot, xyz2pos(dfhack.items.getPosition(item)))
        local is_pending = not not pending[item_id] or item.flags.in_building
        local is_forbidden = item.flags.forbid
        local is_banned, is_risky = common.scan_banned(item, self.risky_items)
        local is_requested = dfhack.items.isRequestedTradeGood(item)
        local wear_level = item:getWear()
        local desc = dfhack.items.getReadableDescription(item)
        local key = ('%s/%d'):format(desc, value)
        if groups[key] then
            local group = groups[key]
            group.data.items[item_id] = {item=item, pending=is_pending, banned=is_banned, requested=is_requested}
            group.data.quantity = group.data.quantity + 1
            group.data.dist = math.min(group.data.dist or math.huge, dist)
            group.data.selected = group.data.selected + (is_pending and 1 or 0)
            group.data.num_at_depot = group.data.num_at_depot + (item.flags.in_building and 1 or 0)
            group.data.has_forbidden = group.data.has_forbidden or is_forbidden
            group.data.has_banned = group.data.has_banned or is_banned
            group.data.has_risky = group.data.has_risky or is_risky
            group.data.has_requested = group.data.has_requested or is_requested
        else
            local has_ethical, is_ethical_mixed = is_ethical_product(item, self.animal_ethics, self.wood_ethics)
            local data = {
                desc=desc,
                per_item_value=value,
                item=item, -- a representative item that we can use for filtering later
                items={[item_id]={item=item, pending=is_pending, banned=is_banned, risky=is_risky, requested=is_requested}},
                item_type=item:getType(),
                item_subtype=item:getSubtype(),
                quantity=1,
                quality=item.flags.artifact and 6 or item:getQuality(),
                dist=dist,
                wear=wear_level,
                selected=is_pending and 1 or 0,
                num_at_depot=item.flags.in_building and 1 or 0,
                has_forbidden=is_forbidden,
                has_foreign=item.flags.foreign,
                has_banned=is_banned,
                has_risky=is_risky,
                has_requested=is_requested,
                has_ethical=has_ethical,
                ethical_mixed=is_ethical_mixed,
                dirty=false,
            }
            local search_key
            if not inside_containers and is_container(item) then
                search_key = make_container_search_key(item, desc)
            else
                search_key = common.make_search_key(desc)
            end
            local entry = {
                search_key=search_key,
                icon=curry(get_entry_icon, data),
                data=data,
            }
            groups[key] = entry
        end
        ::continue::
    end

    local group_choices, nogroup_choices = {}, {}
    for _, group in pairs(groups) do
        local data = group.data
        for item_id, item_data in pairs(data.items) do
            local nogroup_choice = copyall(group)
            nogroup_choice.icon = curry(get_entry_icon, data, item_id)
            nogroup_choice.text = make_choice_text(item_data.item.flags.in_building,
                data.dist, data.per_item_value, 1, data.desc)
            nogroup_choice.item_id = item_id
            table.insert(nogroup_choices, nogroup_choice)
        end
        data.total_value = data.per_item_value * data.quantity
        group.text = make_choice_text(data.num_at_depot == data.quantity, data.dist, data.total_value, data.quantity, data.desc)
        table.insert(group_choices, group)
        self.value_pending = self.value_pending + (data.per_item_value * data.selected)
    end

    self.choices_cache[get_cache_index(true, inside_containers)] = group_choices
    self.choices_cache[get_cache_index(false, inside_containers)] = nogroup_choices
    return self.choices_cache[cache_idx]
end

function MoveGoods:get_choices()
    local raw_choices = self:cache_choices()
    local choices = {}
    local include_forbidden = not self.subviews.hide_forbidden:getOptionValue()
    local provenance = self.subviews.provenance:getOptionValue()
    local banned = self.subviews.banned:getOptionValue()
    local only_agreement = self.subviews.only_agreement:getOptionValue()
    local ethical = self.subviews.ethical:getOptionValue()
    local strict_ethical_bins = self.subviews.strict_ethical_bins:getOptionValue()
    local min_condition = self.subviews.min_condition:getOptionValue()
    local max_condition = self.subviews.max_condition:getOptionValue()
    local min_quality = self.subviews.min_quality:getOptionValue()
    local max_quality = self.subviews.max_quality:getOptionValue()
    local min_value = self.subviews.min_value:getOptionValue().value
    local max_value = self.subviews.max_value:getOptionValue().value
    for _,choice in ipairs(raw_choices) do
        local data = choice.data
        if ethical ~= 'show' then
            if strict_ethical_bins and data.ethical_mixed then goto continue end
            if ethical == 'hide' and data.has_ethical then goto continue end
            if ethical == 'only' and not data.has_ethical then goto continue end
        end
        if not include_forbidden then
            if choice.item_id then
                if data.items[choice.item_id].item.flags.forbid then
                    goto continue
                end
            elseif data.has_forbidden then
                goto continue
            end
        end
        if provenance ~= 'all' then
            if (provenance == 'local' and data.has_foreign) or
                (provenance == 'foreign' and not data.has_foreign)
            then
                goto continue
            end
        end
        if min_condition < data.wear then goto continue end
        if max_condition > data.wear then goto continue end
        if min_quality > data.quality then goto continue end
        if max_quality < data.quality then goto continue end
        if min_value > data.per_item_value then goto continue end
        if max_value < data.per_item_value then goto continue end
        if only_agreement then
            if choice.item_id then
                if not data.items[choice.item_id].requested then
                    goto continue
                end
            elseif not data.has_requested then
                goto continue
            end
        end
        if banned ~= 'ignore' then
            if choice.item_id then
                if data.items[choice.item_id].banned or (banned ~= 'banned_only' and data.items[choice.item_id].risky) then
                    goto continue
                end
            elseif data.has_banned or (banned ~= 'banned_only' and data.has_risky) then
                goto continue
            end
        end
        if not predicates.pass_predicates(self.predicate_context, data.item) then
            goto continue
        end
        table.insert(choices, choice)
        ::continue::
    end
    table.sort(choices, self.subviews.sort:getOptionValue())
    return choices
end

function MoveGoods:toggle_item_base(choice, target_value)
    if choice.item_id then
        local item_data = choice.data.items[choice.item_id]
        if item_data.pending then
            self.value_pending = self.value_pending - choice.data.per_item_value
            choice.data.selected = choice.data.selected - 1
        end
        if target_value == nil then target_value = not item_data.pending end
        item_data.pending = target_value
        if item_data.pending then
            self.value_pending = self.value_pending + choice.data.per_item_value
            choice.data.selected = choice.data.selected + 1
        end
    else
        self.value_pending = self.value_pending - (choice.data.selected * choice.data.per_item_value)
        if target_value == nil then target_value = (choice.data.selected ~= choice.data.quantity) end
        for _, item_data in pairs(choice.data.items) do
            item_data.pending = target_value
        end
        choice.data.selected = target_value and choice.data.quantity or 0
        self.value_pending = self.value_pending + (choice.data.selected * choice.data.per_item_value)
    end
    choice.data.dirty = true
    return target_value
end

function MoveGoods:select_item(idx, choice)
    if not dfhack.internal.getModifiers().shift then
        self.prev_list_idx = self.subviews.list.list:getSelected()
    end
end

function MoveGoods:toggle_item(idx, choice)
    self:toggle_item_base(choice)
end

function MoveGoods:toggle_range(idx, choice)
    if not self.prev_list_idx then
        self:toggle_item(idx, choice)
        return
    end
    local choices = self.subviews.list:getVisibleChoices()
    local list_idx = self.subviews.list.list:getSelected()
    local target_value
    for i = list_idx, self.prev_list_idx, list_idx < self.prev_list_idx and 1 or -1 do
        target_value = self:toggle_item_base(choices[i], target_value)
    end
    self.prev_list_idx = list_idx
end

function MoveGoods:toggle_visible()
    local target_value
    for _, choice in ipairs(self.subviews.list:getVisibleChoices()) do
        target_value = self:toggle_item_base(choice, target_value)
    end
end

-- -------------------
-- MoveGoodsModal
--

MoveGoodsModal = defclass(MoveGoodsModal, gui.ZScreenModal)
MoveGoodsModal.ATTRS {
    focus_path='caravan/movegoods',
    depot=DEFAULT_NIL,
    on_dismiss=DEFAULT_NIL,
}

local function get_pending_trade_item_ids()
    local item_ids = {}
    for _,job in utils.listpairs(df.global.world.jobs.list) do
        if job.job_type == df.job_type.BringItemToDepot and #job.items > 0 then
            item_ids[job.items[0].item.id] = true
        end
    end
    return item_ids
end

function MoveGoodsModal:init()
    self.pending_item_ids = get_pending_trade_item_ids()
    self.depot = self.depot or dfhack.gui.getSelectedBuilding(true)
    self:addviews{
        MoveGoods{
            view_id='move_goods',
            pending_item_ids=self.pending_item_ids,
            depot=self.depot,
        },
    }
end

function MoveGoodsModal:onDismiss()
    -- mark/unmark selected goods for trade
    local depot = self.depot
    if not depot then return end
    local pending = self.pending_item_ids
    for _, choice in ipairs(self.subviews.move_goods:cache_choices()) do
        if not choice.data.dirty then goto continue end
        for item_id, item_data in pairs(choice.data.items) do
            local item = item_data.item
            if item_data.pending and not pending[item_id] then
                item.flags.forbid = false
                if dfhack.items.getHolderBuilding(item) == depot then
                    item.flags.in_building = true
                else
                    -- TODO: if there is just one (ethical, if filtered) item inside of a bin, mark the item for
                    -- trade instead of the bin
                    -- TODO: give containers that have some items inside of them marked for trade a ":" marker in the UI
                    -- TODO: correlate items inside containers marked for trade across the cached choices so no choices are lost
                    dfhack.items.markForTrade(item, depot)
                end
            elseif not item_data.pending and pending[item_id] then
                local spec_ref = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
                if spec_ref then
                    dfhack.job.removeJob(spec_ref.data.job)
                end
            elseif not item_data.pending and item.flags.in_building and dfhack.items.getHolderBuilding(item) == depot then
                item.flags.in_building = false
            end
        end
        ::continue::
    end
    if self.on_dismiss then
        self.on_dismiss(self)
    end
end

-- -------------------
-- MoveGoodsOverlay
--

local function has_trade_depot_and_caravan()
    local bld = dfhack.gui.getSelectedBuilding(true)
    if not bld or bld:getBuildStage() < bld:getMaxBuildStage() then
        return false
    end
    if #bld.jobs == 1 and bld.jobs[0].job_type == df.job_type.DestroyBuilding then
        return false
    end

    for _, caravan in ipairs(df.global.plotinfo.caravans) do
        if caravan.flags.tribute then goto continue end
        local trade_state = caravan.trade_state
        local time_remaining = caravan.time_remaining
        if time_remaining > 0 and
            (trade_state == df.caravan_state.T_trade_state.Approaching or
             trade_state == df.caravan_state.T_trade_state.AtDepot)
        then
            return true
        end
        ::continue::
    end
    return false
end

MoveGoodsOverlay = defclass(MoveGoodsOverlay, overlay.OverlayWidget)
MoveGoodsOverlay.ATTRS{
    desc='Adds link to trade depot building to launch the DFHack trade goods UI.',
    default_pos={x=-64, y=10},
    default_enabled=true,
    viewscreens='dwarfmode/ViewSheets/BUILDING/TradeDepot',
    frame={w=33, h=1},
    frame_background=gui.CLEAR_PEN,
    visible=has_trade_depot_and_caravan,
}

function MoveGoodsOverlay:init()
    self:addviews{
        widgets.TextButton{
            frame={t=0, l=0},
            label='DFHack move trade goods',
            key='CUSTOM_CTRL_T',
            on_activate=function() MoveGoodsModal{}:show() end,
        },
    }
end

-- -------------------
-- MoveGoodsHiderOverlay
--

MoveGoodsHiderOverlay = defclass(MoveGoodsHiderOverlay, overlay.OverlayWidget)
MoveGoodsHiderOverlay.ATTRS{
    desc='Hides the vanilla trade goods selection button.',
    default_pos={x=-70, y=12},
    viewscreens='dwarfmode/ViewSheets/BUILDING/TradeDepot',
    frame={w=27, h=3},
    frame_background=gui.CLEAR_PEN,
    visible=has_trade_depot_and_caravan,
}

function MoveGoodsHiderOverlay:onInput(keys)
    return keys._MOUSE_L and self:getMouseFramePos()
end

-- -------------------
-- AssignTradeOverlay
--

AssignTradeOverlay = defclass(AssignTradeOverlay, overlay.OverlayWidget)
AssignTradeOverlay.ATTRS{
    desc='Adds link to the trade goods screen to launch the DFHack trade goods UI.',
    default_pos={x=-41,y=-5},
    default_enabled=true,
    viewscreens='dwarfmode/AssignTrade',
    frame={w=33, h=1},
    frame_background=gui.CLEAR_PEN,
}

function AssignTradeOverlay:init()
    local on_dismiss = function(scr)
        scr:sendInputToParent('LEAVESCREEN')
    end
    self:addviews{
        widgets.TextButton{
            frame={t=0, l=0},
            label='DFHack move trade goods',
            key='CUSTOM_CTRL_T',
            on_activate=function()
                local depot = df.global.game.main_interface.assign_trade.trade_depot_bld
                MoveGoodsModal{depot=depot, on_dismiss=on_dismiss}:show()
            end,
        },
    }
end
