utils = require('utils')

local validArgs = utils.invert({
    'unit',
    'help',
})
local args = utils.processArgs({...}, validArgs)

if args.help then
    print(dfhack.script_help())
    return
end

local geld_args = {'-ungeld'}

if args.unit then
    table.insert(geld_args, '-unit')
    table.insert(geld_args, args.unit)
end

dfhack.run_script('geld', table.unpack(geld_args))
