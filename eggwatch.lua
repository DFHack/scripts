local argparse = require("argparse")
local eventful = require("plugins.eventful")

local GLOBAL_KEY = "eggwatch"
local EVENT_FREQ = 5
local print_prefix = "eggwatch: "

enabled = enabled or false
default_table = {}
default_table.DEFAULT = 10
function isEnabled()
    return enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(
        GLOBAL_KEY,
        {
            enabled = enabled,
            verbose = verbose,
            target_eggs_count_per_race = target_eggs_count_per_race
        }
    )
end

--- Load the saved state of the script
local function load_state()
    -- load persistent data
    local persisted_data = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    enabled = persisted_data.enabled or false
    verbose = persisted_data.verbose or false
    target_eggs_count_per_race = persisted_data.target_eggs_count_per_race or default_table
end

if dfhack_flags.module then
    return
end
local function print_local(text)
    print(print_prefix .. text)
end
local function handle_error(text)
    qerror(text)
end
local function print_status()
    print_local(("eggwatch is currently %s."):format(enabled and "enabled" or "disabled"))
    if verbose then
        print_local("eggwatch is in verbose mode")
    end
end

local function print_detalis(details)
    if verbose then
        print_local(details)
    end
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

local function count_forbidden_eggs_for_race_in_claimed_nestobxes(race_creature_id)
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
                            if df.creature_raw.find(nestbox_contained_item.item.race).creature_id == race_creature_id then
                                print_detalis(("Eggs belong to %s"):format(race_creature_id))
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
local function get_max_eggs_for_race(race_creature_id)
    for k, v in pairs(target_eggs_count_per_race) do
        if k == race_creature_id then
            return v
        end
    end
    target_eggs_count_per_race[race_creature_id] = target_eggs_count_per_race.DEFAULT
    persist_state()
    return target_eggs_count_per_race[race_creature_id]
end
local function handle_eggs(eggs)
    print_detalis(("start handle_eggs"))
    if not eggs.egg_flags.fertile then
        print_local("Newly laid eggs are not fertile, do nothing")
        return
    end

    local race_creature_id = df.creature_raw.find(eggs.race).creature_id
    local max_eggs = get_max_eggs_for_race(race_creature_id)
    local current_eggs = eggs.stack_size

    local total_count = current_eggs
    total_count = total_count + count_forbidden_eggs_for_race_in_claimed_nestobxes(race_creature_id)

    print_detalis(("Total count for %s eggs is %s"):format(race_creature_id, total_count))

    if total_count - current_eggs < max_eggs then
        -- ###if possible split egg stack to forbid only part below max change previous condition to total_count < max_eggs
        -- elseif total_count - current_eggs < max_eggs  and  total_count > max_eggs then
        -- local forbid_eggs =  max_eggs - total_count + current_eggs
        -- local remaining_eggs = current_eggs - forbid_eggs
        -- print('about to split eggs stack')
        -- create_new_egg_stack(eggs, remaining_eggs, df.creature_raw.find(eggs.race), race_creature.caste[eggs.caste])
        -- eggs.stack_size = forbid_eggs
        -- eggs.flags.forbid = true
        -- print(('Total count for %s eggs is %s over maximum %s , forbidden %s eggs out of clutch of %s.'):format(race_creature_id, total_count, max_eggs, forbid_eggs, current_eggs))
        eggs.flags.forbid = true
        print_local(
            ("Previously existing  %s eggs is %s lower than maximum %s , forbidden %s new eggs."):format(
                race_creature_id,
                total_count - current_eggs,
                max_eggs,
                current_eggs
            )
        )
    else
        print_local(
            ("Total count for %s eggs is %s over maximum %s, newly laid eggs %s , no action taken."):format(
                race_creature_id,
                total_count,
                max_eggs,
                current_eggs
            )
        )
    end
    
    print_detalis(("end handle_eggs"))
end

local function check_item_created(item_id)
    local item = df.item.find(item_id)
    if not item or not is_egg(item) then
        return
    end
    handle_eggs(item)
end
local function do_enable()
    enabled = true
    eventful.enableEvent(eventful.eventType.ITEM_CREATED, EVENT_FREQ)
    eventful.onItemCreated[GLOBAL_KEY] = check_item_created
end

local function do_disable()
    enabled = false
    eventful.onItemCreated[GLOBAL_KEY] = nil
end

local function validate_creature_id(creature_id)
    for i, c in ipairs(df.global.world.raws.creatures.all) do
        if c.creature_id == creature_id then
            return true
        end
    end
    return false
end

local function set_target(target_race, target_count)
    if target_race == nil or target_race == "" then
        handle_error('must specify "DEFAULT" or valid creature_id')
    end
    local target_race_upper = string.upper(target_race)
    if tonumber(target_count) == nil or tonumber(target_count) < 0 then
        handle_error("No valid target count specified")
    end
    if target_race_upper == "DEFAULT" or validate_creature_id(target_race_upper) then
        target_eggs_count_per_race[target_race_upper] = tonumber(target_count)
    else
        handle_error('must specify "DEFAULT" or valid creature_id')
    end

    print_local(dump(target_eggs_count_per_race))
end
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

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    dfhack.printerr("eggwatch needs a loaded fortress to work")
    return
end

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

load_state()
local command = positionals[1]

if command == "help" or opts.help then
    print(dfhack.script_help())
elseif command == "enable" then
    do_enable()
    print_status()
elseif command == "disable" then
    do_disable()
    print_status()
elseif command == "target" then
    set_target(positionals[2], positionals[3])
    print_status()
elseif command == "verbose" then
    verbose = not verbose
    print_status()
elseif command == 'clear' then
target_eggs_count_per_race = default_table

elseif not command or command == "status" then
    print_status()
    print_local(dump(target_eggs_count_per_race))
end
persist_state()
