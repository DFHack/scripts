-- teleports a unit to a location
-- author Putnam
-- edited by expwnent
--@module = true

local guidm = require('gui.dwarfmode')

function teleport(unit,pos)
 dfhack.units.teleport(unit, pos)
end

local utils = require('utils')

local validArgs = utils.invert({
 'unit',
 'x',
 'y',
 'z',
 'showunitid',
 'showpos'
})

if moduleMode then
 return
end

local args = utils.processArgs({...}, validArgs)

if args.showunitid or args.showpos then
 if args.showunitid then
  print(dfhack.gui.getSelectedUnit(true).id)
 else
  printall(guidm.getCursorPos())
 end
else
 local unit = tonumber(args.unit) and df.unit.find(tonumber(args.unit)) or dfhack.gui.getSelectedUnit(true)
 local pos = not(not args.x or not args.y or not args.z) and {x=args.x,y=args.y,z=args.z} or guidm.getCursorPos()
 if not unit then qerror('A unit needs to be selected or specified. Use teleport -showunitid to get a unit\'s ID.') end
 if not pos then qerror('A position needs to be highlighted or specified. Use teleport -showpos to get a position\'s exact xyz values.') end
 teleport(unit,pos)
end
