local argparse = require('argparse')

local function print_color(color, s)
    dfhack.color(color)
    dfhack.print(s)
    dfhack.color(COLOR_RESET)
end

local function show_one(unit)
    local t = dfhack.units.getMiscTrait(unit, df.misc_trait_type.CaveAdapt)
    local val = t and t.value or 0
    print_color(COLOR_RESET, ('%s has an adaptation level of '):
        format(dfhack.units.getReadableName(unit)))
    if val <= 399999 then
        print_color(COLOR_GREEN, ('%d\n'):format(val))
    elseif val <= 599999 then
        print_color(COLOR_YELLOW, ('%d\n'):format(val))
    else
        print_color(COLOR_RED, ('%d\n'):format(val))
    end
end

local function set_one(unit, value)
    local t = dfhack.units.getMiscTrait(unit, df.misc_trait_type.CaveAdapt, true)
    print(('%s has changed from an adaptation level of %d to %d'):
        format(dfhack.units.getReadableName(unit), t.value, value))
    t.value = value
end

local function get_units(all)
    local units = all and dfhack.units.getCitizens() or {dfhack.gui.getSelectedUnit(true)}
    if #units == 0 then
        qerror('Please select a unit or specify the --all option')
    end
    return units
end

local help, all = false, false
local positionals = argparse.processArgsGetopt({...}, {
    {'a', 'all', handler=function() all = true end},
    {'h', 'help', handler=function() help = true end}
})

if help then
    print(dfhack.script_help())
    return
end

if not positionals[1] or positionals[1] == 'show' then
    for _, unit in ipairs(get_units(all)) do
        show_one(unit)
    end
elseif positionals[1] == 'set' then
    local value = argparse.nonnegativeInt(positionals[2], 'value')
    if value > 800000 then
        dfhack.printerr('clamping value to 800,000')
        value = 800000
    end
    for _, unit in ipairs(get_units(all)) do
        set_one(unit, value)
    end
else
    qerror('unknown command: ' .. positionals[1])
end
