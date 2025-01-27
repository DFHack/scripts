local argparse = require('argparse')

local TICKS_PER_SEASON_TICK = 10
local TICKS_PER_DAY = 1200

local function list_convicts()
    local found = false
    for _,punishment in ipairs(df.global.plotinfo.punishments) do
        local unit = df.unit.find(punishment.criminal)
        if unit and punishment.prison_counter > 0 then
            found = true
            local days = math.ceil((punishment.prison_counter * TICKS_PER_SEASON_TICK) / TICKS_PER_DAY)
            print(('%s (id: %d): serving a sentence of %d day(s)'):format(
                dfhack.units.getReadableName(unit), unit.id, days))
        end
    end
    if not found then
        print('No criminals currently serving sentences.')
    end
end

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
        unit = dfhack.gui.getSelectedUnit(true)
        if not unit then qerror('No unit selected!') end
    else
        unit = df.unit.find(unit_id)
        if not unit then qerror(('No unit with id %d'):format(unit_id)) end
    end
    pardon_unit(unit)
end

local unit_id = nil

local positionals = argparse.processArgsGetopt({...},
    {
        {'u', 'unit', hasArg=true,
            handler=function(optarg) unit_id = argparse.nonnegativeInt(optarg, 'unit') end},
    }
)

local command = positionals[1]

if command == 'pardon' then
    command_pardon(unit_id)
elseif not command or command == 'list' then
    list_convicts()
else
    qerror(('Unrecognised command: %s'):format(command))
end
