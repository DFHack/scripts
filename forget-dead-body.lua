-- Removes emotions associated with seeing a dead body
--@ module = true

local utils = require 'utils'

local validArgs = utils.invert({
    'help',
    'all',
})

function forgetDeadBody(unit)
    for _, t in ipairs(unit.status.current_soul.personality.emotions) do
        if t.thought == df.unit_thought_type.SawDeadBody then
            t.type = df.emotion_type.ANYTHING
        end
    end
end

function main(...)
    local args = utils.processArgs({...}, validArgs)

    if args.help then
        print(dfhack.script_help())
        return
    end

    if args.all then
        for _, unit in ipairs(dfhack.units.getCitizens()) do
            forgetDeadBody(unit)
        end
    else
        local unit = dfhack.gui.getSelectedUnit()
        if unit then
            forgetDeadBody(unit)
        else
            qerror('Invalid usage: No unit selected and --all argument not given.')
        end
    end
end

if not dfhack_flags.module then
    main(...)
end
