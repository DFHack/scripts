--@ module=true

local convo = reqscript('internal/advtools/convo')
local shooting = reqscript('internal/advtools/shooting')

OVERLAY_WIDGETS = {
    conversation=convo.AdvRumorsOverlay,
    shooting=shooting.FixShootingOverlay,
}

if dfhack_flags.module then
    return
end

local commands = {
    -- mycommand=mycommand.run,
}

local args = {...}
local command = table.remove(args, 1)

if not command or command == 'help' or not commands[command] then
    print(dfhack.script_help())
    return
end

commands[command](args)
