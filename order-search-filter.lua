--@module = true
--[====[

order-search-filter
=======================
Overlay search/filter panel for the manager work orders list.

For manual testing, you can bind a hotkey in your ``dfhack*.init``::

    keybinding add Alt+S@workquota order-search-filter

]====]

local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

local orders = df.global.world.manager_orders.all
local itemdefs = df.global.world.raws.itemdefs
local reactions = df.global.world.raws.reactions.reactions

local meal_type_by_ingredient_count = {
    [2] = 'easy',
    [3] = 'fine',
    [4] = 'lavish',
}

local function make_order_material_desc(order, noun)
    local desc = ''
    if order.mat_type >= 0 then
        local matinfo = dfhack.matinfo.decode(order.mat_type, order.mat_index)
        if matinfo then
            desc = desc .. ' ' .. matinfo:toString()
        end
    else
        for k,v in pairs(order.material_category) do
            if v then
                desc = desc .. ' ' .. k
                break
            end
        end
    end
    return desc .. ' ' .. noun
end

local function make_order_desc(order)
    if order.job_type == df.job_type.CustomReaction then
        for _, reaction in ipairs(reactions) do
            if reaction.code == order.reaction_name then
                return reaction.name
            end
        end
        return ''
    elseif order.job_type == df.job_type.PrepareMeal then
        local meal_type = meal_type_by_ingredient_count[order.mat_type]
        if meal_type then
            return 'prepare ' .. meal_type .. ' meal'
        end
        return 'prepare meal'
    end

    local noun
    if order.job_type == df.job_type.MakeArmor then
        noun = itemdefs.armor[order.item_subtype].name
    elseif order.job_type == df.job_type.MakeWeapon then
        noun = itemdefs.weapons[order.item_subtype].name
    elseif order.job_type == df.job_type.MakeShield then
        noun = itemdefs.shields[order.item_subtype].name
    elseif order.job_type == df.job_type.MakeAmmo then
        noun = itemdefs.ammo[order.item_subtype].name
    elseif order.job_type == df.job_type.MakeHelm then
        noun = itemdefs.helms[order.item_subtype].name
    elseif order.job_type == df.job_type.MakeGloves then
        noun = itemdefs.gloves[order.item_subtype].name
    elseif order.job_type == df.job_type.MakePants then
        noun = itemdefs.pants[order.item_subtype].name
    elseif order.job_type == df.job_type.MakeShoes then
        noun = itemdefs.shoes[order.item_subtype].name
    elseif order.job_type == df.job_type.MakeTool then
        noun = itemdefs.tools[order.item_subtype].name
    elseif order.job_type == df.job_type.MakeTrapComponent then
        noun = itemdefs.trapcomps[order.item_subtype].name
    elseif order.job_type == df.job_type.SmeltOre then
        noun = 'ore'
    else
        noun = df.job_type.attrs[order.job_type].caption
    end
    return make_order_material_desc(order, noun)
end

local function build_order_text(order)
    local desc = make_order_desc(order)
    local total = order.amount_total or 0
    local remaining = order.amount_left or total
    if remaining ~= total then
        return string.format('%s x%d (%d left)', desc, total, remaining)
    end
    return string.format('%s x%d', desc, total)
end

OrderSearchFilter = defclass(OrderSearchFilter, overlay.OverlayWidget)
OrderSearchFilter.ATTRS{
    desc='Search and jump to work orders in the manager list.',
    default_enabled=true,
    default_pos={x=100, y=60},
    frame={w=34, h=3},
    overlay_onupdate_max_freq_seconds=1,
    viewscreens='dwarfmode/Info/WORK_ORDERS/Default',
}

function OrderSearchFilter:init()
    self:addviews{
        widgets.Panel{
            subviews={
                widgets.EditField{
                    view_id='filter',
                    frame={t=0, l=1, r=1},
                    key='CUSTOM_ALT_S',
                    label_text='Filter: ',
                    on_change=self:callback('on_filter_change'),
                },
            },
        },
    }
end

function OrderSearchFilter:overlay_onupdate()
    if self.filter_text then
        self:apply_filter(self.filter_text)
    end
end

local function order_matches(filter_lc, order)
    local text = build_order_text(order):lower()
    return text:find(filter_lc, 1, true) ~= nil
end

function OrderSearchFilter:snapshot_orders()
    local snapshot = {}
    for _, order in ipairs(orders) do
        table.insert(snapshot, order)
    end
    return snapshot
end

function OrderSearchFilter:rebuild_orders(new_orders)
    for i = #orders - 1, 0, -1 do
        orders:erase(i)
    end
    for _, order in ipairs(new_orders) do
        orders:insert('#', order)
    end
    local mi = df.global.game.main_interface
    if mi and mi.info and mi.info.work_orders then
        mi.info.work_orders.scroll_position_work_orders = 0
    end
end

function OrderSearchFilter:restore_orders()
    if not self.unfiltered_orders then return end
    local by_id = {}
    for _, order in ipairs(self.unfiltered_orders) do
        by_id[order.id] = order
    end
    for _, order in ipairs(orders) do
        if not by_id[order.id] then
            table.insert(self.unfiltered_orders, order)
            by_id[order.id] = order
        end
    end
    self:rebuild_orders(self.unfiltered_orders)
    self.unfiltered_orders = nil
    self.last_filtered_ids = nil
end

function OrderSearchFilter:apply_filter(filter)
    if filter == '' then
        self:restore_orders()
        return
    end
    if not self.unfiltered_orders then
        self.unfiltered_orders = self:snapshot_orders()
    end
    local filter_lc = filter:lower()
    local current_ids = {}
    for _, order in ipairs(orders) do
        current_ids[order.id] = true
    end
    if self.last_filtered_ids then
        local deleted_ids = {}
        for id in pairs(self.last_filtered_ids) do
            if not current_ids[id] then
                deleted_ids[id] = true
            end
        end
        if next(deleted_ids) then
            local cleaned = {}
            for _, order in ipairs(self.unfiltered_orders) do
                if not deleted_ids[order.id] then
                    table.insert(cleaned, order)
                end
            end
            self.unfiltered_orders = cleaned
        end
    end
    local filtered = {}
    for _, order in ipairs(self.unfiltered_orders) do
        if order_matches(filter_lc, order) then
            table.insert(filtered, order)
        end
    end
    self:rebuild_orders(filtered)
    self.last_filtered_ids = {}
    for _, order in ipairs(filtered) do
        self.last_filtered_ids[order.id] = true
    end
end

function OrderSearchFilter:on_filter_change(text)
    self.filter_text = text
    self:apply_filter(text)
end

function OrderSearchFilter:onInput(keys)
    if keys.SELECT then return false end
    return OrderSearchFilter.super.onInput(self, keys)
end

function OrderSearchFilter:overlay_ondisable()
    self:restore_orders()
end

OVERLAY_WIDGETS = {
    order_search_filter=OrderSearchFilter,
}

if dfhack_flags.module then
    return
end

if not dfhack.gui.matchFocusString('dwarfmode/Info/WORK_ORDERS/Default') then
    qerror('This script must be run from the Work Orders screen.')
end

overlay.overlay_command({'enable', 'order-search-filter.order_search_filter'})
