--@enable = true
--@module = true
local argparse = require("argparse")
local eventful = require("plugins.eventful")
local utils = require('utils')

local GLOBAL_KEY = "eggwatch"
local EVENT_FREQ = 7
local print_prefix = "eggwatch: "
local default_table = {10, false, false}
local stringtoboolean={ ["true"]=true, ["false"]=false, ["1"] = true , ["0"] =  false , ["Y"] = true , ["N"] =  false}

function dump(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. dump(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end

local function get_default_state()
    return {
        enabled = false,
        verbose = false,
        default = default_table,
        target_eggs_count_per_race = {}
    }
end

local state = state or get_default_state()

function isEnabled()
    return state.enabled
end

local function print_local(text)
    print(print_prefix .. text)
end

local function handle_error(text)
    qerror(text)
end
local function format_target_count_row (header, row)
return header..': ' .. 'target count: ' .. row[1] .. '; count children: ' .. tostring(row[2]) .. '; count adults: ' .. tostring(row[3])
end
local function print_status()
    print_local(("eggwatch is currently %s."):format(state.enabled and "enabled" or "disabled"))
    print_local(format_target_count_row('Default', state.default))
    if state.target_eggs_count_per_race ~= nil then
         for k, v in pairs(state.target_eggs_count_per_race) do
         print_local(format_target_count_row(df.global.world.raws.creatures.all[k].creature_id, v))
         end
    end
    if state.verbose then
        print_local("eggwatch is in verbose mode")
    end
end

local function print_detalis(details)
    if state.verbose then
        print_local(details)
    end
end


local function persist_state()
local state_to_persist = {}
state_to_persist.enabled = state.enabled
state_to_persist.verbose = state.verbose
state_to_persist.default = state.default
state_to_persist.target_eggs_count_per_race = {}
if state.target_eggs_count_per_race ~= nil then
    for k, v in pairs(state.target_eggs_count_per_race) do
        state_to_persist.target_eggs_count_per_race[tostring(k)]= v
    end
end
dfhack.persistent.saveSiteData(GLOBAL_KEY, state_to_persist)
end

--- Load the saved state of the script
local function load_state()
    -- load persistent data
    local persisted_data = dfhack.persistent.getSiteData(GLOBAL_KEY, persisted_data)
    state = {}
    if  persisted_data ~= nil then
        state.enabled = persisted_data.enabled
        state.verbose = persisted_data.verbose
        state.default = persisted_data.default
        state.target_eggs_count_per_race = {}
        if persisted_data.target_eggs_count_per_race ~= nil then
            for k, v in pairs(persisted_data.target_eggs_count_per_race) do
                state.target_eggs_count_per_race[tonumber(k)]= v
            end
        end
    else
        state = get_default_state()
    end
end

local function update_event_listener()
    if isEnabled() then
        eventful.enableEvent(eventful.eventType.ITEM_CREATED, EVENT_FREQ)
        eventful.onItemCreated[GLOBAL_KEY] = check_item_created
        print_local(("Subscribing in eventful for %s with frequency %s"):format("ITEM_CREATED", EVENT_FREQ))
    else
        eventful.onItemCreated[GLOBAL_KEY] = nil
        print_local(("Unregistering from eventful for %s"):format("ITEM_CREATED"))
    end
end

local function do_enable()
    state.enabled = true
    update_event_listener()
end

local function do_disable()
    state.enabled = false
    update_event_listener()
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        do_disable()
        return
    end
    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end
    load_state()
    print_status()
    update_event_listener()
end

if dfhack_flags.module then
    return
end

local function is_egg(item)
    return df.item_type.EGG == item:getType()
end

-- local function find_current_nestbox (current_eggs)
-- for _, nestbox in ipairs (df.global.world.buildings.other.NEST_BOX) do
-- if nestbox.pos == current_eggs.pos then
-- return nestbox
-- end
-- end
-- end

-- local function create_new_egg_stack (original_eggs, remaining_eggs, creature, caste)

-- print('about to split create new egg stack')
-- print(('type= %s'):format(original_eggs:getType()))
-- print(('creature= %s'):format( creature.creature_id))
-- print(('caste= %s '):format(caste.caste_id))

-- --local created_items = dfhack.items.createItem(creator, original_eggs:getType(), -1, creature.creature_id, caste.caste_id)

-- print('created item')
-- local created_egg_stack = created_items[1]
-- print('about to copy fields from orginal eggs')
-- created_egg_stack.incumabtion_counter = original_eggs.incumabtion_counter
-- created_egg_stack.flags = original_eggs.flags
-- created_egg_stack.flags2 = original_eggs.flags2
-- created_egg_stack.egg_flags = original_eggs.egg_flags
-- created_egg_stack.pos = original_eggs.pos
-- created_egg_stack.hatchling_civ_id = original_eggs.hatchling_civ_id
-- created_egg_stack.mothers_genes = original_eggs.mothers_genes
-- created_egg_stack.mothers_caste = original_eggs.mothers_caste
-- created_egg_stack.mother_hf = original_eggs.mother_hf
-- created_egg_stack.fathers_genes = original_eggs.fathers_genes
-- created_egg_stack.fathers_caste = original_eggs.fathers_caste
-- created_egg_stack.father_hf = original_eggs.father_hf
-- created_egg_stack.hatchling_flags1 = original_eggs.hatchling_flags1
-- created_egg_stack.hatchling_flags2 = original_eggs.hatchling_flags2
-- created_egg_stack.hatchling_flags3 = original_eggs.hatchling_flags3
-- created_egg_stack.hatchling_flags4 = original_eggs.hatchling_flags4
-- created_egg_stack.hatchling_training_level = original_eggs.hatchling_training_level
-- created_egg_stack.hatchling_animal_population = original_eggs.hatchling_animal_population
-- created_egg_stack.mother_id = original_eggs.mother_id

-- print('about to move new stack to nestbox')
-- dfhack.items.moveToContainer(created_egg_stack, find_current_nestbox(original_eggs))
-- end

local function count_forbidden_eggs_for_race_in_claimed_nestobxes(race)
    print_detalis(("start count_forbidden_eggs_for_race_in_claimed_nestobxes"))
    local eggs_count = 0
    for _, nestbox in ipairs(df.global.world.buildings.other.NEST_BOX) do
        if nestbox.claimed_by ~= -1 then
            print_detalis(("Found claimed nextbox"))
            for _, nestbox_contained_item in ipairs(nestbox.contained_items) do
                if nestbox_contained_item.use_mode == df.building_item_role_type.TEMP then
                    print_detalis(("Found claimed nextbox containing items"))
                    if df.item_type.EGG == nestbox_contained_item.item:getType() then
                        print_detalis(("Found claimed nextbox containing items that are eggs"))
                        if nestbox_contained_item.item.egg_flags.fertile and nestbox_contained_item.item.flags.forbid then
                            print_detalis(("Eggs are fertile and forbidden"))
                            if nestbox_contained_item.item.race == race then
                                print_detalis(("Eggs belong to %s"):format(race))
                                print_detalis(
                                    ("eggs_count %s + new %s"):format(
                                        eggs_count,
                                        nestbox_contained_item.item.stack_size
                                    )
                                )
                                eggs_count = eggs_count + nestbox_contained_item.item.stack_size
                                print_detalis(("eggs_count after adding current nestbox %s "):format(eggs_count))
                            end
                        end
                    end
                end
            end
        end
    end
    print_detalis(("end count_forbidden_eggs_for_race_in_claimed_nestobxes"))
    return eggs_count
end

local function get_config_for_race(race)
    print_detalis(("getting config for race %s "):format(race))
    for k, v in pairs(state.target_eggs_count_per_race) do
        if k == race then
            return v
        end
    end
    state.target_eggs_count_per_race[race] = state.default
    persist_state()
    return state.target_eggs_count_per_race[race]
end

local function is_valid_animal(unit)
    return unit and
        dfhack.units.isActive(unit) and
        dfhack.units.isAnimal(unit) and
        dfhack.units.isFortControlled(unit) and
        dfhack.units.isTame(unit) and
        not dfhack.units.isDead(unit)
end

local function count_live_animals(race, count_children, count_adults)
    if count_adults then print_detalis(('we are counting adults for %s'):format(race)) end
    if count_children then print_detalis(('we are counting children and babies for %s'):format(race)) end

    local count = 0
    if not count_adults and not count_children then
        return count
    end

    for _,unit in ipairs(df.global.world.units.active) do
        if race ==  unit.race
        and is_valid_animal(unit)
        and ( (count_adults and dfhack.units.isAdult(unit))
            or (count_children and ( dfhack.units.isChild(unit) or dfhack.units.isBaby(unit)))
            ) then
            count = count + 1
        end
    end
    print_detalis(('found %s life animals'):format(count))
    return count
end

local function handle_eggs(eggs)
    print_detalis(("start handle_eggs"))
    if not eggs.egg_flags.fertile then
        print_local("Newly laid eggs are not fertile, do nothing")
        return
    end

    local race = eggs.race
    local race_config = get_config_for_race(race)
    local max_eggs = race_config[1]
    local count_children = race_config[2]
    local count_adults = race_config[3]

    print_detalis(("max_eggs %s "):format(max_eggs))
    print_detalis(("count_children %s "):format(count_children))
    print_detalis(("count_adults %s "):format(count_adults))

    local current_eggs = eggs.stack_size

    local total_count = current_eggs
    total_count = total_count + count_forbidden_eggs_for_race_in_claimed_nestobxes(race)

    if total_count - current_eggs < max_eggs then
        print_detalis(("Total count for %s only existing eggs is %s, about to count life animals if enabled"):format(race, total_count - current_eggs))
        total_count = total_count + count_live_animals(race, count_children, count_adults)
    else
        print_detalis(("Total count for %s eggs only is %s greater than maximum %s, no need to count life animals"):format(race, total_count, max_eggs))
        return
    end

    print_detalis(("Total count for %s eggs is %s"):format(race, total_count))

    if total_count - current_eggs < max_eggs then
        -- ###if possible split egg stack to forbid only part below max change previous condition to total_count < max_eggs
        -- elseif total_count - current_eggs < max_eggs  and  total_count > max_eggs then
        -- local forbid_eggs =  max_eggs - total_count + current_eggs
        -- local remaining_eggs = current_eggs - forbid_eggs
        -- print('about to split eggs stack')
        -- create_new_egg_stack(eggs, remaining_eggs, df.creature_raw.find(eggs.race), race_creature.caste[eggs.caste])
        -- eggs.stack_size = forbid_eggs
        -- eggs.flags.forbid = true
        -- print(('Total count for %s eggs is %s over maximum %s , forbidden %s eggs out of clutch of %s.'):format(race, total_count, max_eggs, forbid_eggs, current_eggs))
        eggs.flags.forbid = true
        print_local(
            ("Previously existing  %s eggs is %s lower than maximum %s , forbidden %s new eggs."):format(
                race,
                total_count - current_eggs,
                max_eggs,
                current_eggs
            )
        )
    else
        print_local(
            ("Total count for %s eggs is %s over maximum %s, newly laid eggs %s , no action taken."):format(
                race,
                total_count,
                max_eggs,
                current_eggs
            )
        )
    end

    print_detalis(("end handle_eggs"))
end

function check_item_created(item_id)

    local item = df.item.find(item_id)
    if not item or not is_egg(item) then
        return
    end
    handle_eggs(item)
end

local function validate_creature_id(creature_id)
    for i, c in ipairs(df.global.world.raws.creatures.all) do
        if c.creature_id == creature_id then
            return i
        end
    end
    return -1
end

local function set_target(target_race, target_count, count_children, count_adult)

    if target_race == nil or target_race == "" then
        handle_error('must specify "DEFAULT" or valid creature_id')
    end

    local target_race_upper = string.upper(target_race)

    if tonumber(target_count) == nil or tonumber(target_count) < 0 then
        handle_error("No valid target count specified")
    end
    local race = validate_creature_id(target_race_upper)
    if target_race_upper == "DEFAULT" then
        state.default = {tonumber(target_count), stringtoboolean[count_children] or false, stringtoboolean[count_adult] or false}
    elseif race >= 0 then
    print(race)
        state.target_eggs_count_per_race[race] = {tonumber(target_count), stringtoboolean[count_children] or false, stringtoboolean[count_adult] or false}
    else
        handle_error('must specify "DEFAULT" or valid creature_id')
    end
end


if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    dfhack.printerr("eggwatch needs a loaded fortress to work")
    return
end

load_state()
local args, opts = {...}, {}
if dfhack_flags and dfhack_flags.enable then
    args = {dfhack_flags.enable_state and "enable" or "disable"}
end

local positionals =
    argparse.processArgsGetopt(
    args,
    {
        {"h", "help", handler = function()
                opts.help = true
            end}
    }
)

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        do_enable()
        print_status()
        else
        do_disable()
        print_status()
    end
end

local command = positionals[1]

if command == "help" or opts.help then
    print(dfhack.script_help())
elseif command == "target" then
    set_target(positionals[2], positionals[3], positionals[4],  positionals[5])
    print_status()
elseif command == "verbose" then
    state.verbose = not state.verbose
    print_status()
elseif command == 'clear' then
    state = get_default_state()
    update_event_listener()
elseif not command or command == "status" then
    print_status()
elseif (command ~= 'enable' or command ~= 'disable') and not dfhack_flags.enable then
    handle_error(('Command "%s" is not recognized'):format(command))
end
persist_state()
