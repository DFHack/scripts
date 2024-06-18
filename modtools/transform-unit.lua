-- Transforms a unit into another unit type
--author expwnent
--based on shapechange by Putnam
local usage = [====[

modtools/transform-unit
=======================
Transforms a unit into another unit type, possibly permanently.
Warning: this will crash arena mode if you view the unit on the
same tick that it transforms.  If you wait until later, it will be fine.

Arguments::

    -clear
        clear records of normal races
    -unit id
        set the target unit
    -duration ticks
        how long it should last, or "forever"
    -setPrevRace
        make a record of the previous race so that you can
        change it back with -untransform
    -keepInventory
        move items back into inventory after transformation
    -race raceName
    -caste casteName
    -suppressAnnouncement
        don't show the Unit has transformed into a Blah! event
    -untransform
        turn the unit back into what it was before

]====]
local utils = require 'utils'

normalRace = normalRace or {} --as:{race:number,caste:number}[]

local function transform(unit,race,caste)
 unit.enemy.normal_race = race
 unit.enemy.normal_caste = caste
 unit.enemy.were_race = race
 unit.enemy.were_caste = caste
end

local validArgs = utils.invert({
 'clear',
 'help',
 'unit',
 'duration',
 'setPrevRace',
 'keepInventory',
 'race',
 'caste',
 'suppressAnnouncement',
 'untransform',
})

local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end

if args.clear then
 normalRace = {}
 return
end

local unit
if args.unit then
 unit = df.unit.find(tonumber(args.unit))
else
 unit = dfhack.gui.getSelectedUnit(true)
end
if not unit then
 error 'Select or specify a valid unit'
 return
end
local unit_id = unit.id

if not args.duration then
 args.duration = 'forever'
end

local raceIndex
local race
local caste
if args.untransform then
 raceIndex = normalRace[unit_id].race
 race = df.creature_raw.find(raceIndex)
 caste = normalRace[unit_id].caste
 normalRace[unit_id] = nil
else
 if not args.race or not args.caste then
  error 'Specficy a target form.'
 end

 --find race
 for i,v in ipairs(df.global.world.raws.creatures.all) do
  if v.creature_id == args.race then
   raceIndex = i
   race = v
   break
  end
 end

 if not race then
  error 'Invalid race.'
 end

 for i,v in ipairs(race.caste) do
  if v.caste_id == args.caste then
   caste = i
   break
  end
 end

 if not caste then
  error 'Invalid caste.'
 end
end

local oldRace = unit.enemy.normal_race
local oldCaste = unit.enemy.normal_caste
if args.setPrevRace then
 normalRace[unit_id] = {}
 normalRace[unit_id].race = oldRace
 normalRace[unit_id].caste = oldCaste
end
transform(unit,raceIndex,caste,args.setPrevRace)

local inventoryItems = {} --as:df.unit_inventory_item[]

local function getInventory()
 local result = {}
 for _,item in ipairs(unit.inventory) do
  table.insert(result, item:new());
 end
 return result
end

local function restoreInventory()
 dfhack.timeout(1, 'ticks', function()
  for _,item in ipairs(inventoryItems) do
   dfhack.items.moveToInventory(item.item, unit, item.mode, item.body_part_id)
   item:delete()
  end
  inventoryItems = {}
 end)
end

if args.keepInventory then
 inventoryItems = getInventory()
end

if args.keepInventory then
 restoreInventory()
end
if args.duration and args.duration ~= 'forever' then
 --when the timeout ticks down, transform them back
 dfhack.timeout(tonumber(args.duration), 'ticks', function()
  if args.keepInventory then
   inventoryItems = getInventory()
  end
  transform(unit,oldRace,oldCaste)
  if args.keepInventory then
   restoreInventory()
  end
 end)
end
