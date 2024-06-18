-- runs dfhack commands unless ran already in this save (world)

local argparse = require('argparse')

local GLOBAL_KEY = 'once-per-save'

local opts = {
    help=false,
    rerun=false,
    reset=false,
}

local positionals = argparse.processArgsGetopt({...}, {
    {'h', 'help', handler=function() opts.help = true end},
    {nil, 'rerun', handler=function() opts.rerun = true end},
    {nil, 'reset', handler=function() opts.reset = true end},
})

if opts.help or positionals[1] == 'help' then
    print(dfhack.script_help())
    return
end

if opts.reset then
    dfhack.persistent.deleteWorldData(GLOBAL_KEY)
end
if #positionals == 0 then return end

local state = dfhack.persistent.getWorldData(GLOBAL_KEY, {})

for cmd in table.concat(args, ' '):gmatch("%s*([^;]+);?%s*") do
    cmd = cmd:trim()
    if not state[cmd] or opts.rerun then
        if dfhack.run_command(cmd) == CR_OK then
            state[cmd] = {already_run=true}
        end
    end
end

dfhack.persistent.saveWorldData(GLOBAL_KEY, state)
