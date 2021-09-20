-- Adjusts properties of caravans
--[====[

caravan
=======

Adjusts properties of caravans on the map. See also `force` to create caravans.

This script has multiple subcommands. Commands listed with the argument
``[IDS]`` can take multiple caravan IDs (see ``caravan list``). If no IDs are
specified, then the commands apply to all caravans on the map.

**Subcommands:**

- ``list``: lists IDs and information about all caravans on the map.
- ``extend [DAYS] [IDS]``: extends the time that caravans stay at the depot by
  the specified number of days (defaults to 7 if not specified). Also causes
  caravans to return to the depot if applicable.
- ``happy [IDS]``: makes caravans willing to trade again (after seizing goods,
  annoying merchants, etc.). Also causes caravans to return to the depot if
  applicable.
- ``leave [IDS]``: makes caravans pack up and leave immediately.

]====]

--@ module = true

INTERESTING_FLAGS = {
    casualty = 'Casualty',
    hardship = 'Encountered hardship',
    seized = 'Goods seized',
    offended = 'Offended'
}
local caravans = df.global.ui.caravans

local function caravans_from_ids(ids)
    if not ids or #ids == 0 then
        return caravans
    end

    local c = {} --as:df.caravan_state[]
    for _,id in ipairs(ids) do
        local id = tonumber(id)
        if id then
            c[id] = caravans[id]
        end
    end
    return c
end

function bring_back(car)
    if car.trade_state ~= df.caravan_state.T_trade_state.AtDepot then
        car.trade_state = df.caravan_state.T_trade_state.Approaching
    end
end

local commands = {}

function commands.list()
    for id, car in pairs(caravans) do
        print(dfhack.df2console(('%d: %s caravan from %s'):format(
            id,
            df.creature_raw.find(df.historical_entity.find(car.entity).race).name[2], -- adjective
            dfhack.TranslateName(df.historical_entity.find(car.entity).name)
        )))
        print('  ' .. (df.caravan_state.T_trade_state[car.trade_state] or 'Unknown state: ' .. car.trade_state))
        print(('  %d day(s) remaining'):format(math.floor(car.time_remaining / 120)))
        for flag, msg in pairs(INTERESTING_FLAGS) do
            if car.flags[flag] then
                print('  ' .. msg)
            end
        end
    end
end

function commands.extend(days, ...)
    days = tonumber(days or 7) or qerror('invalid number of days: ' .. days) --luacheck: retype
    for id, car in pairs(caravans_from_ids{...}) do
        car.time_remaining = car.time_remaining + (days * 120)
        bring_back(car)
    end
end

function commands.happy(...)
    for id, car in pairs(caravans_from_ids{...}) do
        -- all flags default to false
        car.flags.whole = 0
        bring_back(car)
    end
end

function commands.leave(...)
    for id, car in pairs(caravans_from_ids{...}) do
        car.trade_state = df.caravan_state.T_trade_state.Leaving
    end
end

function commands.help()
    print(dfhack.script_help())
end

function main(...)
    local args = {...}
    local command = table.remove(args, 1)
    if commands[command] then
        commands[command](table.unpack(args))
    else
        commands.help()
        if command then
            qerror("No such subcommand: " .. command)
        else
            qerror("Missing subcommand")
        end
    end
end

if not dfhack_flags.module then
    main(...)
end
