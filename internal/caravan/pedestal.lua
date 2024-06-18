--@ module=true

-- TODO: this should be moved to stocks once the item filter code is moved there

local common = reqscript('internal/caravan/common')
local gui = require('gui')
local overlay = require('plugins.overlay')
local utils = require('utils')
local widgets = require('gui.widgets')

local STATUS = {
    NONE={label='Unknown', value=0},
    ASSIGNED_HERE={label='Assigned here', value=1},
    ASSIGNED_THERE={label='Assigned elsewhere', value=2},
    AVAILABLE={label='', value=3},
}
local STATUS_REVMAP = {}
for k, v in pairs(STATUS) do
    STATUS_REVMAP[v.value] = k
end

-- -------------------
-- AssignItems
--

AssignItems = defclass(AssignItems, widgets.Window)
AssignItems.ATTRS {
    frame_title='Assign items for display',
    frame={w=76, h=46},
    resizable=true,
    resize_min={h=25},
    frame_inset={l=1, t=1, b=1, r=0},
}

local STATUS_COL_WIDTH = 18
local VALUE_COL_WIDTH = 9

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
    if a.data.value == b.data.value then
        return sort_by_name_desc(a, b)
    end
    return a.data.value > b.data.value
end

local function sort_by_value_asc(a, b)
    if a.data.value == b.data.value then
        return sort_by_name_desc(a, b)
    end
    return a.data.value < b.data.value
end

local function sort_by_status_desc(a, b)
    if a.data.status == b.data.status then
        return sort_by_value_desc(a, b)
    end
    return a.data.status < b.data.status
end

local function sort_by_status_asc(a, b)
    if a.data.status == b.data.status then
        return sort_by_value_desc(a, b)
    end
    return a.data.status > b.data.status
end

local function get_assigned_value(display_bld)
    local value = 0
    for _, item_id in ipairs(display_bld.displayed_items) do
        local item = df.item.find(item_id)
        if item then
            value = value + common.get_perceived_value(item)
        end
    end
    return value
end

local function get_containing_temple_or_guildhall(display_bld)
    local loc_id = nil
    for _, relation in ipairs(display_bld.relations) do
        if relation.location_id > -1 then
            loc_id = relation.location_id
        end
    end
    if not loc_id then return end
    local site = dfhack.world.getCurrentSite()
    local location = utils.binsearch(site.buildings, loc_id, 'id')
    if not location then return end
    local loc_type = location:getType()
    if loc_type ~= df.abstract_building_type.GUILDHALL and loc_type ~= df.abstract_building_type.TEMPLE then
        return
    end
    return location
end

local function to_title_case(str)
    str = str:gsub('(%a)([%w_]*)',
        function (first, rest) return first:upper()..rest:lower() end)
    str = str:gsub('_', ' ')
    return str
end

-- returns the value of items assigned to the display but not yet in the display
local function get_pending_value(display_bld)
    local value = get_assigned_value(display_bld)
    for _, contained_item in ipairs(display_bld.contained_items) do
        if contained_item.use_mode ~= df.building_item_role_type.TEMP or
            not contained_item.item.flags.in_building
        then
            goto continue
        end
        value = value - common.get_perceived_value(contained_item.item)
        ::continue::
    end
    return value
end

local difficulty = df.global.plotinfo.main.custom_difficulty
local function get_expected_location_tier(display_bld)
    local location = get_containing_temple_or_guildhall(display_bld)
    if not location then return '' end
    local loc_type = to_title_case(df.abstract_building_type[location:getType()])
    local pending_value = get_pending_value(display_bld) // #display_bld.relations
    local value = location.contents.location_value + pending_value
    if loc_type == 'Guildhall' then
        if value >= difficulty.grand_guildhall_value then
            return 'Grand Guildhall'
        elseif value >= difficulty.guildhall_value then
            return loc_type
        end
    else
        if value >= difficulty.temple_complex_value then
            return 'Temple Complex'
        elseif value >= difficulty.temple_value then
            return loc_type
        end
    end
    return 'Meeting Hall'
end

function AssignItems:init()
    self.bld = dfhack.gui.getSelectedBuilding(true)
    if not self.bld or not df.building_display_furniturest:is_instance(self.bld) then
        qerror('No display furniture selected')
    end

    self.choices_cache = {}

    self:addviews{
        widgets.CycleHotkeyLabel{
            view_id='sort',
            frame={l=0, t=0, w=21},
            label='Sort by:',
            key='CUSTOM_SHIFT_S',
            options={
                {label='status'..common.CH_DN, value=sort_by_status_desc},
                {label='status'..common.CH_UP, value=sort_by_status_asc},
                {label='value'..common.CH_DN, value=sort_by_value_desc},
                {label='value'..common.CH_UP, value=sort_by_value_asc},
                {label='name'..common.CH_DN, value=sort_by_name_desc},
                {label='name'..common.CH_UP, value=sort_by_name_asc},
            },
            initial_option=sort_by_status_desc,
            on_change=self:callback('refresh_list', 'sort'),
        },
        widgets.EditField{
            view_id='search',
            frame={l=26, t=0},
            label_text='Search: ',
            on_char=function(ch) return ch:match('[%l -]') end,
        },
        widgets.Panel{
            frame={t=2, l=0, w=72, h=6},
            frame_style=gui.FRAME_INTERIOR,
            subviews={
                widgets.Panel{
                    frame={t=0, l=0, w=38, h=4},
                    subviews={
                        widgets.CycleHotkeyLabel{
                            view_id='min_quality',
                            frame={l=0, t=0, w=18},
                            label='Min quality:',
                            label_below=true,
                            key_back='CUSTOM_SHIFT_Z',
                            key='CUSTOM_SHIFT_X',
                            options={
                                {label='Ordinary', value=0},
                                {label='-Well Crafted-', value=1},
                                {label='+Finely Crafted+', value=2},
                                {label='*Superior*', value=3},
                                {label=common.CH_EXCEPTIONAL..'Exceptional'..common.CH_EXCEPTIONAL, value=4},
                                {label=common.CH_MONEY..'Masterful'..common.CH_MONEY, value=5},
                                {label='Artifact', value=6},
                            },
                            initial_option=0,
                            on_change=function(val)
                                if self.subviews.max_quality:getOptionValue() < val then
                                    self.subviews.max_quality:setOption(val)
                                end
                                self:refresh_list()
                            end,
                        },
                        widgets.CycleHotkeyLabel{
                            view_id='max_quality',
                            frame={r=1, t=0, w=18},
                            label='Max quality:',
                            label_below=true,
                            key_back='CUSTOM_SHIFT_Q',
                            key='CUSTOM_SHIFT_W',
                            options={
                                {label='Ordinary', value=0},
                                {label='-Well Crafted-', value=1},
                                {label='+Finely Crafted+', value=2},
                                {label='*Superior*', value=3},
                                {label=common.CH_EXCEPTIONAL..'Exceptional'..common.CH_EXCEPTIONAL, value=4},
                                {label=common.CH_MONEY..'Masterful'..common.CH_MONEY, value=5},
                                {label='Artifact', value=6},
                            },
                            initial_option=6,
                            on_change=function(val)
                                if self.subviews.min_quality:getOptionValue() > val then
                                    self.subviews.min_quality:setOption(val)
                                end
                                self:refresh_list()
                            end,
                        },
                        widgets.RangeSlider{
                            frame={l=0, t=3},
                            num_stops=7,
                            get_left_idx_fn=function()
                                return self.subviews.min_quality:getOptionValue() + 1
                            end,
                            get_right_idx_fn=function()
                                return self.subviews.max_quality:getOptionValue() + 1
                            end,
                            on_left_change=function(idx) self.subviews.min_quality:setOption(idx-1, true) end,
                            on_right_change=function(idx) self.subviews.max_quality:setOption(idx-1, true) end,
                        },
                    },
                },
                widgets.ToggleHotkeyLabel{
                    view_id='hide_unreachable',
                    frame={t=0, l=40, w=30},
                    label='Hide unreachable items:',
                    key='CUSTOM_SHIFT_U',
                    options={
                        {label='Yes', value=true, pen=COLOR_GREEN},
                        {label='No', value=false}
                    },
                    initial_option=true,
                    on_change=function() self:refresh_list() end,
                },
                widgets.ToggleHotkeyLabel{
                    view_id='hide_forbidden',
                    frame={t=2, l=40, w=28},
                    label='Hide forbidden items:',
                    key='CUSTOM_SHIFT_F',
                    options={
                        {label='Yes', value=true, pen=COLOR_GREEN},
                        {label='No', value=false}
                    },
                    initial_option=false,
                    on_change=function() self:refresh_list() end,
                },
            },
        },
        widgets.Panel{
            frame={t=9, l=0, r=0, b=7},
            subviews={
                widgets.CycleHotkeyLabel{
                    view_id='sort_status',
                    frame={t=0, l=0, w=7},
                    options={
                        {label='status', value=sort_noop},
                        {label='status'..common.CH_DN, value=sort_by_status_desc},
                        {label='status'..common.CH_UP, value=sort_by_status_asc},
                    },
                    initial_option=sort_by_status_desc,
                    option_gap=0,
                    on_change=self:callback('refresh_list', 'sort_status'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_value',
                    frame={t=0, l=STATUS_COL_WIDTH+2+VALUE_COL_WIDTH+1-6, w=6},
                    options={
                        {label='value', value=sort_noop},
                        {label='value'..common.CH_DN, value=sort_by_value_desc},
                        {label='value'..common.CH_UP, value=sort_by_value_asc},
                    },
                    option_gap=0,
                    on_change=self:callback('refresh_list', 'sort_value'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_name',
                    frame={t=0, l=STATUS_COL_WIDTH+2+VALUE_COL_WIDTH+2, w=5},
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
                    on_submit=self:callback('toggle_item'),
                    on_submit2=self:callback('toggle_range'),
                    on_select=self:callback('select_item'),
                },
            }
        },
        widgets.Label{
            frame={l=0, b=5, h=1, r=0},
            text={
                'Total value of assigned items:',
                {gap=1, pen=COLOR_GREEN,
                 text=function() return common.obfuscate_value(get_assigned_value(self.bld)) end},
            },
        },
        widgets.Label{
            frame={l=0, b=4, h=1, r=0},
            text={
                {gap=7,
                 text='Expected location tier:'},
                {gap=1, pen=COLOR_GREEN,
                 text=function() return get_expected_location_tier(self.bld) end},
            },
            visible=function() return get_containing_temple_or_guildhall(self.bld) end,
        },
        widgets.HotkeyLabel{
            frame={l=0, b=2},
            label='Select all/none',
            key='CUSTOM_CTRL_A',
            on_activate=self:callback('toggle_visible'),
            auto_width=true,
        },
        widgets.ToggleHotkeyLabel{
            view_id='inside_containers',
            frame={l=33, b=2, w=34},
            label='See inside containers:',
            key='CUSTOM_CTRL_I',
            options={
                {label='Yes', value=true, pen=COLOR_GREEN},
                {label='No', value=false}
            },
            initial_option=true,
            on_change=function() self:refresh_list() end,
        },
        widgets.WrappedLabel{
            frame={b=0, l=0, r=0},
            text_to_wrap='Click to assign/unassign. Shift click to assign/unassign a range.',
        },
    }

    -- replace the FilteredList's built-in EditField with our own
    self.subviews.list.list.frame.t = 0
    self.subviews.list.edit.visible = false
    self.subviews.list.edit = self.subviews.search
    self.subviews.search.on_change = self.subviews.list:callback('onFilterChange')

    self.subviews.list:setChoices(self:get_choices())
end

function AssignItems:refresh_list(sort_widget, sort_fn)
    sort_widget = sort_widget or 'sort'
    sort_fn = sort_fn or self.subviews.sort:getOptionValue()
    if sort_fn == sort_noop then
        self.subviews[sort_widget]:cycle()
        return
    end
    for _,widget_name in ipairs{'sort', 'sort_status', 'sort_value', 'sort_name'} do
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

local function is_displayable_item(item)
    if not item or
        item.flags.hostile or
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
    if item.flags.in_job then
        local spec_ref = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
        if not spec_ref then return false end
        if spec_ref.data.job.job_type ~= df.job_type.PutItemOnDisplay then return false end
    elseif item.flags.in_inventory then
        local gref = dfhack.items.getGeneralRef(item, df.general_ref_type.CONTAINED_IN_ITEM)
        if not gref then return false end
        if not is_container(df.item.find(gref.item_id)) or item:isLiquidPowder() then
            return false
        end
    end
    if not dfhack.maps.isTileVisible(xyz2pos(dfhack.items.getPosition(item))) then
        return false
    end
    if item.flags.in_building then
        local bld = dfhack.items.getHolderBuilding(item)
        if not bld then return false end
        for _, contained_item in ipairs(bld.contained_items) do
            if contained_item.use_mode == df.building_item_role_type.TEMP then return true end
            -- building construction materials
            if item == contained_item.item then return false end
        end
    end
    return true
end

local function get_display_bld_id(item)
    local assigned_bld_ref = dfhack.items.getGeneralRef(item, df.general_ref_type.BUILDING_DISPLAY_FURNITURE)
    if assigned_bld_ref then return assigned_bld_ref.building_id end
end

local function get_status(item, display_bld)
    local display_bld_id = get_display_bld_id(item)
    if display_bld_id == display_bld.id then
        return STATUS.ASSIGNED_HERE.value
    elseif display_bld_id then
        return STATUS.ASSIGNED_THERE.value
    end
    return STATUS.AVAILABLE.value
end

local function make_choice_text(data)
    return {
        {width=STATUS_COL_WIDTH, text=function() return STATUS[STATUS_REVMAP[data.status]].label end},
        {gap=2, width=VALUE_COL_WIDTH, rjustify=true, text=common.obfuscate_value(data.value)},
        {gap=2, text=data.desc},
    }
end

local function make_container_search_key(item, desc)
    local words = {}
    common.add_words(words, desc)
    for _, contained_item in ipairs(dfhack.items.getContainedItems(item)) do
        common.add_words(words, dfhack.items.getReadableDescription(contained_item))
    end
    return table.concat(words, ' ')
end

local function contains_non_liquid_powder(container)
    for _, item in ipairs(dfhack.items.getContainedItems(container)) do
        if not item:isLiquidPowder() then return true end
    end
    return false
end

function AssignItems:cache_choices(inside_containers, display_bld)
    if self.choices_cache[inside_containers] then return self.choices_cache[inside_containers] end

    local choices = {}
    for _, item in ipairs(df.global.world.items.other.IN_PLAY) do
        if not is_displayable_item(item) then goto continue end
        if inside_containers and is_container(item) and contains_non_liquid_powder(item) then
            goto continue
        elseif not inside_containers and item.flags.in_inventory then
            goto continue
        end
        local value = common.get_perceived_value(item)
        local desc = dfhack.items.getReadableDescription(item)
        local status = get_status(item, self.bld)
        local reachable = dfhack.maps.canWalkBetween(xyz2pos(dfhack.items.getPosition(item)),
                xyz2pos(display_bld.centerx, display_bld.centery, display_bld.z))
        local data = {
            item=item,
            desc=desc,
            value=value,
            status=status,
            quality=item.flags.artifact and 6 or item:getQuality(),
            reachable=reachable,
        }
        local search_key
        if not inside_containers and is_container(item) then
            search_key = make_container_search_key(item, desc)
        else
            search_key = common.make_search_key(desc)
        end
        local entry = {
            search_key=search_key,
            text=make_choice_text(data),
            data=data,
        }
        table.insert(choices, entry)
        ::continue::
    end

    self.choices_cache[inside_containers] = choices
    return choices
end

function AssignItems:get_choices()
    local raw_choices = self:cache_choices(self.subviews.inside_containers:getOptionValue(), self.bld)
    local choices = {}
    local include_unreachable = not self.subviews.hide_unreachable:getOptionValue()
    local include_forbidden = not self.subviews.hide_forbidden:getOptionValue()
    local min_quality = self.subviews.min_quality:getOptionValue()
    local max_quality = self.subviews.max_quality:getOptionValue()
    for _,choice in ipairs(raw_choices) do
        local data = choice.data
        if not include_unreachable and not data.reachable then goto continue end
        if not include_forbidden and data.item.flags.forbid then goto continue end
        if min_quality > data.quality then goto continue end
        if max_quality < data.quality then goto continue end
        table.insert(choices, choice)
        ::continue::
    end
    table.sort(choices, self.subviews.sort:getOptionValue())
    return choices
end

local function unassign_item(bld, item)
    if not bld then return end
    local _, found, idx = utils.binsearch(bld.displayed_items, item.id)
    if found then
        bld.displayed_items:erase(idx)
    end
end

local function detach_item(item)
    if item.flags.in_job then
        local spec_ref = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
        if spec_ref then
            dfhack.job.removeJob(spec_ref.data.job)
        end
    end
    local display_bld_id = get_display_bld_id(item)
    if not display_bld_id then return end
    for idx = #item.general_refs-1, 0, -1 do
        local ref = item.general_refs[idx]
        if df.general_ref_building_display_furniturest:is_instance(ref) then
            unassign_item(df.building.find(ref.building_id), item)
            item.general_refs:erase(idx)
            ref:delete()
        end
    end
end

local function attach_item(item, display_bld)
    local ref = df.new(df.general_ref_building_display_furniturest)
    ref.building_id = display_bld.id
    item.general_refs:insert('#', ref)
    utils.insert_sorted(display_bld.displayed_items, item.id)
    item.flags.forbid = false
    item.flags.in_building = false
end

function AssignItems:toggle_item_base(choice, target_value)
    local true_value = STATUS.ASSIGNED_HERE.value

    if target_value == nil then
        target_value = choice.data.status ~= true_value
    end

    if target_value and choice.data.status == true_value then
        return target_value
    end
    if not target_value and choice.data.status ~= true_value then
        return target_value
    end

    local item = choice.data.item
    detach_item(item)

    if target_value then
        attach_item(item, self.bld)
    end

    choice.data.status = get_status(item, self.bld)

    return target_value
end

function AssignItems:select_item(idx, choice)
    if not dfhack.internal.getModifiers().shift then
        self.prev_list_idx = self.subviews.list.list:getSelected()
    end
end

function AssignItems:toggle_item(idx, choice)
    self:toggle_item_base(choice)
end

function AssignItems:toggle_range(idx, choice)
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

function AssignItems:toggle_visible()
    local target_value
    for _, choice in ipairs(self.subviews.list:getVisibleChoices()) do
        target_value = self:toggle_item_base(choice, target_value)
    end
end

-- -------------------
-- AssignItemsModal
--

AssignItemsModal = defclass(AssignItemsModal, gui.ZScreenModal)
AssignItemsModal.ATTRS {
    focus_path='pedestal/assignitems',
}

function AssignItemsModal:init()
    self:addviews{AssignItems{}}
end

-- -------------------
-- PedestalOverlay
--

PedestalOverlay = defclass(PedestalOverlay, overlay.OverlayWidget)
PedestalOverlay.ATTRS{
    desc='Adds link to the display furniture building panel to launch the DFHack display assignment UI.',
    default_pos={x=-40, y=34},
    default_enabled=true,
    viewscreens='dwarfmode/ViewSheets/BUILDING/DisplayFurniture',
    frame={w=23, h=1},
    frame_background=gui.CLEAR_PEN,
}

local function is_valid_building()
    local bld = dfhack.gui.getSelectedBuilding(true)
return bld and bld:getBuildStage() == bld:getMaxBuildStage()
end

function PedestalOverlay:init()
    self:addviews{
        widgets.TextButton{
            frame={t=0, l=0},
            label='DFHack assign items',
            key='CUSTOM_CTRL_T',
            visible=is_valid_building,
            on_activate=function() AssignItemsModal{}:show() end,
        },
    }
end
