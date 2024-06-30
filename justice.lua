
local argparse = require('argparse')

local function pardon_unit(unit)
    for _,punishment in ipairs(df.global.plotinfo.punishments) do
        if punishment.criminal == unit.id then
            punishment.prison_counter = 0
            return
        end
    end
    qerror('Unit is not currently serving a sentence!')
end

local function command_pardon(unit_id)
    local unit = nil
    if not unit_id then
        unit = dfhack.gui.getSelectedUnit()
        if not unit then qerror("No unit selected!") end
    else
        unit = df.unit.find(unit_id)
        if not unit then qerror(("No unit with id %i"):format(unit_id)) end
    end
    if unit then pardon_unit(unit) end
end

local unit_id = nil

local args = {...}

local positionals = argparse.processArgsGetopt(args,
    {'u', 'unit', hasArg=true, handler=function(optarg) unit_id = optarg end}
)

local command = positionals[1]

if command == "pardon" then
    command_pardon(unit_id)
end

qerror(("Unrecognised command: %s"):format(command))
