-- Forces an event (wrapper for modtools/force)
--[====[

force
=====
A simpler wrapper around the `modtools/force` script.

Usage:

- ``force event_type``
- ``force event_type civ_id`` - civ ID required for ``Diplomat`` and ``Caravan``
  events

See `modtools/force` for a complete list of event types.

]====]

utils = require 'utils'
args = {...}
if #args < 1 then qerror('missing event type') end
if args[1]:find('help') then
    return print(dfhack.script_help())
end
eventType = nil
for _, type in ipairs(df.timed_event_type) do
    if type:lower() == args[1]:lower() then
        eventType = type
    end
end
if not eventType then
    qerror('unknown event type: ' .. args[1])
end

newArgs = {'-eventType', eventType}
if eventType == 'Caravan' or eventType == 'Diplomat' then
    if not args[2] then
        qerror('event type ' .. eventType .. ' requires civ ID')
    else
        table.insert(newArgs, '-civ')
        table.insert(newArgs, args[2])
    end
end

dfhack.run_script('modtools/force', table.unpack(newArgs))
