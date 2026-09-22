-- Watches unit job assignments and reports transitions in the console
--@ enable = true
--[====[

devel/jobwatch
==============
Watches ``unit.job.current_job`` for all units in ``world.units.active``
and prints a line whenever a unit gains, loses, or switches jobs —
including switches between two jobs of the same type, which is how
claim races (a unit losing its target posting to another unit) appear.

Useful for observing job churn that is otherwise invisible: the
assignment auction runs inside the tick and can only be seen through
its effects on ``current_job``.

:enable|start:   Begin watching
:disable|stop:   Stop watching
:unit <id>|all:  Only report transitions for one unit id (or all units)
:verbose:        Also print each job's posting index and flags
]====]

active = active or false
filter_unit = filter_unit or nil --as:number
verbose = verbose or false
last_jobs = last_jobs or {} --as:{[number]:{id:number,desc:string}}

local function describe(unit)
    local job = unit.job.current_job
    if not job then return -1, 'none' end
    local s = df.job_type[job.job_type] or ('?type ' .. job.job_type)
    if verbose then
        s = ('%s [id=%d posting=%d do_now=%s special=%s]'):format(
            s, job.id, job.posting_index,
            tostring(job.flags.do_now), tostring(job.flags.special))
    end
    return job.id, s
end

local function check()
    local seen = {}
    for _, unit in ipairs(df.global.world.units.active) do
        local id, desc = describe(unit)
        seen[unit.id] = {id=id, desc=desc}
        local prev = last_jobs[unit.id]
        if prev and prev.id ~= id
                and (not filter_unit or unit.id == filter_unit) then
            print(('%d unit %d %s: %s -> %s'):format(
                df.global.cur_year_tick, unit.id,
                dfhack.df2console(dfhack.units.getReadableName(unit)),
                prev.desc, desc))
        end
    end
    last_jobs = seen
    if active then
        dfhack.timeout(1, 'ticks', check)
    end
end

local args = {...}
if dfhack_flags and dfhack_flags.enable then
    table.insert(args, dfhack_flags.enable_state and 'enable' or 'disable')
end

local cmd = args[1]
if cmd == 'enable' or cmd == 'start' then
    if not active then
        active = true
        dfhack.timeout(1, 'ticks', check)
    end
elseif cmd == 'disable' or cmd == 'stop' then
    active = false
elseif cmd == 'unit' then
    filter_unit = (args[2] == 'all') and nil or tonumber(args[2])
    print('jobwatch: unit filter = ' .. tostring(filter_unit or 'all'))
elseif cmd == 'verbose' then
    verbose = not verbose
    print('jobwatch: verbose = ' .. tostring(verbose))
else
    print(dfhack.script_help())
end
