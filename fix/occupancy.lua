local argparse = require('argparse')
local plugin = require('plugins.fix-occupancy')

local opts = {
    dry_run=false,
}

local positionals = argparse.processArgsGetopt({...}, {
    { 'h', 'help', handler = function() opts.help = true end },
    { 'n', 'dry-run', handler = function() opts.dry_run = true end },
})

if positionals[1] == 'help' or opts.help then
    print(dfhack.script_help())
    return
end

if not positionals[1] then
    plugin.fix_map(opts.dry_run)
else
    plugin.fix_tile(argparse.coords(positionals[1], 'pos'), opts.dry_run)
end
