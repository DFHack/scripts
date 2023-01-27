-- Spawn liquid on specified tile.
--@ module = true

local argparse = require('argparse')

function spawnLiquid(position, liquid_level, liquid_type)
  local map_block = dfhack.maps.getTileBlock(position)
  local tile = dfhack.maps.getTileFlags(position)

  tile.flow_size = liquid_level or 3
  tile.liquid_type = liquid_type or df.tile_liquid.Water
  tile.flow_forbid = liquid_type == df.tile_liquid.Magma or liquid_level >= 4

  map_block.flags.update_liquid = true
  map_block.flags.update_liquid_twice = true

  -- TODO: Water seems to get "stuck" for multiple seconds in air.
  local z_level = df.global.world.map_extras.z_level_flags
  z_level.update = true
  z_level.update_twice = true
end

local options, args = {
  type = nil,
  level = nil,
  position = nil,
}, {...}

local positionals = argparse.processArgsGetopt(args, {
  {'h', 'help', handler=function() options.help = true end},
  {'t', 'type', handler=function(arg) options.type = arg end, hasArg = true},
  {'l', 'level', handler=function(arg)
    options.level = argparse.positiveInt(arg, "level")
  end, hasArg = true},
  {'p', 'pos', 'position', handler=function(arg)
    options.position = argparse.coords(arg, "position")
  end, hasArg = true},
})

local function main()
  if positionals[1] == "help" or options.help then
    print(dfhack.script_help())
  end

  if options.type and df.tile_liquid[options.type] then
    options.type = df.tile_liquid[options.type]
  elseif options.type then
    qerror(([[%s is an unrecognized liquid type. Types available: Water Magma]]):format(options.type))
  else
    qerror("No liquid type specified. Use `--type <type>`")
  end

  if options.level > 7 then
    qerror("Invalid liquid level specified. Minimum of 1 and maximum of 7.")
  elseif not options.level then
    qerror("No liquid level specified. Use `--level <level>`")
  end

  if not options.position then
    qerror("No position specified. Use `--position [ <x> <y> <z> ]")
  end

  spawnLiquid(options.position, options.level, options.type)
end

if not dfhack_flags.module then
  main()
end
