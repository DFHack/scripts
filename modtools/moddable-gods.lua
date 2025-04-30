local argparse = require('argparse')

local function get_spheres(arg)
    local spheres = {}
    for _, sphere in ipairs(argparse.stringList(arg, 'spheres')) do
        local sphereType = df.sphere_type[sphere]
        if not sphereType then
            qerror('invalid sphere: ' .. sphere)
        end
        table.insert(spheres, sphereType)
    end
    return spheres
end

local function get_gender(arg)
    if arg == 'male' then
        return df.pronoun_type.he
    elseif arg == 'female' then
        return df.pronoun_type.she
    elseif arg == 'neuter' then
        return df.pronoun_type.it
    else
        qerror('invalid gender: ' .. arg)
    end
end

local function get_race(arg)
    local int_arg = tonumber(arg)
    if int_arg then
        local raw = df.creature_raw.find(int_arg)
        if not raw then
            qerror('race id ' .. int_arg .. ' does not exist')
        end
        return int_arg
    end
    for k, raw in ipairs(df.global.world.raws.creatures.all) do
        if raw.creature_id == arg or raw.name[0] == arg then
            return k
        end
    end
    qerror('race ' .. arg .. ' does not exist')
end

local function do_god(opts)
    local godFig = df.historical_figure:new()
    godFig.race = opts.race
    godFig.caste = 0
    godFig.sex = opts.gender

    godFig.appeared_year = -1
    godFig.born_year = -1
    godFig.born_seconds = -1
    godFig.curse_year = -1
    godFig.curse_seconds = -1
    godFig.old_year = -1
    godFig.old_seconds = -1
    godFig.died_year = -1
    godFig.died_seconds = -1

    godFig.name.has_name = true
    godFig.name.first_name = opts.name

    godFig.breed_id = -1
    godFig.flags.deity = true
    godFig.flags.brag_on_kill = true
    godFig.flags.kill_quest = true
    godFig.flags.chatworthy = true
    godFig.flags.flashes = true
    godFig.flags.never_cull = true

    godFig.info = df.historical_figure_info:new()
    godFig.info.metaphysical = {new=true}
    godFig.info.known_info = {new=true}
    for _,sphere in ipairs(opts.spheres) do
        godFig.info.metaphysical.spheres:insert('#', sphere)
    end

    godFig.pool_id = -1 -- will get a pool_id when game is saved and reloaded
    godFig.id = df.global.hist_figure_next_id
    df.global.hist_figure_next_id = 1 + df.global.hist_figure_next_id
    df.global.world.history.figures:insert('#', godFig)

    return godFig
end

if not dfhack.isWorldLoaded() then
    qerror('This script requires a loaded world.')
end

local opts = {
    name=nil,
    spheres=nil,
    gender=nil,
    race=nil,
    quiet=false,
    help=false,
}

local _ = argparse.processArgsGetopt({ ... }, {
    {'n', 'name',        hasArg=true, handler=function(arg) opts.name = arg end},
    {'s', 'spheres',     hasArg=true, handler=function(arg) opts.spheres = get_spheres(arg) end},
    {'g', 'gender',      hasArg=true, handler=function(arg) opts.gender = get_gender(arg) end},
    {'d', 'depicted-as', hasArg=true, handler=function(arg) opts.race = get_race(arg) end},
    {'h', 'help',        handler=function() opts.help = true end},
    {'q', 'quiet',       handler=function() opts.quiet = true end},
})

if opts.help then
    print(dfhack.script_help())
    return
end

if not opts.name or not opts.spheres or #opts.name == 0 or #opts.spheres == 0 then
    qerror('name and spheres must be specified.')
end

for _, fig in ipairs(df.global.world.history.figures) do
    if fig.name.first_name == opts.name then
        print('god "' .. opts.name .. '" already exists.')
        return
    end
end

if not opts.gender then
    opts.gender = math.random(-1, 1)
end

if not opts.race then
    opts.race = get_race('dwarf')
end

local godFig = do_god(opts)

if not opts.quiet then
    print(godFig.name.first_name .. " created as historical figure " .. tostring(godFig.id))
end
