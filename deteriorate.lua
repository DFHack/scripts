-- Cause selected item types to quickly rot away
--@module = true
--[====[

deteriorate
===========

Causes the selected item types to rot away. By default, items disappear after a
few months, but you can choose to slow this down or even make things rot away
instantly!

Now all those slightly worn wool shoes that dwarves scatter all over the place
or the toes, teeth, fingers, and limbs from the last undead siege will
deteriorate at a greatly increased rate, and eventually just crumble into
nothing. As warm and fuzzy as a dining room full of used socks makes your
dwarves feel, your FPS does not like it!

To always have deteriorate running in your forts, add a line like this to your
``onMapLoad.init`` file (use your preferred options, of course)::

    deteriorate start --types=corpses

Usage::

    deteriorate <command> [<options>]

**<command>** is one of:

:start:   Starts deteriorating items while you play.
:stop:    Stops running.
:status:  Shows the item types that are currently being monitored and their
          deterioration frequencies.
:now:     Causes all items (of the specified item types) to rot away within a
          few ticks.

You can control which item types are being monitored and their rotting rates by
running the command multiple times with different options.

**<options>** are:

``-f``, ``--freq``, ``--frequency <number>[,<timeunits>]``
    How often to increment the wear counters. ``<timeunits>`` can be one of
    ``days``, ``months``, or ``years`` and defaults to ``days`` if not
    specified. The default frequency of 1 day will result in items disappearing
    after several months. The number does not need to be a whole number. E.g.
    ``--freq=0.5,days`` is perfectly valid.
``-q``, ``--quiet``
    Silence non-error output.
``-t``, ``--types <types>``
    The item types to affect. This option is required for ``start``, ``stop``,
    and ``now`` commands. See below for valid types.

**<types>** is any of:

:clothes:  All clothing types that have an armor rating of 0, are on the ground,
           and are already starting to show signs of wear.
:corpses:  All non-dwarf corpses and body parts. This includes potentially
           useful remains such as hair, wool, hooves, bones, and skulls. Use
           them before you lose them!
:food:     All food and plants, regardles of whether they are in barrels or
           stockpiles. Seeds are left untouched.

You can specify multiple types by separating them with commas, e.g.
``deteriorate start --types=clothes,food``.

Examples:

* Deteriorate corpses at twice the default rate::

    deteriorate start --types=corpses --freq=0.5,days

* Deteriorate corpses quickly but food slowly::

    deteriorate start -tcorpses -f0.1
    deteriorate start -tfood -f3,months
]====]

local argparse = require('argparse')
local utils = require('utils')

local function get_clothes_vectors()
    return {df.global.world.items.other.GLOVES,
            df.global.world.items.other.ARMOR,
            df.global.world.items.other.SHOES,
            df.global.world.items.other.PANTS,
            df.global.world.items.other.HELM}
end

local function get_corpse_vectors()
    return {df.global.world.items.other.ANY_CORPSE}
end

local function get_remains_vectors()
    return {df.global.world.items.other.REMAINS}
end

local function get_food_vectors()
    return {df.global.world.items.other.FISH,
            df.global.world.items.other.FISH_RAW,
            df.global.world.items.other.EGG,
            df.global.world.items.other.CHEESE,
            df.global.world.items.other.PLANT,
            df.global.world.items.other.PLANT_GROWTH,
            df.global.world.items.other.FOOD}
end

local function is_valid_clothing(item)
    return item.subtype.armorlevel == 0 and item.flags.on_ground
            and item.wear > 0
end

local function is_valid_corpse(item)
    return not item.flags.dead_dwarf
end

local function is_valid_food(item)
    return true
end

local function increment_clothes_wear(item)
    item.wear_timer = math.ceil(item.wear_timer * (item.wear + 0.5))
    return item.wear > 2
end

local function increment_generic_wear(item, threshold)
    item.wear_timer = item.wear_timer + 1
    if item.wear_timer > threshold then
        item.wear_timer = 0
        item.wear = item.wear + 1
    end
    return item.wear > 3
end

local function increment_corpse_wear(item)
    return increment_generic_wear(item, 24)
end

local function increment_remains_wear(item)
    return increment_generic_wear(item, 6)
end

local function increment_food_wear(item)
    return increment_generic_wear(item, 24)
end

local function deteriorate(get_item_vectors_fn, is_valid_fn, increment_wear_fn)
    local count = 0
    for _,v in ipairs(get_item_vectors_fn()) do
        for _,item in ipairs(v) do
            if is_valid_fn(item) and increment_wear_fn(item)
                    and not item.flags.garbage_collect then
                item.flags.garbage_collect = true
                item.flags.hidden = true
                count = count + 1
            end
        end
    end
    return count
end

local function always_worn()
    return true
end

local function deteriorate_clothes(now)
    return deteriorate(get_clothes_vectors, is_valid_clothing,
                       now and always_worn or increment_clothes_wear)
end

local function deteriorate_corpses(now)
    return deteriorate(get_corpse_vectors, is_valid_corpse,
                       now and always_worn or increment_corpse_wear)
            + deteriorate(get_remains_vectors, is_valid_corpse,
                          now and always_worn or increment_remains_wear)
end

local function deteriorate_food(now)
    return deteriorate(get_food_vectors, is_valid_food,
                       now and always_worn or increment_food_wear)
end

local type_fns = {
    clothes=deteriorate_clothes,
    corpses=deteriorate_corpses,
    food=deteriorate_food,
}

-- maps the type string to {id=int, time=int, timeunit=string}
timeout_ids = timeout_ids or {
    clothes={},
    corpses={},
    food={},
}

local function _stop(item_type)
    local timeout_id = timeout_ids[item_type].id
    if timeout_id then
        dfhack.timeout_active(timeout_id, nil) -- cancel callback
        timeout_ids[item_type].id = nil
        return true
    end
end

local function make_timeout_cb(item_type, opts)
    local fn
    fn = function(first_time)
        local timeout_data = timeout_ids[item_type]
        timeout_data.time, timeout_data.mode = opts.time, opts.mode
        timeout_data.id = dfhack.timeout(opts.time, opts.mode, fn)
        if not timeout_ids[item_type].id then
            print('Map has been unloaded; stopping deteriorate')
            for k in pairs(type_fns) do
                _stop(k)
            end
            return
        end
        if not first_time then
            local count = type_fns[item_type]()
            if count > 0 then
                print(('Deteriorated %d %s'):format(count, item_type))
            end
        end
    end
    return fn
end

local function start(opts)
    for _,v in ipairs(opts.types) do
        _stop(v)
        if not opts.quiet then
            print(('Deterioration of %s commencing...'):format(v))
        end
        -- create a callback and call it to make it register itself
        make_timeout_cb(v, opts)(true)
    end
end

local function stop(opts)
    for _,v in ipairs(opts.types) do
        if _stop(v) and not opts.quiet then
            print('Stopped deteriorating ' .. v)
        end
    end
end

local function status()
    for k in pairs(type_fns) do
        local timeout_data = timeout_ids[k]
        local status_str = 'Stopped'
        if timeout_data.id then
            local time, mode = timeout_data.time, timeout_data.mode
            if time == 1 then
                mode = mode:sub(1, #mode - 1) -- make singular
            end
            status_str = ('Running (every %s %s)') :format(time, mode)
        end
        print(('%7s:\t%s'):format(k, status_str))
    end
end

local function now(opts)
    for _,v in ipairs(opts.types) do
        local count = type_fns[v](true)
        if not opts.quiet then
            print(('Deteriorated %d %s'):format(count, v))
        end
    end
end

local function help()
    print(dfhack.script_help())
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('deteriorate needs a fortress map to be loaded.')
end

local command_switch = {
    start=start,
    stop=stop,
    status=status,
    now=now,
}

local valid_timeunits = utils.invert{'days', 'months', 'years'}

local function parse_freq(arg)
    local elems = argparse.stringList(arg)
    local num = tonumber(elems[1])
    if not num or num <= 0 then
        qerror('number parameter for --freq option must be greater than 0')
    end
    if #elems == 1 then
        return num, 'days'
    end
    local timeunit = elems[2]:lower()
    if valid_timeunits[timeunit] then return num, timeunit end
    timeunit = timeunit .. 's' -- it's ok if the user specified a singular
    if valid_timeunits[timeunit] then return num, timeunit end
    qerror(('invalid time unit: "%s"'):format(elems[2]))
end

local function parse_types(arg)
    local types = argparse.stringList(arg)
    for _,v in ipairs(types) do
        if not type_fns[v] then
            qerror(('unrecognized type: "%s"'):format(v))
        end
    end
    return types
end

local opts = {
    time = 1,
    mode = 'days',
    quiet = false,
    types = {},
    help = false,
}

local nonoptions = argparse.processArgsGetopt({...}, {
        {'f', 'freq', 'frequency', hasArg=true,
         handler=function(optarg) opts.time,opts.mode = parse_freq(optarg) end},
        {'h', 'help', handler=function() opts.help = true end},
        {'q', 'quiet', handler=function() opts.quiet = true end},
        {'t', 'types', hasArg=true,
         handler=function(optarg) opts.types = parse_types(optarg) end}})

local command = nonoptions[1]
if not command or not command_switch[command] then opts.help = true end

if not opts.help and command ~= 'status' and #opts.types == 0 then
    qerror('no item types specified! try adding a --types parameter.')
end

(command_switch[command] or help)(opts)
