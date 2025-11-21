-- Allow haulers to pick up multiple nearby items when using wheelbarrows
--@module = true
--@enable = true

local eventful = require('plugins.eventful')
local utils = require('utils')
local itemtools = reqscript('item')

local GLOBAL_KEY = 'multihaul'

local finish_jobs_without_wheelbarrow

local function get_default_state()
    return {
        enabled=false,
        debug_enabled=false,
        radius=10,
        wheelbarrow_search_radius_k=5,
        max_items=10,
        mode='sametype',
        autowheelbarrows=true
    }
end

state = state or get_default_state()

function isEnabled()
    return state.enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, state)
end

local function load_state()
    state = get_default_state()
    utils.assign(state, dfhack.persistent.getSiteData(GLOBAL_KEY, state))
end

local function for_each_item_in_radius(x, y, z, radius, fn)
    local xmin = math.max(0, x - radius)
    local xmax = math.min(df.global.world.map.x_count - 1, x + radius)
    local ymin = math.max(0, y - radius)
    local ymax = math.min(df.global.world.map.y_count - 1, y + radius)
    local bxmin, bxmax = math.floor(xmin/16), math.floor(xmax/16)
    local bymin, bymax = math.floor(ymin/16), math.floor(ymax/16)
    for by = bymin, bymax do
        for bx = bxmin, bxmax do
            local block = dfhack.maps.getTileBlock(bx*16, by*16, z)
            if block then
                for _, id in ipairs(block.items) do
                    local item = df.item.find(id)
                    if item and fn(item) then return end
                end
            end
        end
    end
end

local function get_job_stockpile(job)
    local ref = dfhack.job.getGeneralRef(job, df.general_ref_type.BUILDING_HOLDER)
    return ref and df.building.find(ref.building_id) or nil
end

local function items_identical(a, b)
    return a:getType() == b:getType() and a:getSubtype() == b:getSubtype() and
        a.mat_type == b.mat_type and a.mat_index == b.mat_index
end

local function items_sametype(a, b)
    return a:getType() == b:getType()
end

local function items_samesubtype(a, b)
    return a:getType() == b:getType() and a:getSubtype() == b:getSubtype()
end

local match_fns = {
    any = function() return true end,
    identical = items_identical,
    sametype = items_sametype,
    samesubtype = items_samesubtype,
}

local function items_match(a, b)
    local fn = match_fns[state.mode] or match_fns.sametype
    return fn(a, b)
end

local function emptyContainedItems(wheelbarrow)
    local items = dfhack.items.getContainedItems(wheelbarrow)
    if #items == 0 then return end

    if state.debug_enabled then
        dfhack.gui.showAnnouncement('multihaul: emptying wheelbarrow', COLOR_CYAN)
    end

    for _, item in ipairs(items) do
        if item.flags.in_job then
            local job_ref = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
            if job_ref then
                dfhack.job.removeJob(job_ref.data.job)
            end
        end
        dfhack.items.moveToGround(item, wheelbarrow.pos)
    end
    finish_jobs_without_wheelbarrow()
end

local function add_nearby_items(job)
    if #job.items == 0 then return end

    local target = job.items[0].item
    if not target then return end
    local stockpile = get_job_stockpile(job)
    if not stockpile then return end
    local x,y,z = dfhack.items.getPosition(target)
    if not x then return end

    local cond = {}
    itemtools.condition_stockpiled(cond)
    local is_stockpiled = cond[1]

    local function matches(it)
        return items_match(it, target)
    end

    local count = 0
    for_each_item_in_radius(x, y, z, state.radius, function(it)
        if it ~= target and not it.flags.in_job and it.flags.on_ground and not it.flags.forbid and 
                not it:isWheelbarrow() and not dfhack.items.isRouteVehicle(it) and
                not is_stockpiled(it) and matches(it) then
            dfhack.job.attachJobItem(job, it, df.job_role_type.Hauled, -1, -1)
            count = count + 1
            if state.debug_enabled then
                dfhack.gui.showAnnouncement(
                    ('multihaul: added %s to hauling job of %s'):format(
                        dfhack.items.getDescription(it, 0), dfhack.items.getDescription(target, 0)),
                    COLOR_CYAN)
            end
            if count >= state.max_items then return true end
        end
    end)
end

local function find_attached_wheelbarrow(job)
    for _, jitem in ipairs(job.items) do
        local item = jitem.item
        if item and item:isWheelbarrow() then
            if jitem.role ~= df.job_role_type.PushHaulVehicle then
                return 'badrole'
            end
            local ref = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
            if ref and ref.data.job == job then
                return item
            end
        end
    end
    return nil
end

local function find_free_wheelbarrow(stockpile)
    if not df.building_stockpilest:is_instance(stockpile) then return nil end
    local sx, sy, sz = stockpile.centerx, stockpile.centery, stockpile.z
    local found
    for_each_item_in_radius(sx, sy, sz, state.radius*state.wheelbarrow_search_radius_k or 10*state.wheelbarrow_search_radius_k, function(it)
        if it:isWheelbarrow() and not it.flags.in_job then
            found = it
            return true
        end
    end)
    return found
end


local function attach_free_wheelbarrow(job)
    local stockpile = get_job_stockpile(job)
    if not stockpile then return nil end
    local wheelbarrow = find_free_wheelbarrow(stockpile)
    if not wheelbarrow then return nil end
    if dfhack.job.attachJobItem(job, wheelbarrow,
            df.job_role_type.PushHaulVehicle, -1, -1) then
        if state.debug_enabled then
            dfhack.gui.showAnnouncement('multihaul: adding wheelbarrow to a job', COLOR_CYAN)
        end
        return wheelbarrow
    end
end

function finish_jobs_without_wheelbarrow()
    local count = 0
    for _, job in utils.listpairs(df.global.world.jobs.list) do
        if job.job_type == df.job_type.StoreItemInStockpile and #job.items > 1 and not find_attached_wheelbarrow(job) then
            for _, jobitem in ipairs(job.items) do
                local item = jobitem.item
                if item and item.flags.in_job then
                    local ref = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
                    if ref and ref.data.job == job then
                        dfhack.job.removeJob(job)
                    end
                end
            end
            job.items:resize(0)
            job.completion_timer = 0
            count = count + 1
        end
    end
    if count > 0 then
    dfhack.gui.showAnnouncement('multihaul: clearing stuck hauling job', COLOR_CYAN)
    end
end

local function on_new_job(job)
    if job.job_type ~= df.job_type.StoreItemInStockpile then return end
    local wheelbarrow = find_attached_wheelbarrow(job)
    if wheelbarrow == 'badrole' then return
    end
    if not wheelbarrow and state.autowheelbarrows then
        wheelbarrow = attach_free_wheelbarrow(job)
    end
    if not wheelbarrow then return end
    add_nearby_items(job)
    emptyContainedItems(wheelbarrow)
end

local function enable(val)
    state.enabled = val
    if state.enabled then
        eventful.onJobInitiated[GLOBAL_KEY] = on_new_job
    else
        eventful.onJobInitiated[GLOBAL_KEY] = nil
    end
    persist_state()
end

if dfhack.internal.IN_TEST then
    unit_test_hooks = {on_new_job=on_new_job, enable=enable,
                       load_state=load_state}
end

-- state change handler

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        state.enabled = false
        eventful.onJobInitiated[GLOBAL_KEY] = nil
        return
    end
    if sc == SC_MAP_LOADED then
        load_state()
    end
end

if dfhack_flags.module then
    return
end

local args = {...}
if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        enable(true)
    else
        enable(false)
    end
    return
end

local function parse_options(start_idx)
    local i = start_idx
    while i <= #args do
        local a = args[i]
        if a == '--debug' then
            local m = args[i + 1]
            if m == 'off' or m == 'disable' then
                state.debug_enabled = false
                i = i + 1
            else
                state.debug_enabled = true
            end
        elseif a == '--autowheelbarrows' then
            local m = args[i + 1]
            if m == 'on' or m == 'enable' then
                state.autowheelbarrows = true
                i = i + 1
            elseif m == 'off' or m == 'disable' then
                state.autowheelbarrows = false
                i = i + 1
            else
                qerror('invalid autowheelbarrows option: ' .. tostring(m))
            end
        elseif a == '--radius' then
            i = i + 1
            state.radius = tonumber(args[i]) or state.radius
        elseif a == '--max-items' then
            i = i + 1
            state.max_items = tonumber(args[i]) or state.max_items
        elseif a == '--mode' then
            i = i + 1
            local m = args[i]
            if m == 'any' or m == 'sametype' or m == 'samesubtype' or m == 'identical' then
                state.mode = m
            else
                qerror('invalid mode: ' .. tostring(m))
            end
        end
        i = i + 1
    end
end

local cmd = args[1]
if cmd == 'enable' then
    parse_options(2)
    enable(true)
elseif cmd == 'disable' then
    enable(false)
elseif cmd == 'status' or not cmd then
    print((state.enabled and 'multihaul is enabled' or 'multihaul is disabled'))
    print(('radius=%d max-items=%d mode=%s autowheelbarrows=%s debug=%s')
          :format(state.radius, state.max_items, state.mode, state.autowheelbarrows and 'on' or 'off', state.debug_enabled and 'on' or 'off'))
elseif cmd == 'config' then
    parse_options(2)
    persist_state()
    print(('multihaul config: radius=%d max-items=%d mode=%s autowheelbarrows=%s debug=%s')
          :format(state.radius, state.max_items, state.mode, state.autowheelbarrows and 'on' or 'off', state.debug_enabled and 'on' or 'off'))
elseif cmd == 'unstuckjobs' then
    finish_jobs_without_wheelbarrow()
else
    qerror('Usage: multihaul [enable|disable|status|config|unstuckjobs] [--radius N] [--max-items N] [--mode MODE] [--autowheelbarrows on|off] [--debug on|off]')
end
