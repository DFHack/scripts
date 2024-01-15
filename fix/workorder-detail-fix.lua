--@enable = true
--@module = true
local repeatutil = require 'repeat-util'
local utils = require 'utils'
local script_name = "workorder-detail-fix"
local schedule_key = script_name..":dispatch"

enabled = enabled or false -- enabled API
function isEnabled() return enabled end

local managers = df.global.plotinfo.main.fortress_entity.assignments_by_type.MANAGE_PRODUCTION
if not managers then error("NO MANAGERS VECTOR!") end
local last_job_id = -1
local jobs_corrected = 0

-- all jobs with the NONE (-1) type in its default job_items may be a problem
local offending_jobs = {
    [df.job_type.EncrustWithGems] = true,
    [df.job_type.EncrustWithGlass] = true,
    [df.job_type.StudWith] = true,
    [df.job_type.PrepareMeal] = true,
    [df.job_type.DecorateWith] = true,
    [df.job_type.SewImage] = true,
    -- list may be incomplete
}

-- copy order.item fields/flags over to job's job_item
-- only the essentials: stuff that is editable via gui/job-details
local function correct_item_details(job_item, order_item)
    local fields = {'item_type', 'item_subtype', 'mat_type', 'mat_index'}
    for _, field in pairs(fields) do
        job_item[field] = order_item[field]
    end

    local flags_names = {'flags1', 'flags2', 'flags3', 'flags4', 'flags5'}
    for _, flags in pairs(flags_names) do
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
    local num_bugged, improve_item_index, item = 0, 1, nil
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
        -- Only SewImage has the item-to-improve at items[0]
        improve_item_index = (order_job_type ~= SewImage) and 1 or 0
        item = order.items[improve_item_index]
        if not item then goto nextorder end -- error here?
        if item.item_type == NONE then goto nextorder end
        :: fix ::
        num_bugged = num_bugged + 1
        orders[order.id] = order
        :: nextorder ::
    end
    if num_bugged == 0 then return nil end
    return orders
end

-- correct newly dispatched work order jobs
local disable
local function on_dispatch_tick()
    if df.global.cur_year_tick % 150 ~= 30 then
        print(script_name.." desynced from dispatch tick")
        repeatutil.cancel(schedule_key)
        disable(true)
    end
    if #managers == 0 then return end
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
        -- job in progress: only happens on the first run.
        -- experimental fix: remove the items and un-task them
        while #job.items ~= 0 do
            job.items[0].item.flags.in_job = false
            job.items:erase(0)
        end
        enforce_order_details(job, order)
        :: nextjob ::
    end
    last_job_id = highest
end

timeout_id = timeout_id or nil
local function schedule_handler()
    if repeatutil.cancel(schedule_key) then
        print(script_name..": canceled old dispatch handler")
    end
    repeatutil.scheduleEvery(schedule_key, 150, 'ticks', on_dispatch_tick)
    timeout_id = nil
end

local function enable(yell)
    local manager_timer = df.global.plotinfo.manager_timer
    local d = df.global.cur_year_tick
    -- it's a potential dispatch tick when tick % 150 == 30
    local time_until = (30 - d) % 150 -- + manager_timer * 150
    if time_until == 0 then
        schedule_handler()
    else
        timeout_id = dfhack.timeout(time_until, 'ticks', schedule_handler)
    end
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

-- (not working with enabled API, probably something to do with module mode)
local function status()
    local status = "DISABLED" or enabled and "ENABLED"
    print(script_name.." status: "..status.." # jobs corrected: "..tostring(jobs_corrected))
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
    print(script_name.." valid cmds: enable, disable, status")
    return
end

local cmd_table = { ['enable']=enable, ['disable']=disable, ['status']=status }

local cmd = cmd_table[args[1]:lower()]
if cmd then cmd(true) else
    print(script_name.." valid cmds: enable, disable, status")
end
