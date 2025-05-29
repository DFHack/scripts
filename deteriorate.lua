-- Cause selected item types to quickly rot away
--@module = true
--@enable = true

local argparse = require('argparse')
local utils = require('utils')

--------------------
-- state

local GLOBAL_KEY = 'deteriorate'

local categories = {
    'clothes',
    'food',
    'corpses',
    'usable-parts',
    'unusable-parts',
}

local aliases = {
    parts={'usable-parts', 'unusable-parts'},
    all=categories,
}

local function get_default_state()
    local default_state = {
        enabled=false,
        categories={},
    }
    for _,category in ipairs(categories) do
        local default_enabled = category == 'corpses' or category == 'unusable-parts'
        default_state.categories[category] = {
            enabled=default_enabled,
            frequency=1,
            last_cycle_tick=0,
        }
    end
    return default_state
end

state = state or get_default_state()

function isEnabled()
    return state.enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, state)
end

-----------------------
-- deterioration logic

local function get_clothes_vectors()
    return {
        df.global.world.items.other.GLOVES,
        df.global.world.items.other.ARMOR,
        df.global.world.items.other.SHOES,
        df.global.world.items.other.PANTS,
        df.global.world.items.other.HELM,
    }
end

local function get_food_vectors()
    return {
        df.global.world.items.other.FISH,
        df.global.world.items.other.FISH_RAW,
        df.global.world.items.other.EGG,
        df.global.world.items.other.CHEESE,
        df.global.world.items.other.PLANT,
        df.global.world.items.other.PLANT_GROWTH,
        df.global.world.items.other.FOOD,
        df.global.world.items.other.MEAT,
        df.global.world.items.other.LIQUID_MISC,
    }
end

local function get_corpse_vectors()
    return {
        df.global.world.items.other.CORPSE,
        df.global.world.items.other.REMAINS,
    }
end

local function get_parts_vectors()
    return {
        df.global.world.items.other.CORPSEPIECE,
    }
end

local function is_valid_clothing(item)
    -- includes discarded owned clothes
    return item.subtype.armorlevel == 0 and item.flags.on_ground
            and item.wear > 0
end

local function is_valid_food(item)
    if not df.item_liquid_miscst:is_instance(item) then
        return true
    end
    local mi = dfhack.matinfo.decode(item)
    return mi:getToken():endswith(':MILK')
end

-- TODO: is just checking in_building sufficient, or do we need to validate
-- that the building it is in is a coffin?
local function is_entombed(item)
    return item.flags.in_building
end

local function is_valid_corpse(item)
    return not is_entombed(item)
end

local usable_types = {
    'plant',
    'silk',
    'leather',
    'bone',
    'shell',
    'wood',
    'soap',
    'tooth',
    'horn',
    'pearl',
    'skull',
    'hair_wool',
    'yarn',
}

local function is_usable_corpse_piece(item)
    if item.flags.dead_dwarf or item.corpse_flags.unbutchered then
        return false
    end
    for _,flag in ipairs(usable_types) do
        if item.corpse_flags[flag] then return true end
    end
    return false
end

local function is_valid_usable_corpse_piece(item)
    return not is_entombed(item) and is_usable_corpse_piece(item)
end

local function is_valid_unusable_corpse_piece(item)
    return not is_entombed(item) and not is_usable_corpse_piece(item)
end

-- different algorithm for clothes so they rot away when they become tattered
local function increment_clothes_wear(item)
    item.wear_timer = math.ceil(item.wear_timer * (item.wear + 0.5))
    return item.wear > 2
end

local function increment_wear(threshold, item)
    item.wear_timer = item.wear_timer + 1
    if item.wear_timer > threshold then
        item.wear_timer = 0
        item.wear = item.wear + 1
    end
    return item.wear > 3
end

local function deteriorate_items(now, get_item_vectors_fn, is_valid_fn, increment_wear_fn)
    local items_to_remove = {}
    for _,v in ipairs(get_item_vectors_fn()) do
        for _,item in ipairs(v) do
            if is_valid_fn(item) and (now or increment_wear_fn(item)) and not item.flags.garbage_collect then
                table.insert(items_to_remove, item)
            end
        end
    end
    for _,item in ipairs(items_to_remove) do
        print(('deteriorate: %s crumbles away to dust'):format(dfhack.items.getReadableDescription(item)))
        dfhack.items.remove(item)
    end
    return #items_to_remove
end

local function mk_deteriorate_fn(get_item_vectors_fn, is_valid_fn, increment_wear_fn)
    return function(now)
        return deteriorate_items(now, get_item_vectors_fn, is_valid_fn, increment_wear_fn)
    end
end

local category_fns = {
    clothes=mk_deteriorate_fn(get_clothes_vectors, is_valid_clothing, increment_clothes_wear),
    food=mk_deteriorate_fn(get_food_vectors, is_valid_food, curry(increment_wear, 24)),
    corpses=mk_deteriorate_fn(get_corpse_vectors, is_valid_corpse, curry(increment_wear, 24)),
    ['usable-parts']=mk_deteriorate_fn(get_parts_vectors, is_valid_usable_corpse_piece, curry(increment_wear, 24)),
    ['unusable-parts']=mk_deteriorate_fn(get_parts_vectors, is_valid_unusable_corpse_piece, curry(increment_wear, 24)),
}

----------------------------
-- cycle and timer logic

local TICKS_PER_DAY = 1200
local TICKS_PER_MONTH = 28 * TICKS_PER_DAY
local TICKS_PER_YEAR = 12 * TICKS_PER_MONTH

local function get_normalized_tick()
    return dfhack.world.ReadCurrentTick() + TICKS_PER_YEAR * dfhack.world.ReadCurrentYear()
end

timeout_ids = timeout_ids or {}

local function event_loop(category)
    local category_data = state.categories[category]
    if not state.enabled or not category_data.enabled then return end

    local current_tick = get_normalized_tick()
    local ticks_per_cycle = math.max(1, math.floor(TICKS_PER_DAY * category_data.frequency))
    local timeout_ticks = ticks_per_cycle

    if current_tick - category_data.last_cycle_tick < ticks_per_cycle then
        timeout_ticks = category_data.last_cycle_tick - current_tick + ticks_per_cycle
    else
        category_fns[category](false)
        category_data.last_cycle_tick = current_tick
        persist_state()
    end
    timeout_ids[category] = dfhack.timeout(timeout_ticks, 'ticks', curry(event_loop, category))
end

-- launches timer. first cycle will be after the configured frequency
local function start_category(category, category_data, current_tick)
    category_data = category_data or state.categories[category]
    category_data.last_cycle_tick = current_tick or get_normalized_tick()
    event_loop(category)
end

local function stop_category(category)
    local timeout_id = timeout_ids[category]
    if timeout_id then
        dfhack.timeout_active(timeout_id, nil) -- cancel callback
        timeout_ids[category] = nil
    end
end

local function do_enable()
    if state.enabled then return end

    state.enabled = true
    local current_tick = get_normalized_tick()
    for _,category in ipairs(categories) do
        local category_data = state.categories[category]
        if category_data.enabled then
            start_category(category, category_data, current_tick)
        end
    end
end

local function do_disable()
    if not state.enabled then return end

    state.enabled = false
    for _,category in ipairs(categories) do
        stop_category(category)
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        do_disable()
        return
    end

    if sc ~= SC_MAP_LOADED or not dfhack.world.isFortressMode() then
        return
    end

    state = get_default_state()
    utils.assign(state, dfhack.persistent.getSiteData(GLOBAL_KEY, state))

    for _,category in ipairs(categories) do
        event_loop(category)
    end
end

---------------------
-- CLI

if dfhack_flags.module then
    return
end

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        do_enable()
    else
        do_disable()
    end
end

local function parse_categories(arg)
    local list = {}
    for _,v in ipairs(argparse.stringList(arg)) do
        if aliases[v] then
            for _,alias in ipairs(aliases[v]) do
                table.insert(list, alias)
            end
        elseif category_fns[v] then
            table.insert(list, v)
        else
            qerror(('unrecognized category: "%s"'):format(v))
        end
    end
    if #list == 0 then
        qerror('no categories specified')
    end
    return list
end

local function status()
    local running_str = state.enabled and 'Running' or 'Would run'
    print(('deteriorate is %s'):format(state.enabled and 'enabled' or 'disabled'))
    print()
    for _,category in ipairs(categories) do
        local status_str = 'Stopped'
        local category_data = state.categories[category]
        if category_data.enabled then
            status_str = ('%s every %s day%s') :format(running_str,
                category_data.frequency, category_data.frequency == 1 and '' or 's')
        end
        print(('%18s: %s'):format(category, status_str))
    end
end

local help = false

local positionals = argparse.processArgsGetopt({...}, {
    {'h', 'help', handler=function() help = true end},
})

local command = table.remove(positionals, 1)
if command == 'help' or help then
    print(dfhack.script_help())
    return
end

if not command or command == 'status' then
    status()
elseif command == 'enable' then
    local cats = parse_categories(positionals[1])
    for _,v in ipairs(cats) do
        if state.categories[v].enabled then
            goto continue
        end
        state.categories[v].enabled = true
        if state.enabled then
            start_category(v)
        end
        ::continue::
    end
elseif command == 'disable' then
    local cats = parse_categories(positionals[1])
    for _,v in ipairs(cats) do
        if not state.categories[v].enabled then
            goto continue
        end
        state.categories[v].enabled = false
        if state.enabled then
            stop_category(v)
        end
        ::continue::
    end
elseif command == 'frequency' or command == 'freq' then
    local freq = tonumber(positionals[1])
    if not freq or freq <= 0 then
        qerror('frequency must be greater than 0')
    end
    local cats = parse_categories(positionals[2])
    for _,v in ipairs(cats) do
        state.categories[v].frequency = freq
        if state.enabled then
            stop_category(v)
            start_category(v)
        end
    end
elseif command == 'now' then
    local cats = parse_categories(positionals[1])
    local count = 0
    for _,v in ipairs(cats) do
        count = count + category_fns[v](true)
    end
    print(('Deteriorated %d item%s'):format(count, count == 1 and '' or 's'))
else
    qerror('unrecognized command: "' .. command .. '"')
end

persist_state()
