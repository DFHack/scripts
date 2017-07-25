--Use with a unit selected to make them focused and unstressed.
local utils=require('utils')
local args = utils.processArgs({...}, validArgs)

local unit = args.unit and df.unit.find(args.unit) or dfhack.gui.getSelectedUnit(true)

if not unit then qerror('A unit must be specified or selected.') end

function satisfyNeeds(unit,mind)
local mind = unit.status.current_soul.personality.needs
    for k,v in ipairs(mind) do
        mind[k].focus_level = 400
    end
        unit.status.current_soul.personality.stress_level=-1000000
end
satisfyNeeds(unit,mind)
