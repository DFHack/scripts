--@enable = true
--@module = true
local repeatutil = require 'repeat-util'
local utils = require 'utils'
local script_name = "fix/workorder-details"
local schedule_key = script_name..":dispatch"

enabled = enabled or false -- enabled API
function isEnabled() return enabled end

local last_job_id = -1
jobs_corrected = jobs_corrected or 0

-- all jobs with the NONE (-1) type in its default job_items may be a problem
local offending_jobs = utils.invert({
    df.job_type.EncrustWithGems,
    df.job_type.EncrustWithGlass,
    df.job_type.StudWith,
    df.job_type.PrepareMeal,
    df.job_type.DecorateWith,
    df.job_type.SewImage,
    -- list may be incomplete
})

-- copy order.item fields/flags over to job's job_item
-- only the essentials: stuff that is editable via gui/job-details
local function correct_item_details(job_item, order_item)
    local fields = {'item_type', 'item_subtype', 'mat_type', 'mat_index'}
    for _, field in ipairs(fields) do
        job_item[field] = order_item[field]
    end

    local flags_names = {'flags1', 'flags2', 'flags3', 'flags4', 'flags5'}
    for _, flags in ipairs(flags_names) do
        local order_flags = order_item[flags]
        if type(order_flags) == 'number' then
            job_item[flags] = order_flags
        else
            job_item[flags].whole = order_flags.whole
        end
    end
end

-- correct job's job_items to match the order's
local function enforce_order_details(job, order)
    if not job.job_items then return end -- never happens (error here?)
    local modified = false
    for idx, job_item in ipairs(job.job_items) do
        local order_item = order.items[idx]
        if not order_item then break end -- never happens (error here?)
        if job_item.item_type ~= order_item.item_type then
            -- dfhack's isSuitableItem function will allow the orders we want,
            -- but disallow insane combinations like meals made of shoes
            local suitable = dfhack.job.isSuitableItem(
                job_item, order_item.item_type, order_item.item_subtype )
            if suitable then
                correct_item_details(job_item, order_item)
                modified = true
            else --[[ error on unsuitable item?]] end
        end
    end
    if modified then jobs_corrected = jobs_corrected + 1 end
end

-- check orders list to see if fix is needed
-- yields id-order table for the orders with issues, or nil when no issues
local PrepareMeal = df.job_type.PrepareMeal
local SewImage = df.job_type.SewImage
local NONE = df.job_type.NONE
local function get_bugged_orders()
    local orders = {}
    local num_bugged = 0
    for _, order in ipairs(df.global.world.manager_orders) do
        if not order.items then goto nextorder end
        local order_job_type = order.job_type
        if not offending_jobs[order_job_type] then goto nextorder end
        if #order.items == 0 then goto nextorder end -- doesn't happen

        -- for PrepareMeal jobs, any one of the items could be an issue.
        if order_job_type == PrepareMeal then
            for _, _item in ipairs(order.items) do
                if _item.item_type ~= NONE then goto fix end
            end
            goto nextorder
        end

        -- All other types are improve jobs; only the improved item is checked
        do
            -- Only SewImage has the item-to-improve at items[0]
            local improve_item_index = (order_job_type == SewImage) and 0 or 1
            local item = order.items[improve_item_index]
            if not item then goto nextorder end -- error here?
            if item.item_type == NONE then goto nextorder end
        end
        :: fix ::
        num_bugged = num_bugged + 1
        orders[order.id] = order
        :: nextorder ::
    end
    if num_bugged == 0 then return nil end
    return orders
end

-- correct newly dispatched work order jobs
local disable, schedule_handler
local function on_dispatch_tick()
    if not dfhack.units.getUnitByNobleRole('manager') then return end
    if df.global.plotinfo.manager_timer ~= 10 then return end
    local orders = get_bugged_orders()
    if not orders then return end -- no bugs to fix

    local highest = last_job_id
    for _, job in utils.listpairs(df.global.world.jobs.list) do
        if job.id <= last_job_id then goto nextjob end
        highest = math.max(job.id, highest)
        if job.order_id == -1 then goto nextjob end
        local order = orders[job.order_id]
        if not order then goto nextjob end -- order wasn't bugged
        -- skip jobs with items already gathered
        if job.items and (#job.items > 0) then goto nextjob end
        enforce_order_details(job, order)
        :: nextjob ::
    end
    last_job_id = highest

    if df.global.cur_year_tick % 150 ~= 30 then
        print(script_name..": lost sync with dispatch tick. Resetting...")
        schedule_handler()
    end
end

timeout_id = timeout_id or nil
local function start_handler()
    repeatutil.scheduleEvery(schedule_key, 150, 'ticks', on_dispatch_tick)
    timeout_id = nil
end

function schedule_handler()
    local manager_timer = df.global.plotinfo.manager_timer
    local d = df.global.cur_year_tick
    -- it's a potential dispatch tick when tick % 150 == 30
    local time_until = (30 - d) % 150 -- + manager_timer * 150
    if time_until == 0 then
        start_handler()
    else
        timeout_id = dfhack.timeout(time_until, 'ticks', start_handler)
    end
end

local function enable(yell)
    jobs_corrected = 0
    schedule_handler()
    enabled = true
    if yell then print(script_name.." ENABLED") end
end

function disable(yell)
    if timeout_id then
        dfhack.timeout_active(timeout_id, nil)
        timeout_id = nil
    end
    repeatutil.cancel(schedule_key)
    enabled = false
    if yell then print(script_name.." DISABLED") end
end

local function status()
    local status = enabled and "Enabled" or "Disabled"
    if enabled then
        status = status..". Jobs corrected: "..tostring(jobs_corrected)
    end
    print(script_name.." status: "..status)
end

-- check if script was called by enable API
if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        enable(false)
    else
        disable(false)
    end
    return
end

if dfhack_flags.module then return end

-- check the arguments
local args={...}

if not args[1] then
    status()
    return
end

local cmd_table = { ['enable']=enable, ['disable']=disable, ['status']=status }

local cmd = cmd_table[args[1]:lower()]
if cmd then cmd(true) else
    print(script_name.." valid cmds: enable, disable, status")
end
