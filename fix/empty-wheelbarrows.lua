-- checks all wheelbarrows on map for rocks stuck in them and empties such rocks onto the ground. If a wheelbarrow
-- isn't in use for a job (hauling) then there should be no rocks in them.

local argparse = require("argparse")

local quiet = false
local dryrun = false

argparse.processArgsGetopt({...}, {
    {'q', 'quiet', handler=function() quiet = true end},
    {'d', 'dry-run', handler=function() dryrun = true end},
})

local i_count = 0
local e_count = 0

local function emptyContainedItems(wheelbarrow, outputCallback)
    local items = dfhack.items.getContainedItems(wheelbarrow)
    if #items == 0 then return end
    outputCallback('Emptying wheelbarrow: ' .. dfhack.items.getReadableDescription(wheelbarrow))
    e_count = e_count + 1
    for _,item in ipairs(items) do
        outputCallback('  ' .. dfhack.items.getReadableDescription(item))
        if not dryrun then
            if item.flags.in_job then
                local job_ref = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
                if job_ref then
                    dfhack.job.removeJob(job_ref.data.job)
                end
            end
            dfhack.items.moveToGround(item, wheelbarrow.pos)
        end
        i_count = i_count + 1
    end
end

local function emptyWheelbarrows(outputCallback)
    for _,item in ipairs(df.global.world.items.other.TOOL) do
        -- wheelbarrow must be on ground and not in a job
        if ((not item.flags.in_job) and item.flags.on_ground and item:isWheelbarrow()) then
           emptyContainedItems(item, outputCallback)
        end
    end
end

local output
if (quiet) then output = (function(...) end) else output = print end

emptyWheelbarrows(output)

if i_count > 0 or not quiet then
    local action = dryrun and 'would remove' or 'removed'
    print(("fix/empty-wheelbarrows - %s %d item(s) from %d wheelbarrow(s)."):format(action, i_count, e_count))
end
