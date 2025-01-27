--@ module=true

local convo = reqscript('internal/advtools/convo')
local party = reqscript('internal/advtools/party')

OVERLAY_WIDGETS = {
    conversation=convo.AdvRumorsOverlay,
}

if dfhack_flags.module then
    return
end

local commands = {
    party=party.run,
}

local args = {...}
local command = table.remove(args, 1)

if not command or command == 'help' or not commands[command] then
    print(dfhack.script_help())
    return
end

-- since these are "advtools", maybe don't let them run outside adventure mode.
if not dfhack.world.isAdventureMode() then
    qerror("This script can only be used during adventure mode!")
end
commands[command](args)
