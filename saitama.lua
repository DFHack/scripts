-- Multiply the potential (max_value) of all attributes of a unit
--[====[

saitama
=======
Multiplies the potential (max_value) of every mental and physical attribute
for the selected unit, all citizens, all map creatures, or an entire squad.

Usage::

    saitama <multiplier>
        Multiplies the attribute potential of the selected unit.

    saitama --all <multiplier>
        Multiplies the attribute potential of every creature on the map.

    saitama --citizens <multiplier>
        Multiplies the attribute potential of all fort citizens.

    saitama --squad <number> <multiplier>
        Multiplies the attribute potential of every member in squad <number>.
        Squad numbers start at 1. Use ``saitama --listsquads`` to see them.

    saitama --unit <id> <multiplier>
        Multiplies the attribute potential of the unit with the given ID.

    saitama --listsquads
        Lists all squads and their IDs.

Examples::

    saitama 100
        Selected unit's max attributes become 100x their current potential.

    saitama --citizens 10
        All citizens get 10x attribute potential.

    saitama --squad 1 50
        First squad members get 50x attribute potential.

]====]

-- Manual arg parsing to support: --squad 1 100 (flag + value + positional)
local raw_args = {...}
local args = {}
local positional = {}
local i = 1
while i <= #raw_args do
    local v = raw_args[i]
    if v == '--help' or v == '-help' then
        args.help = true
    elseif v == '--all' or v == '-all' then
        args.all = true
    elseif v == '--citizens' or v == '-citizens' then
        args.citizens = true
    elseif v == '--listsquads' or v == '-listsquads' then
        args.listsquads = true
    elseif v == '--squad' or v == '-squad' then
        i = i + 1
        args.squad = raw_args[i]
    elseif v == '--unit' or v == '-unit' then
        i = i + 1
        args.unit = raw_args[i]
    else
        table.insert(positional, v)
    end
    i = i + 1
end

if args.help then
    print(dfhack.script_help())
    return
end

-- ---------------------------------------------------------------------------
-- Core logic: multiply max_value of all attributes for a unit
-- ---------------------------------------------------------------------------
local function saitama_punch(unit, multiplier)
    if not unit then return end

    local name = dfhack.units.getReadableName(unit)

    -- Mental attributes (soul)
    if unit.status.current_soul then
        for k, v in pairs(unit.status.current_soul.mental_attrs) do
            local old = v.max_value
            v.max_value = math.floor(old * multiplier)
            -- If current value exceeds new max, leave it alone (don't nerf current)
        end
    end

    -- Physical attributes (body)
    if unit.body then
        for k, v in pairs(unit.body.physical_attrs) do
            local old = v.max_value
            v.max_value = math.floor(old * multiplier)
        end
    end

    print(('  One Punch: %s (x%d)'):format(dfhack.df2console(name), multiplier))
end

-- ---------------------------------------------------------------------------
-- Squad helpers
-- ---------------------------------------------------------------------------
local function get_squads()
    local govt = df.historical_entity.find(df.global.plotinfo.group_id)
    if not govt then return {} end
    local squads = {}
    for i, squad_id in ipairs(govt.squads) do
        local squad = df.squad.find(squad_id)
        if squad then
            table.insert(squads, {index = i, squad = squad})
        end
    end
    return squads
end

local function get_squad_units(squad)
    local units = {}
    for _, sp in ipairs(squad.positions) do
        if sp.occupant ~= -1 then
            local hf = df.historical_figure.find(sp.occupant)
            if hf then
                local unit = df.unit.find(hf.unit_id)
                if unit then
                    table.insert(units, unit)
                end
            end
        end
    end
    return units
end

local function list_squads()
    local squads = get_squads()
    if #squads == 0 then
        print('No squads found.')
        return
    end
    print('Squads:')
    for _, entry in ipairs(squads) do
        local squad = entry.squad
        local name = dfhack.military.getSquadName(squad.id)
        local member_count = 0
        for _, sp in ipairs(squad.positions) do
            if sp.occupant ~= -1 then member_count = member_count + 1 end
        end
        print(('  [%d] %s (%d members)'):format(entry.index + 1, dfhack.df2console(name), member_count))
    end
end

-- ---------------------------------------------------------------------------
-- Parse multiplier from remaining args
-- ---------------------------------------------------------------------------
local function get_multiplier(raw_args)
    -- The multiplier is the last positional argument
    local val = nil
    for _, v in ipairs(raw_args) do
        local n = tonumber(v)
        if n then val = n end
    end
    if not val then
        qerror('No multiplier provided. Usage: saitama <multiplier>')
    end
    if val < 1 then
        qerror('Multiplier must be >= 1.')
    end
    return math.floor(val)
end

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------
if args.listsquads then
    list_squads()
    return
end




if #positional == 0 then
    qerror('No multiplier provided.\n\nUsage: saitama <multiplier>\n       saitama --all <multiplier>\n       saitama --citizens <multiplier>\n       saitama --squad <id> <multiplier>\n       saitama --listsquads\n\nRun "saitama --help" for details.')
end

local multiplier = tonumber(positional[#positional])
if not multiplier or multiplier < 1 then
    qerror('Multiplier must be a number >= 1.')
end
multiplier = math.floor(multiplier)

if args.all then
    -- All creatures on map
    local count = 0
    for _, unit in ipairs(df.global.world.units.active) do
        saitama_punch(unit, multiplier)
        count = count + 1
    end
    print(('Saitama punched %d creatures (x%d).'):format(count, multiplier))

elseif args.citizens then
    -- All fort citizens
    local count = 0
    for _, unit in ipairs(dfhack.units.getCitizens()) do
        saitama_punch(unit, multiplier)
        count = count + 1
    end
    print(('Saitama punched %d citizens (x%d).'):format(count, multiplier))

elseif args.squad then
    -- Specific squad by index
    local squad_num = tonumber(args.squad)
    if not squad_num or squad_num < 1 then
        qerror('Invalid squad number: ' .. tostring(args.squad) .. '\nUse "saitama --listsquads" to see available squads.')
    end
    local squads = get_squads()
    local target_squad = nil
    for _, entry in ipairs(squads) do
        if entry.index + 1 == squad_num then
            target_squad = entry.squad
            break
        end
    end
    if not target_squad then
        qerror('Squad ' .. squad_num .. ' not found.\nUse "saitama --listsquads" to see available squads.')
    end
    local squad_name = dfhack.df2console(dfhack.military.getSquadName(target_squad.id))
    print(('Targeting squad: %s'):format(squad_name))
    local units = get_squad_units(target_squad)
    if #units == 0 then
        print('  No active members in this squad.')
    else
        for _, unit in ipairs(units) do
            saitama_punch(unit, multiplier)
        end
        print(('Saitama punched %d members of %s (x%d).'):format(#units, squad_name, multiplier))
    end

elseif args.unit then
    -- Specific unit by ID
    local unit_id = tonumber(args.unit)
    if not unit_id then
        qerror('Invalid unit ID: ' .. tostring(args.unit))
    end
    local unit = df.unit.find(unit_id)
    if not unit then
        qerror('Unit not found: ' .. tostring(unit_id))
    end
    saitama_punch(unit, multiplier)

else
    -- Default: selected unit
    local unit = dfhack.gui.getSelectedUnit()
    if not unit then
        qerror('No unit selected. Select a unit or use --all, --citizens, --squad, or --unit.')
    end
    saitama_punch(unit, multiplier)
    print(('Saitama punched (x%d).'):format(multiplier))
end
