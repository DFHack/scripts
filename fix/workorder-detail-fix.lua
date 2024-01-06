--@enable = true
--@module = true
local script_name = "workorder-detail-fix"
local eventful = require 'plugins.eventful'
if not handler_ref then local handler_ref = nil end

enabled = enabled or false
function isEnabled()
    return enabled
end

-- all jobs with the "any" (-1) type in its default job_items may be a problem
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

local function enable()
    print(script_name.." ENABLED")
    -- set eventful onJobInitiated handler to run every tick (frequency 0)
    eventful.enableEvent(eventful.eventType.JOB_INITIATED, 0)
    eventful.onJobInitiated.workorder_detail_fix = enforce_order_details
    handler_ref = eventful.onJobInitiated.workorder_detail_fix
end

local function disable()
    print(script_name.." DISABLED")
    eventful.onJobInitiated.workorder_detail_fix = nil
    handler_ref = nil
end

local function status()
    local status = "DISABLED"
    local handler = eventful.onJobInitiated.workorder_detail_fix
    if handler ~= nil then
        -- ensure the handler still matches the one copied back from eventful
        if handler == handler_ref then
            status = "ENABLED"
        else
            status = "ERROR: Handler overwritten!"
            print("why is this here:", handler)
            print("should be", handler_ref)
        end
    end
    print(script_name.." status: "..status)
end

-- check if script was called by enable API
if dfhack_flags.enable then 
    if dfhack_flags.enable_state then 
        enable(); enabled = true
    else
        disable(); enabled = false
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
if cmd then cmd() else
    print(script_name.." valid cmds: enable, disable, status")
end