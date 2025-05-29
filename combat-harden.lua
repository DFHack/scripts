--@ module = true

local utils = require('utils')

local validArgs = utils.invert({
    'help',
    'all',
    'citizens',
    'tier',
    'unit',
    'value',
})

local tiers = {0, 33, 67, 100}

function setUnitCombatHardened(unit, value)
    if not unit.status.current_soul then return end

    -- Ensure value is in the bounds of 0-100
    value = math.max(0, math.min(100, value))
    unit.status.current_soul.personality.combat_hardened = value

    print(('set hardness value for %s to %d'):format(
        dfhack.df2console(dfhack.units.getReadableName(unit)),
        value))
end

function main(args)
    local opts = utils.processArgs(args, validArgs)

    if opts.help then
        print(dfhack.script_help())
        return
    end

    local value
    if not opts.tier and not opts.value then
        -- Default to 100
        value = 100
    elseif opts.tier then
        -- Bound between 1-4
        local tierNum = math.max(1, math.min(4, tonumber(opts.tier)))
        value = tiers[tierNum]
    elseif opts.value then
        -- Function ensures value is bound, so no need to bother here
        -- Will check it's a number, though
        value = tonumber(opts.value) or 100
    end

    local unitsList = {} --as:df.unit[]

    if not opts.all and not opts.citizens then
        -- Assume trying to target a unit
        local unit
        if opts.unit then
            if tonumber(opts.unit) then
                unit = df.unit.find(opts.unit)
            end
        end

        -- If unit ID wasn't provided / unit couldn't be found,
        -- Try getting selected unit
        if not unit then
            unit = dfhack.gui.getSelectedUnit(true)
        end

        if not unit then
            qerror("Couldn't find unit. If you don't want to target a specific unit, use --all or --citizens.")
        else
            table.insert(unitsList, unit)
        end
    elseif opts.all then
        for _, unit in pairs(df.global.world.units.active) do
            table.insert(unitsList, unit)
        end
    elseif opts.citizens then
        -- Abort if not in Fort mode
        if not dfhack.world.isFortressMode() then
            qerror('--citizens requires fortress mode')
        end

        for _, unit in ipairs(dfhack.units.getCitizens()) do
            table.insert(unitsList, unit)
        end
    end

    for _, unit in ipairs(unitsList) do
        setUnitCombatHardened(unit, value)
    end
end

if not dfhack_flags.module then
    main{...}
end
