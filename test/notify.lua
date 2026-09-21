config = {
    target = 'gui/notify',
    mode = 'fortress',
}

local notifications = reqscript('internal/notify/notifications')

local all_mandates = df.global.world.mandates.all

-- mandate.timeout_counter increments once per 10 frames
local NEAR_THRESHOLD = 2500 -- ~3 weeks
local EARLY_THRESHOLD = 10080 -- 3 months

local function add_mandate(remaining)
    local m = df.mandate:new()
    m.mode = df.mandate_type.Make
    m.timeout_counter = 0
    m.timeout_limit = remaining
    all_mandates:insert('#', m)
end

local function remove_added_mandates(orig_size)
    for i = #all_mandates - 1, orig_size, -1 do
        all_mandates:erase(i)
    end
end

local function window_count(remaining)
    local count = 0
    for _, m in ipairs(all_mandates) do
        if m.mode == df.mandate_type.Make and
            m.timeout_limit - m.timeout_counter < remaining
        then
            count = count + 1
        end
    end
    return count
end

local function expected_msg(count, suffix)
    if count == 0 then return nil end
    return ('%d production mandate%s %s'):format(
        count, count == 1 and '' or 's', suffix)
end

local function expect_mandate_msgs(near_count, early_count)
    local near = notifications.NOTIFICATIONS_BY_NAME.mandates_expiring
    local early = notifications.NOTIFICATIONS_BY_NAME.mandates_expiring_early
    expect.eq(expected_msg(near_count, 'near deadline'), near.dwarf_fn())
    expect.eq(expected_msg(early_count, 'expire within 3 months'),
              early.dwarf_fn())
end

function test.mandates_expiring()
    local orig_size = #all_mandates
    return dfhack.with_finalize(
        function() remove_added_mandates(orig_size) end,
        function()
            -- the fort may already have real mandates; measure baselines
            local base_near = window_count(NEAR_THRESHOLD)
            local base_early = window_count(EARLY_THRESHOLD)

            expect_mandate_msgs(base_near, base_early)

            -- ~1.5 months remaining: early notification only
            add_mandate(5000)
            expect_mandate_msgs(base_near, base_early + 1)

            -- ~8 days remaining: both notifications
            add_mandate(1000)
            expect_mandate_msgs(base_near + 1, base_early + 2)

            -- ~4.5 months remaining: neither notification
            add_mandate(15000)
            expect_mandate_msgs(base_near + 1, base_early + 2)
        end)
end
