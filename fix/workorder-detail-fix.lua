--@enable = true
--@module = true
local script_name = "workorder-detail-fix"
local eventful = require 'plugins.eventful'
local repeatutil = require 'repeat-util'

-- must be frequent enough to catch new orders before any jobs get dispatched
order_check_period = order_check_period or 300
job_check_period = job_check_period or 0 -- might be overkill

-- these are only for debug/printing status
handler_ref = handler_ref or nil
handler_armed = handler_armed or false
checking_orders = checking_orders or false

enabled = enabled or false -- "enabled API" stuff
function isEnabled() return enabled end

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
        if type(order_flags) == "number" then
            job_item[flags] = order_flags
        else -- copy over the flags one by one
            for o_flag, val in pairs(order_flags) do
                job_item[flags][o_flag] = val
            end
        end
    end
end

-- correct each job as it's initialized
-- this is the handler, running after the job is dispatched
local function enforce_order_details(job)
    if not job.job_items then return end -- never happens (error here?)
    local order_id = job.order_id -- only jobs with an ORDER ID
    if (order_id == -1) or (order_id == nil) then return end

    -- only jobs with the item type issue. encrusting, sewing, cooking, etc.
    if not offending_jobs[job.job_type] then return end

    local order = nil -- get the order ref from order id
    for _, ord in ipairs(df.global.world.manager_orders) do
        if ord.id == order_id then order = ord; break end
    end

    if not order then return end -- oops, no order
    if not order.items then return end -- no order item details to enforce

    -- copy the item details over when the types don't match
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
            else --[[ error on unsuitable item?]] end
        end
    end
end

local function arm_job_handler()
    -- set eventful onJobInitiated handler to run every tick (frequency 0)
    -- NOTE: this affects every other script using this eventful handler.
    eventful.enableEvent(eventful.eventType.JOB_INITIATED, job_check_period)
    eventful.onJobInitiated.workorder_detail_fix = enforce_order_details
    handler_ref = eventful.onJobInitiated.workorder_detail_fix
    handler_armed = true
end

local function disarm_job_handler()
    --[[ would undo the onJobInitiated frequency here, but eventful has no way
    to set a less frequent check- only a more frequent one.
    having a PERMANENT side effect is not ideal but perhaps it should be taken
    up with eventful.cpp ]]
    eventful.onJobInitiated.workorder_detail_fix = nil
    handler_ref = nil
    handler_armed = false
end

local PrepareMeal = df.job_type.PrepareMeal
local SewImage = df.job_type.SewImage
local NONE = df.job_type.NONE

--[[ return true if order list contains an order that would trigger the bug.
it only happens when item types clash with an expected default of "any"/NONE,
so this is the only case it checks for. ]]
local function detail_fix_is_needed()
    for _, order in ipairs(df.global.world.manager_orders) do
        if not order.items then goto nextorder end

        local order_job_type = order.job_type
        if not offending_jobs[order_job_type] then goto nextorder end
        if #order.items == 0 then goto nextorder end -- doesn't happen

        -- for PrepareMeal jobs, any one of the items could be an issue.
        if order_job_type == PrepareMeal then
            for _, item in ipairs(order.items) do
                if item.item_type ~= NONE then return true end
            end
            goto nextorder
        end

        -- All other types are improve jobs. only the improved item is checked
        local job_item_index = 1
         -- Only SewImage has the item-to-improve at items[0]
        if order_job_type == SewImage then job_item_index = 0 end

        local item = order.items[job_item_index]

        -- only happens if someone has really mangled an order. deleted items,
        -- switch positions, etc. gui/job-details doesn't let this happen.
        if not item then goto nextorder end

        if item.item_type ~= NONE then return true end
        :: nextorder ::
    end
    return false
end

local schedule_key = "workorder_detail_fix_order_check"
local function disable_order_checking()
    repeatutil.cancel(schedule_key)
    checking_orders = false
end

-- checks orders for bug periodically & enables the main fix when applicable,
-- mainly to avoid setting unnecessary handlers
local function enable(yell)
    -- embedded func could be factored out if we want to allow other
    -- scripts to check. eg after importing orders, or modifying an order
    checking_orders = true
    repeatutil.scheduleEvery( schedule_key, order_check_period, "ticks",
        function()
            if detail_fix_is_needed() then
                arm_job_handler()
                disable_order_checking()
            end
        end )
    enabled = true
    if yell then print(script_name.." ENABLED") end
end

local function disable(yell)
    disable_order_checking()
    disarm_job_handler()
    enabled = false
    if yell then print(script_name.." DISABLED") end
end

-- mostly for debugging. maybe could print the # of jobs corrected
local function status()
    local status = "DISABLED"
    if checking_orders then status = "ENABLED (Checking orders)" end
    if handler_armed then status = "ENABLED (Handling jobs)" end
    local extralines = {}; local num_err = 0
    local function err(msg, ...)
        num_err = num_err + 1; status = ("ERROR (%d)"):format(num_err)
        table.insert(extralines, msg:format(...))
    end
    -- may become non-error if we want to get more dynamic with toggling
    if checking_orders and handler_armed then
        err("checking orders and handling jobs at the same time?")
    end
    local order_check_scheduled = repeatutil.repeating[schedule_key] ~= nil
    if checking_orders ~= order_check_scheduled then
        err( "%s we are checking orders but %s that a check is scheduled",
            checking_orders, order_check_scheduled )
    end
    local handler = eventful.onJobInitiated.workorder_detail_fix
    if handler_armed ~= (handler ~= nil) then
        err( "%s that job handler should be armed but %s that one exists",
            handler_armed, handler ~= nil )
    end
    if not handler == handler_ref then
        err( "job handler: %s\ndoesn't match stored handler: %s",
            handler, handler_ref )
    end
    print(script_name.." status: "..status)
    for idx, message in pairs(extralines) do print(idx, message) end
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

local cmd_table = { ["enable"]=enable, ["disable"]=disable, ["status"]=status }

local cmd = cmd_table[args[1]:lower()]
if cmd then cmd(true) else
    print(script_name.." valid cmds: enable, disable, status")
end
