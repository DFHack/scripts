-- Suspend all construction jobs

local utils = require('utils')
local argparse = require('argparse')

local help = false
argparse.processArgsGetopt({...}, {
    {'h', 'help', handler=function() help = true end},
})

---cancel job and remove worker
---@param job df.job
local function suspend(job)
    job.flags.suspend = true
    job.flags.working = false
    dfhack.job.removeWorker(job, 0);
end


if help then
    print(dfhack.script_help())
    return
end

for _,job in utils.listpairs(df.global.world.jobs.list) do
    if job.job_type == df.job_type.ConstructBuilding then
        suspend(job)
    end
end
