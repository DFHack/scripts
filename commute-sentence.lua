local utils = require('utils')
local argparse = require('argparse')

local function commute_sentence(unit)
    for _,punishment in ipairs(df.global.plotinfo.punishments) do
        if punishment.criminal == unit.id then
            punishment.prison_counter = 0
            return
        end
    end
    qerror('Unit is not currently serving a sentence!')
end

unit = dfhack.gui.getSelectedUnit(true)
if not unit then
    qerror('No unit selected!')
else
    commute_sentence(unit)
end
