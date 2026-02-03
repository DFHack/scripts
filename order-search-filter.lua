--@module = true

local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

local ORDERS = df.global.world.manager_orders.all
local ITEMDEFS = df.global.world.raws.itemdefs
local REACTIONS = df.global.world.raws.reactions.reactions

local JOBTYPE_ITEMDEF = {
    [df.job_type.MakeArmor] = 'armor',
    [df.job_type.MakeWeapon] = 'weapons',
    [df.job_type.MakeShield] = 'shields',
    [df.job_type.MakeAmmo] = 'ammo',
    [df.job_type.MakeHelm] = 'helms',
    [df.job_type.MakeGloves] = 'gloves',
    [df.job_type.MakePants] = 'pants',
    [df.job_type.MakeShoes] = 'shoes',
    [df.job_type.MakeTool] = 'tools',
    [df.job_type.MakeTrapComponent] = 'trapcomps',
}

-- ------------------------------------------------------------
-- Matching
-- ------------------------------------------------------------

local function safe_name(vec, idx)
    if not vec or idx == nil or idx < 0 then return '' end
    local def = vec[idx]
    return (def and def.name) or ''
end

local function get_item_subtype_name(order)
    local key = JOBTYPE_ITEMDEF[order.job_type]
    if not key then return '' end
    return safe_name(ITEMDEFS[key], order.item_subtype)
end

local function get_reaction_name(order)
    if order.job_type ~= df.job_type.CustomReaction then return '' end
    for _, r in ipairs(REACTIONS) do
        if r.code == order.reaction_name then
            return r.name
        end
    end
    return ''
end

local function get_material_text(order)
    if order.mat_type >= 0 then
        local matinfo = dfhack.matinfo.decode(order.mat_type, order.mat_index)
        return matinfo and matinfo:toString() or ''
    end
    for k, v in pairs(order.material_category) do
        if v then
            return k
        end
    end
    return ''
end

local function build_search_text(order)
    local parts = {}

    local attr = df.job_type.attrs[order.job_type]
    if attr and attr.caption then
        parts[#parts+1] = attr.caption
    end

    local subtype = get_item_subtype_name(order)
    if subtype ~= '' then
        parts[#parts+1] = subtype
    end

    local rxn = get_reaction_name(order)
    if rxn ~= '' then
        parts[#parts+1] = rxn
    end

    local mat = get_material_text(order)
    if mat ~= '' then
        parts[#parts+1] = mat
    end

    return table.concat(parts, ' '):lower()
end

local function matches(filter_lc, order)
    return build_search_text(order):find(filter_lc, 1, true) ~= nil
end

-- ------------------------------------------------------------
-- Snapshot + deletion-safe tracking
-- ------------------------------------------------------------

-- entries: {id=<int>, order=<df.manager_order>}
local function snapshot_entries()
    local out = {}
    for _, order in ipairs(ORDERS) do
        out[#out+1] = {id = order.id, order = order}
    end
    return out
end

local function entries_to_orders(entries)
    local out = {}
    for _, e in ipairs(entries) do
        out[#out+1] = e.order
    end
    return out
end

local function visible_id_set()
    local ids = {}
    for _, order in ipairs(ORDERS) do
        ids[order.id] = true
    end
    return ids
end

-- ------------------------------------------------------------
-- Overlay widget
-- ------------------------------------------------------------

OrderSearchFilter = defclass(OrderSearchFilter, overlay.OverlayWidget)
OrderSearchFilter.ATTRS{
    desc='Filter work orders in the manager list.',
    default_enabled=true,
    default_pos={x=100, y=60},
    frame={w=34, h=3},
    overlay_onupdate_max_freq_seconds=1,
    viewscreens='dwarfmode/Info/WORK_ORDERS/Default',
}

function OrderSearchFilter:init()
    self.filter_text = nil
    self.pending_clear = false

    self.unfiltered_entries = nil
    self.last_filtered_ids = nil

    self:addviews{
        widgets.Panel{
            subviews={
                widgets.EditField{
                    view_id='filter',
                    frame={t=0, l=1, r=1},
                    key='CUSTOM_ALT_S',
                    label_text='Filter: ',
                    on_change=self:callback('on_filter_change'),
                    on_unfocus=self:callback('clear_filter'),
                },
            },
        },
    }
end

function OrderSearchFilter:overlay_onupdate()
    if self.pending_clear then
        self:clear_filter()
    end
    if self.filter_text then
        self:apply_filter(self.filter_text)
    end
end

function OrderSearchFilter:reset_scroll()
    local mi = df.global.game.main_interface
    if mi and mi.info and mi.info.work_orders then
        mi.info.work_orders.scroll_position_work_orders = 0
    end
end

function OrderSearchFilter:rebuild_visible_orders(new_orders)
    for i = #ORDERS - 1, 0, -1 do
        ORDERS:erase(i)
    end
    for _, order in ipairs(new_orders) do
        ORDERS:insert('#', order)
    end
    self:reset_scroll()
end

function OrderSearchFilter:incorporate_new_visible_orders_into_snapshot()
    if not self.unfiltered_entries then return end

    local known = {}
    for _, e in ipairs(self.unfiltered_entries) do
        known[e.id] = true
    end

    for _, order in ipairs(ORDERS) do
        local id = order.id
        if not known[id] then
            self.unfiltered_entries[#self.unfiltered_entries+1] = {id = id, order = order}
            known[id] = true
        end
    end
end

function OrderSearchFilter:restore_orders()
    if not self.unfiltered_entries then return end

    self:drop_deleted_from_snapshot(self:detect_deleted_ids())
    self:incorporate_new_visible_orders_into_snapshot()
    self:rebuild_visible_orders(entries_to_orders(self.unfiltered_entries))

    self.unfiltered_entries = nil
    self.last_filtered_ids = nil
end

function OrderSearchFilter:detect_deleted_ids()
    if not self.last_filtered_ids then return nil end

    local current = visible_id_set()
    local deleted = {}

    for id in pairs(self.last_filtered_ids) do
        if not current[id] then
            deleted[id] = true
        end
    end

    return next(deleted) and deleted or nil
end

function OrderSearchFilter:drop_deleted_from_snapshot(deleted)
    if not deleted then return end

    local cleaned = {}
    for _, e in ipairs(self.unfiltered_entries) do
        -- IMPORTANT: compare by cached e.id, never e.order.id
        if not deleted[e.id] then
            cleaned[#cleaned+1] = e
        end
    end
    self.unfiltered_entries = cleaned
end

function OrderSearchFilter:apply_filter(filter)
    if filter == '' then
        self:restore_orders()
        return
    end

    if not self.unfiltered_entries then
        self.unfiltered_entries = snapshot_entries()
    else
        self:drop_deleted_from_snapshot(self:detect_deleted_ids())
    end

    self:incorporate_new_visible_orders_into_snapshot()

    local filter_lc = filter:lower()
    local filtered_entries = {}

    for _, e in ipairs(self.unfiltered_entries) do
        if matches(filter_lc, e.order) then
            filtered_entries[#filtered_entries+1] = e
        end
    end

    self:rebuild_visible_orders(entries_to_orders(filtered_entries))

    self.last_filtered_ids = {}
    for _, e in ipairs(filtered_entries) do
        self.last_filtered_ids[e.id] = true
    end
end

function OrderSearchFilter:on_filter_change(text)
    self.filter_text = text
    self:apply_filter(text)
end

function OrderSearchFilter:onInput(keys)
    if keys.LEAVESCREEN then
        self:clear_filter()
    end
    if keys.SELECT then return false end
    return OrderSearchFilter.super.onInput(self, keys)
end

function OrderSearchFilter:clear_filter()
    local filter_view = self.subviews.filter
    if filter_view then
        filter_view:setText('')
        self.pending_clear = false
    else
        self.pending_clear = true
    end
    self.filter_text = nil
    self:restore_orders()
end

function OrderSearchFilter:overlay_ondisable()
    self:clear_filter()
end

OVERLAY_WIDGETS = {
    order_search_filter = OrderSearchFilter,
}

if dfhack_flags.module then
    return
end

if not dfhack.gui.matchFocusString('dwarfmode/Info/WORK_ORDERS/Default') then
    qerror('This script must be run from the Work Orders screen.')
end

overlay.overlay_command({'enable', 'order-search-filter.order_search_filter'})
