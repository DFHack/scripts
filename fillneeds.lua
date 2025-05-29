local utils = require('utils')
local validArgs = utils.invert({'all', 'unit'})
local args = utils.processArgs({...}, validArgs)

function satisfyNeeds(unit)
    if not unit.status.current_soul then
        return
    end
    local mind = unit.status.current_soul.personality.needs
    for k,v in ipairs(mind) do
        mind[k].focus_level = 400
    end
    unit.status.current_soul.personality.stress = -1000000
end

if args.all then
    for _, unit in ipairs(dfhack.units.getCitizens()) do
        satisfyNeeds(unit)
    end
else
    local unit = args.unit and df.unit.find(args.unit) or dfhack.gui.getSelectedUnit(true)
    if not unit then
        qerror('A unit must be specified or selected.')
    end
    satisfyNeeds(unit)
end
