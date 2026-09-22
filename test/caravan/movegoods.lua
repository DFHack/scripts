config = {
    mode = 'fortress',
    target = 'caravan',
}

local movegoods = reqscript('internal/caravan/movegoods')
local common = reqscript('internal/caravan/common')
local mock = require('test_util.mock')

local function get_depot()
    for _, b in ipairs(df.global.world.buildings.all) do
        if df.building_tradedepotst:is_instance(b) then return b end
    end
end

local function expected_pending(w)
    local pending = w.pending_item_ids
    local sum = 0
    for item_id, item in pairs(w.items_by_id) do
        local marked = w.marked[item_id]
        if marked == nil then
            marked = not not pending[item_id] or item.flags.in_building
        end
        if marked then
            sum = sum + (w.item_values[item_id] or 0)
        end
    end
    return sum
end

local function find_choice(w, item_id)
    for _, choices in pairs(w.choices_cache) do
        for _, choice in ipairs(choices) do
            if choice.data.items[item_id] then return choice end
        end
    end
end

local function run_check()
    local depot = get_depot() or {centerx=0, centery=0, z=0, contained_items={}}
    local ids = {}
    for _, item in ipairs(df.global.world.items.other.IN_PLAY) do
        if common.get_perceived_value(item) > 0 then ids[item.id] = true end
    end
    if not next(ids) then return end
    local w = movegoods.MoveGoods{pending_item_ids=ids, depot=depot}
    for _, inside in ipairs{false, true} do
        for _, group in ipairs{false, true} do
            w.subviews.inside_containers:setOption(inside and 'Yes' or 'No')
            w.subviews.group_items:setOption(group and 'Yes' or 'No')
            w:cache_choices()
            expect.eq(expected_pending(w), w.value_pending)
        end
    end
    return w
end

function test.value_pending_not_doubled_by_cache_builds()
    run_check()
end

function test.marks_persist_across_filter_views()
    local w = run_check()
    if not w then return end
    -- mark a non-container item (those appear in every filter view)
    local marked_id
    for _, choice in ipairs(w.choices_cache[1]) do
        for item_id, item_data in pairs(choice.data.items) do
            if not df.item_binst:is_instance(item_data.item)
                    and not item_data.item:isFoodStorage() then
                marked_id = item_id
                break
            end
        end
        if marked_id then break end
    end
    if not marked_id then return end
    local choice = find_choice(w, marked_id)
    w:toggle_item_base(choice, true)
    expect.true_(w.marked[marked_id])
    -- rebuild every view and verify the mark propagated
    for idx in pairs(w.choices_cache) do w.choices_cache[idx] = nil end
    for _, inside in ipairs{false, true} do
        for _, group in ipairs{false, true} do
            w.subviews.inside_containers:setOption(inside and 'Yes' or 'No')
            w.subviews.group_items:setOption(group and 'Yes' or 'No')
            w:cache_choices()
            local c = find_choice(w, marked_id)
            if c then expect.true_(c.data.items[marked_id].pending) end
        end
    end
end
