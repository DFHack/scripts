-- Forces an event (caravan, migrants, etc)
-- author Putnam
-- edited by expwnent
local help = [====[

modtools/force
==============
This tool triggers events like megabeasts, caravans, and migrants.

Usage::

    -eventType event
        specify the type of the event to trigger
        examples:
            Megabeast
            Migrants
            Caravan
            Diplomat
            WildlifeCurious
            WildlifeMischievous
            WildlifeFlier
            NightCreature
    -civ entity
        specify the civ of the event, if applicable
        examples:
            player
            MOUNTAIN
            EVIL
            28

]====]
local utils = require 'utils'

local function findCiv(arg)
 local entities = df.global.world.entities.all
 if tonumber(arg) then return df.historical_entity.find(tonumber(arg)) end
 if arg then
  for eid,entity in ipairs(entities) do
   if entity.entity_raw.code == arg then return entity end
  end
 end
 return nil
end

local validArgs = utils.invert({
 'eventType',
 'help',
 'civ'
})

local args = utils.processArgs({...}, validArgs)
if args.help then
 print(help)
 print('force: -eventType [Megabeast, Migrants, Caravan, Diplomat, WildlifeCurious, WildlifeMischievous, WildlifeFlier, NightCreature] -civ [player,ENTITY_ID]')
 return
end

if not args.eventType then
 error 'Specify an eventType.'
elseif not df.timed_event_type[args.eventType] then
 error('Invalid eventType: ' .. args.eventType)
end

local civ = nil --as:df.historical_entity
if args.civ == 'player' then
 civ = df.historical_entity.find(df.global.ui.civ_id)
elseif args.civ then
 civ = findCiv(args.civ)
end
if args.civ and not civ then
 error('Invalid civ: ' .. args.civ)
end
if args.eventType == 'Caravan' or args.eventType == 'Diplomat' then
 if not civ then
  error('Specify civ for this eventType')
 end
end

if args.eventType == 'Migrants' then
 civ = df.historical_entity.find(df.global.ui.civ_id)
end

local timedEvent = df.timed_event:new()
timedEvent.type = df.timed_event_type[args.eventType]
timedEvent.season = df.global.cur_season
timedEvent.season_ticks = df.global.cur_season_tick
if civ then
 timedEvent.entity = civ
end

df.global.timed_events:insert('#', timedEvent)
