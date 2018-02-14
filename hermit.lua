-- Blocks most types of visitors (caravans, migrants, etc.)
--@ enable=true
--[====[

hermit
======

Blocks all caravans, migrants, diplomats, and forgotten beasts (not wildlife).
Useful for attempting the `hermit challenge`_.

Use ``enable`` or ``disable`` to enable/disable, or ``help`` for this help.

.. warning::

    This does not block sieges, and may not block visitors or monarchs.

.. _hermit challenge: http://dwarffortresswiki.org/index.php/DF2014:Playstyle_challenge#Hermit

]====]

repeat_util = require "repeat-util"
timed_events = df.global.timed_events

whitelist = {
    [df.timed_event_type.WildlifeCurious] = true,
    [df.timed_event_type.WildlifeMischievous] = true,
    [df.timed_event_type.WildlifeFlier] = true,
}

enabled = enabled or false

function run()
    local tmp_events = {}
    for _, event in pairs(timed_events) do
        table.insert(tmp_events, event)
    end
    timed_events:resize(0)

    for _, event in pairs(tmp_events) do
        if whitelist[event.type] then
            timed_events:insert('#', event)
        else
            event:delete()
        end
    end
end

function enable(state)
    if not dfhack.isWorldLoaded() and state then
        qerror('This script requires a world to be loaded')
    end
    enabled = state
    if enabled then
        repeat_util.scheduleEvery('hermit', 1, 'days', run)
        print('hermit enabled')
    else
        repeat_util.cancel('hermit')
        print('hermit disabled')
    end
end

function dfhack.onStateChange.hermit(event)
    if event == SC_WORLD_UNLOADED then
        enable(false)
    end
end

args = {...}

if dfhack_flags.enable then
    enable(dfhack_flags.enable_state)
elseif args[1] == 'enable' or args[1] == 'disable' then
    enable(args[1] == 'enable')
else
    if args[1] ~= 'help' then
        dfhack.printerr('Unrecognized argument(s)')
    end
    print(dfhack.script_help())
end
