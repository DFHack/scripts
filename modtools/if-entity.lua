-- Run a command if the current entity matches a given ID.

local utils = require('utils')

local validArgs = utils.invert({
    'help',
    'id',
    'cmd',
})

local args = utils.processArgs({...}, validArgs)

if not args.id or not args.cmd or args.help then
    print(dfhack.script_help())
    return
end

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    error('emigration needs a loaded fortress map to work')
end


local entsrc = df.historical_entity.find(df.global.plotinfo.civ_id)
if not entsrc then
    error('could not find current entity')
end

if entsrc.entity_raw.code == args.id then
    dfhack.run_command(table.unpack(args.cmd))
end
