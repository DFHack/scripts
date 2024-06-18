-- displays migration wave information for citizens/units

local utils = require('utils')

local validArgs = utils.invert({
    'unit',
    'all',
    'granularity',
    'showarrival',
    'help'
})
local args = utils.processArgs({...}, validArgs)
args.granularity = args.granularity or 'seasons'

--[[
The script loops through all citizens on the map and builds each wave one dwarf
at a time. This requires calculating arrival information for each dwarf and
combining this information into a sort of unique wave ID number. After this is
finished, these wave IDs are normalized so they start at zero and increment by
one for each wave.
]]

local selected = dfhack.gui.getSelectedUnit(true)
local ticks_per_day = 1200
local ticks_per_month = 28 * ticks_per_day
local ticks_per_season = 3 * ticks_per_month
local ticks_per_year = 12 * ticks_per_month
local current_tick = df.global.cur_year_tick
local seasons = {
    'spring',
    'summer',
    'autumn',
    'winter',
}

--sorted pairs
local function spairs(t, cmp)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end
    utils.sort_vector(keys, nil, cmp)
    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        local k = keys[i]
        if k then
            return k, t[k]
        end
    end
end

local waves = {}
local function getWave(dwf)
    arrival_time = current_tick - dwf.curse.time_on_site
    arrival_year = df.global.cur_year + (arrival_time // ticks_per_year)
    arrival_season = 1 + (arrival_time % ticks_per_year) // ticks_per_season
    arrival_month = 1 + (arrival_time % ticks_per_year) // ticks_per_month
    arrival_day = 1 + ((arrival_time % ticks_per_year) % ticks_per_month) // ticks_per_day
    local wave
    if args.granularity == 'days' then
        wave = arrival_day + (100 * arrival_month) + (10000 * arrival_year)
    elseif args.granularity == 'months' then
        wave = arrival_month + (100 * arrival_year)
    elseif args.granularity == 'seasons' then
        wave = arrival_season + (10 * arrival_year)
    elseif args.granularity == 'years' then
        wave = arrival_year
    else
        qerror('Invalid granularity value. Omit the option if you want "seasons".')
    end
    table.insert(ensure_key(waves, wave), dwf)
    if args.unit and dwf == selected then
        print(('  Selected citizen arrived in the %s of year %d, month %d, day %d.'):format(
            seasons[arrival_season], arrival_year, arrival_month, arrival_day))
    end
end

for _,v in ipairs(dfhack.units.getCitizens(true, true)) do
    getWave(v)
end

if args.help or (not args.all and not args.unit) then
    print(dfhack.script_help())
    return
end

local zwaves = {}
i = 0
for k,v in spairs(waves, utils.compare) do
    if args.showarrival and args.all then
        if args.granularity == 'days' then
            local year = k // 10000
            local month = (k - (10000 * year)) // 100
            local season = 1 + ((month - 1) // 3)
            local day = k - ((100 * month) + (10000 * year))
            print(('  Wave %2d arrived in the %s of year %d, month %d, day %d.'):format(
                i, seasons[season], year, month, day))
        elseif args.granularity == 'months' then
            local year = k // 100
            local month = k - (100 * year)
            local season = 1 + ((month - 1) // 3)
            print(('  Wave %2d arrived in the %s of year %d, month %d.'):format(
                i, seasons[season], year, month))
        elseif args.granularity == 'seasons' then
            local year = k // 10
            local season = k - (10 * year)
            print(('  Wave %2d arrived in the %s of year %d'):format(
                i, seasons[season], year))
        elseif args.granularity == 'years' then
            local year = k
            print(('  Wave %2d arrived in year %d.'):format(i, year))
        end
    end

    zwaves[i] = waves[k]
    for _,dwf in spairs(v, utils.compare) do
        if args.unit and dwf == selected then
            print(('  Selected citizen came with wave %d'):format(i))
        end
    end
    i = i + 1
end

if args.all then
    if args.showarrival then
        print()
    end
    for i = 0, #zwaves do
        print(('  Wave %2d has %2d surviving member%s.'):format(
            i, #zwaves[i], #zwaves[i] == 1 and '' or 's'))
    end
end
