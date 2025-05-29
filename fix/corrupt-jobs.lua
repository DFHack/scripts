-- Deletes corrupted jobs from affected units
--@module = true

local GLOBAL_KEY = 'corrupt-jobs'

function remove_bad_jobs()
    local count = 0

    for _, unit in ipairs(df.global.world.units.active) do
        if unit.job.current_job and unit.job.current_job.id == -1 then
            unit.job.current_job = nil
            count = count + 1
        end
    end

    if count > 0 then
        print(('removed %d corrupted job(s) from affected units'):format(count))
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_LOADED then
        remove_bad_jobs()
    end
end

if dfhack_flags.module then
    return
end

-- allow the player to run it manually if they want to
remove_bad_jobs()
