--@module = true

local argparse = require('argparse')

local function spawnLiquid(position, liquid_level, liquid_type, update_liquids)
  local map_block = dfhack.maps.getTileBlock(position)
  local tile = dfhack.maps.getTileFlags(position)

  tile.flow_size = liquid_level
  tile.liquid_type = liquid_type
  tile.flow_forbid = false

  map_block.flags.update_liquid = update_liquids
  map_block.flags.update_liquid_twice = update_liquids
end

local function checkUnit(opts, unit)
    if not dfhack.units.isActive(unit) or
        (unit.body.blood_max ~= 0 and unit.body.blood_count == 0) or
        unit.flags1.caged or
        unit.flags1.chained
    then
        return false
    end
    if opts.only_visible and not dfhack.units.isVisible(unit) then
        return false
    end
    if not opts.include_friendly and not dfhack.units.isDanger(unit) and not dfhack.units.isWildlife(unit) then
        return false
    end
    if opts.selected_caste and opts.selected_caste ~= df.creature_raw.find(unit.race).caste[unit.caste].caste_id then
        return false
    end
    return true
end

killMethod = {
    INSTANT = 0,
    BUTCHER = 1,
    MAGMA = 2,
    DROWN = 3,
    VAPORIZE = 4,
    DISINTEGRATE = 5,
    KNOCKOUT = 6,
    TRAUMATIZE = 7,
}

-- removes the unit from existence, leaving no corpse if the unit hasn't died
-- by the time the vanish countdown expires
local function vaporizeUnit(unit, target_value)
    target_value = target_value or 1
    unit.animal.vanish_countdown = target_value
end

-- Kills a unit by removing blood and also setting a vanish countdown as a failsafe.
local function destroyUnit(unit)
    unit.body.blood_count = 0
    vaporizeUnit(unit, 2)
end

--  Marks a unit for slaughter at the butcher's shop.
local function butcherUnit(unit)
    unit.flags2.slaughter = true
end

--  Knocks a unit out for 30k ticks or the target value
local function knockoutUnit(unit, target_value)
    target_value = target_value or 30000
    unit.counters.unconscious = target_value
end

--  Traumatizes the unit, forcing them to stare off into space. Cuts down on pathfinding
local function traumatizeUnit(unit)
    unit.mood = df.mood_type.Traumatized
end


local function drownUnit(unit, liquid_type)
    previousPositions = previousPositions or {}
    previousPositions[unit.id] = copyall(unit.pos)

    local function createLiquid()
        spawnLiquid(unit.pos, 7, liquid_type)
        if not same_xyz(previousPositions[unit.id], unit.pos) then
            spawnLiquid(previousPositions[unit.id], 0, nil, false)
            previousPositions[unit.id] = copyall(unit.pos)
        end
        if unit.flags2.killed then
            spawnLiquid(previousPositions[unit.id], 0, nil, false)
        else
            dfhack.timeout(1, 'ticks', createLiquid)
        end
    end
    createLiquid()
end

local function destroyInventory(unit)
    for index = #unit.inventory-1, 0, -1 do
        local item = unit.inventory[index].item
        dfhack.items.remove(item)
    end
end

function killUnit(unit, method)
    if method == killMethod.BUTCHER then
        butcherUnit(unit)
    elseif method == killMethod.MAGMA then
        drownUnit(unit, df.tile_liquid.Magma)
    elseif method == killMethod.DROWN then
        drownUnit(unit, df.tile_liquid.Water)
    elseif method == killMethod.VAPORIZE then
        vaporizeUnit(unit)
    elseif method == killMethod.DISINTEGRATE then
        vaporizeUnit(unit)
        destroyInventory(unit)
    elseif method == killMethod.KNOCKOUT then
        knockoutUnit(unit)
    elseif method == killMethod.TRAUMATIZE then
        traumatizeUnit(unit)
    else
        destroyUnit(unit)
    end
end

local function getRaceCastes(race_id)
    local unit_castes = {}
    for _, caste in pairs(df.creature_raw.find(race_id).caste) do
        unit_castes[caste.caste_id] = {}
    end
    return unit_castes
end

local function getMapRaces(opts)
    local map_races = {}
    for _, unit in pairs(df.global.world.units.active) do
        if not checkUnit(opts, unit) then goto continue end
        local race_name, display_name
        if dfhack.units.isUndead(unit) then
            race_name = 'UNDEAD'
            display_name = 'UNDEAD'
        else
            local craw = df.creature_raw.find(unit.race)
            race_name = craw.creature_id
            if race_name:match('^FORGOTTEN_BEAST_[0-9]+$') or race_name:match('^TITAN_[0-9]+$') then
                display_name = dfhack.units.getReadableName(unit)
            else
                display_name = craw.name[0]
            end
        end
        local race = ensure_key(map_races, race_name)
        race.id = unit.race
        race.name = race_name
        race.display_name = display_name
        race.count = (race.count or 0) + 1
        ::continue::
    end
    return map_races
end

if dfhack_flags.module then
    return
end

local options, args = {
    help = false,
    method = killMethod.INSTANT,
    only_visible = false,
    include_friendly = false,
    limit = -1,
}, {...}

local positionals = argparse.processArgsGetopt(args, {
    {'h', 'help', handler = function() options.help = true end},
    {'m', 'method', handler = function(arg) options.method = killMethod[arg:upper()] end, hasArg = true},
    {'o', 'only-visible', handler = function() options.only_visible = true end},
    {'f', 'include-friendly', handler = function() options.include_friendly = true end},
    {'l', 'limit', handler = function(arg) options.limit = argparse.positiveInt(arg, 'limit') end, hasArg = true},
})

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

if positionals[1] == "help" or options.help then
    print(dfhack.script_help())
    return
end

if positionals[1] == "this" then
    local selected_unit = dfhack.gui.getSelectedUnit()
    if not selected_unit then
        qerror("Select a unit and run the script again.")
    end
    killUnit(selected_unit, options.method)
    print('Unit exterminated.')
    return
end

local map_races = getMapRaces(options)

if not positionals[1] or positionals[1] == 'list' then
    local sorted_races = {}
    local max_width = 10
    for _,v in pairs(map_races) do
        max_width = math.max(max_width, #v.name)
        table.insert(sorted_races, v)
    end
    table.sort(sorted_races, function(a, b)
        if a.count == b.count then
            local asuffix, bsuffix = a.name:match('([0-9]+)$'), b.name:match('([0-9]+)$')
            if asuffix and bsuffix then
                local aname, bname = a.name:match('(.*)_[0-9]+$'), b.name:match('(.*)_[0-9]+$')
                local anum, bnum = tonumber(asuffix), tonumber(bsuffix)
                if aname == bname and anum and bnum then
                    return anum < bnum
                end
            end
            return a.name < b.name
        end
        return a.count > b.count
    end)
    for _,v in ipairs(sorted_races) do
        local name_str = v.name
        if name_str ~= 'UNDEAD' and v.display_name ~= string.lower(name_str):gsub('_', ' ') then
            name_str = ('%-'..tostring(max_width)..'s  (%s)'):format(name_str, v.display_name)
        end
        print(('%4s %s'):format(v.count, name_str))
    end
    return
end

local count, target = 0, 'creature(s)'
local race_name = table.concat(positionals, ' ')
if race_name:lower() == 'undead' then
    target = 'undead'
    if not map_races.UNDEAD then
        qerror("No undead found on the map.")
    end
    for _, unit in pairs(df.global.world.units.active) do
        if dfhack.units.isUndead(unit) and checkUnit(options, unit) then
            killUnit(unit, options.method)
            count = count + 1
        end
    end
elseif positionals[1]:split(':')[1] == "all" then
    options.selected_caste = positionals[1]:split(':')[2]

    for _, unit in ipairs(df.global.world.units.active) do
        if options.limit > 0 and count >= options.limit then
            break
        end
        if not checkUnit(options, unit) then
            goto skipunit
        end

        killUnit(unit, options.method)
        count = count + 1
        :: skipunit ::
    end
else
    local selected_race, selected_caste = race_name, nil

    if string.find(selected_race, ':') then
        local tokens = selected_race:split(':')
        selected_race, selected_caste = tokens[1], tokens[2]
    end

    if not map_races[selected_race] then
        local selected_race_upper = selected_race:upper()
        local selected_race_under = selected_race_upper:gsub(' ', '_')
        if map_races[selected_race_upper] then
            selected_race = selected_race_upper
        elseif map_races[selected_race_under] then
            selected_race = selected_race_under
        else
            qerror("No creatures of this race on the map (" .. selected_race .. ").")
        end
    end

    local race_castes = getRaceCastes(map_races[selected_race].id)

    if selected_caste and not race_castes[selected_caste] then
        local selected_caste_upper = selected_caste:upper()
        if race_castes[selected_caste_upper] then
            selected_caste = selected_caste_upper
        else
            qerror("Invalid caste: " .. selected_caste)
        end
    end

    target = selected_race
    options.selected_caste = selected_caste

    for _, unit in pairs(df.global.world.units.active) do
        if options.limit > 0 and count >= options.limit then
            break
        end
        if not checkUnit(options, unit) then
            goto skipunit
        end

        if selected_race == df.creature_raw.find(unit.race).creature_id then
            killUnit(unit, options.method)
            count = count + 1
        end

        :: skipunit ::
    end
end

print(([[Exterminated %d %s.]]):format(count, target))
