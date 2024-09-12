--@enable = true
--@module = true

local argparse = require("argparse")
local eventful = require("plugins.eventful")
local utils = require("utils")

local GLOBAL_KEY = "eggwatch"
local default_table = {10, false, false, false}

local function get_default_state()
    return {
        enabled = false,
        verbose = false,
        default = default_table,
        EVENT_FREQ = 7,
        split_stacks = true,
        migration_from_cpp_to_lua_done = false,
        target_eggs_count_per_race = {}
    }
end

state = state or get_default_state()

function isEnabled()
    return state.enabled
end

local function dump(o)
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

local string_or_int_to_boolean = {["true"] = true, ["false"] = false, ["1"] = true, ["0"] = false, ["Y"] = true, ["N"] = false, [1] = true, [0] = false}


local function print_local(text)
    print(GLOBAL_KEY .. ": " .. text)
end

local function handle_error(text)
    qerror(text)
end

local function print_details(details)
    if state.verbose then
        print_local(details)
    end
end

local function format_target_count_row(header, row)
    return header ..
        ": " ..
            "target count: " ..
                row[1] .. "; count children: " .. tostring(row[2]) .. "; count adults: " .. tostring(row[3])
end

local function print_status()
    print_local((GLOBAL_KEY .. " is currently %s."):format(state.enabled and "enabled" or "disabled"))
    print_local(("egg stack splitting is %s"):format(state.split_stacks and "enabled" or "disabled"))
    print_local(format_target_count_row("Default", state.default))
    if state.target_eggs_count_per_race ~= nil then
        for k, v in pairs(state.target_eggs_count_per_race) do
            print_local(format_target_count_row(df.global.world.raws.creatures.all[k].creature_id, v))
        end
    end
    print_details("verbose mode enabled")
    print_details(dump(state))
end

local function persist_state()
    print_details(("start persist_state"))
    local state_to_persist = {}
    state_to_persist = utils.clone(state)
    state_to_persist.target_eggs_count_per_race = {}
    if state.target_eggs_count_per_race ~= nil then
        for k, v in pairs(state.target_eggs_count_per_race) do
            state_to_persist.target_eggs_count_per_race[tostring(k)] = v
        end
    end
    dfhack.persistent.saveSiteData(GLOBAL_KEY, state_to_persist)
    print_details(("end persist_state"))
end

local function read_persistent_config(key, index)
    if dfhack.internal.readPersistentSiteConfigInt ~= nil then 
        return dfhack.internal.readPersistentSiteConfigInt(key, index) 
    else 
        return nil
    end
end

local function migrate_enabled_status_from_cpp_nestboxes()
    print_local("About to attempt migration from cpp to lua")
    local nestboxes_status = read_persistent_config("nestboxes/config", "0")
    print_local(("Migrating status %s from cpp nestboxes to lua"):format(string_or_int_to_boolean[nestboxes_status] and "enabled" or "disabled"))
    state.enabled = string_or_int_to_boolean[nestboxes_status] or false
    state.migration_from_cpp_to_lua_done = true
    dfhack.persistent['deleteSiteData']("nestboxes/config")
    persist_state()
    print_local("Migrating from cpp to lua done")
end

--- Load the saved state of the script
local function load_state()
    print_details(("start load_state"))
    -- load persistent data
    local persisted_data = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    local processed_persisted_data = {}
    if persisted_data ~= nil then
        processed_persisted_data = utils.clone(persisted_data)
        processed_persisted_data.target_eggs_count_per_race = {}
        if persisted_data.target_eggs_count_per_race ~= nil then
            for k, v in pairs(persisted_data.target_eggs_count_per_race) do
                processed_persisted_data.target_eggs_count_per_race[tonumber(k)] = v
            end
        end
    end

    state = get_default_state()
    utils.assign(state, processed_persisted_data)

    if not state.migration_from_cpp_to_lua_done then
        migrate_enabled_status_from_cpp_nestboxes()
    end

    print_details(("end load_state"))
end

local function update_event_listener()
    print_details(("start update_event_listener"))
    if state.enabled then
        eventful.enableEvent(eventful.eventType.ITEM_CREATED, state.EVENT_FREQ)
        eventful.onItemCreated[GLOBAL_KEY] = check_item_created
        print_local(("Subscribing in eventful for %s with frequency %s"):format("ITEM_CREATED", state.EVENT_FREQ))
    else
        eventful.onItemCreated[GLOBAL_KEY] = nil
        print_local(("Unregistering from eventful for %s"):format("ITEM_CREATED"))
    end
    print_details(("end update_event_listener"))
end

local function do_enable()
    print_details(("start do_enable"))
    state.enabled = true
    update_event_listener()
    print_details(("end do_enable"))
end

local function do_disable()
    print_details(("start do_disable"))
    state.enabled = false
    update_event_listener()
    print_details(("end do_disable"))
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

local function is_egg(item)
    return df.item_type.EGG == item:getType()
end

local function copy_egg_fields(source_egg, target_egg)
    print_details("start copy_egg_fields")
    target_egg.incubation_counter = source_egg.incubation_counter
    print_details("incubation_counter done")
    target_egg.egg_flags = utils.clone(source_egg.egg_flags, true)
    target_egg.hatchling_flags1 = utils.clone(source_egg.hatchling_flags1, true)
    target_egg.hatchling_flags2 = utils.clone(source_egg.hatchling_flags2, true)
    target_egg.hatchling_flags3 = utils.clone(source_egg.hatchling_flags3, true)
    target_egg.hatchling_flags4 = utils.clone(source_egg.hatchling_flags4, true)
    print_details("flags done")
    target_egg.hatchling_training_level = utils.clone(source_egg.hatchling_training_level, true)
    utils.assign(target_egg.hatchling_animal_population, source_egg.hatchling_animal_population)
    print_details("hatchling_animal_population done")
    target_egg.hatchling_mother_id = source_egg.hatchling_mother_id
    print_details("hatchling_mother_id done")
    target_egg.mother_hf = source_egg.mother_hf
    target_egg.father_hf = source_egg.mother_hf
    print_details("mother_hf father_hf done")
    target_egg.mothers_caste = source_egg.mothers_caste
    target_egg.fathers_caste = source_egg.fathers_caste
    print_details("mothers_caste fathers_caste  done")
    target_egg.mothers_genes = source_egg.mothers_genes
    target_egg.fathers_genes = source_egg.fathers_genes
    print_details("mothers_genes fathers_genes  done")
    target_egg.hatchling_civ_id = source_egg.hatchling_civ_id
    print_details("hatchling_civ_id done")
    print_details("end copy_egg_fields")
end

local function resize_egg_stack(egg_stack, new_stack_size)
    print_details("start resize_egg_stack")
    egg_stack.stack_size = new_stack_size
    --TODO check if weight or size need adjustment
    print_details("end resize_egg_stack")
end

local function create_new_egg_stack(original_eggs, remaining_eggs)
    print_details("start create_new_egg_stack")

    print_details("about to split create new egg stack")
    print_details(("type= %s"):format(original_eggs:getType()))
    print_details(("creature= %s"):format(original_eggs.race))
    print_details(("caste= %s "):format(original_eggs.caste))
    print_details(remaining_eggs)

    local created_items =
        dfhack.items.createItem(
        df.unit.find(original_eggs.hatchling_mother_id),
        original_eggs:getType(),
        -1,
        original_eggs.race,
        original_eggs.caste
    )
    print_details("created new egg stack")
    local created_egg_stack = created_items[0] or created_items[1]
    print_details(df.creature_raw.find(created_egg_stack.race).creature_id)
    print_details("about to copy fields from orginal eggs")
    copy_egg_fields(original_eggs, created_egg_stack)

    print_details("about to resize new egg stack")
    resize_egg_stack(created_egg_stack, remaining_eggs)

    print_details("about to move new stack to nestbox")
    if dfhack.items.moveToBuilding(created_egg_stack, dfhack.items.getHolderBuilding(original_eggs)) then
        print_details("moved new egg stack to nestbox")
    else
        print_local("move of separated eggs to nestbox  failed")
    end
    print_details("end create_new_egg_stack")
end

local function split_egg_stack(source_egg_stack, to_be_left_in_source_stack)
    print_details("start split_egg_stack")
    local egg_count_in_new_stack_size = source_egg_stack.stack_size - to_be_left_in_source_stack
    if egg_count_in_new_stack_size > 0 then
        create_new_egg_stack(source_egg_stack, egg_count_in_new_stack_size)
        resize_egg_stack(source_egg_stack, to_be_left_in_source_stack)
    else
        print_details("nothing to do, wrong egg_count_in_new_stack_size")
    end
    print_details("end split_egg_stack")
end

local function count_forbidden_eggs_for_race_in_claimed_nestobxes(race)
    print_details(("start count_forbidden_eggs_for_race_in_claimed_nestobxes"))
    local eggs_count = 0
    for _, nestbox in ipairs(df.global.world.buildings.other.NEST_BOX) do
        if nestbox.claimed_by ~= -1 then
            print_details(("Found claimed nextbox"))
            for _, nestbox_contained_item in ipairs(nestbox.contained_items) do
                if nestbox_contained_item.use_mode == df.building_item_role_type.TEMP then
                    print_details(("Found claimed nextbox containing items"))
                    if df.item_type.EGG == nestbox_contained_item.item:getType() then
                        print_details(("Found claimed nextbox containing items that are eggs"))
                        if nestbox_contained_item.item.egg_flags.fertile and nestbox_contained_item.item.flags.forbid then
                            print_details(("Eggs are fertile and forbidden"))
                            if nestbox_contained_item.item.race == race then
                                print_details(("Eggs belong to %s"):format(race))
                                print_details(
                                    ("eggs_count %s + new %s"):format(
                                        eggs_count,
                                        nestbox_contained_item.item.stack_size
                                    )
                                )
                                eggs_count = eggs_count + nestbox_contained_item.item.stack_size
                                print_details(("eggs_count after adding current nestbox %s "):format(eggs_count))
                            end
                        end
                    end
                end
            end
        end
    end
    print_details(("end count_forbidden_eggs_for_race_in_claimed_nestobxes"))
    return eggs_count
end

local function get_config_for_race(race)
    print_details(("start get_config_for_race"))
    print_details(("getting config for race %s "):format(race))
    for k, v in pairs(state.target_eggs_count_per_race) do
        if k == race then
            print_details(("end 1 get_config_for_race"))
            return v
        end
    end
    state.target_eggs_count_per_race[race] = state.default
    persist_state()
    print_details(("end 2 get_config_for_race"))
    return state.target_eggs_count_per_race[race]
end

local function is_valid_animal(unit)
    return unit and dfhack.units.isActive(unit) and dfhack.units.isAnimal(unit) and dfhack.units.isFortControlled(unit) and
        dfhack.units.isTame(unit) and
        not dfhack.units.isDead(unit)
end

local function count_live_animals(race, count_children, count_adults)
    print_details(("start count_live_animals"))
    if count_adults then
        print_details(("we are counting adults for %s"):format(race))
    end
    if count_children then
        print_details(("we are counting children and babies for %s"):format(race))
    end

    local count = 0
    if not count_adults and not count_children then
        print_details(("end 1 count_live_animals"))
        return count
    end

    for _, unit in ipairs(df.global.world.units.active) do
        if
            race == unit.race and is_valid_animal(unit) and
                ((count_adults and dfhack.units.isAdult(unit)) or
                    (count_children and (dfhack.units.isChild(unit) or dfhack.units.isBaby(unit))))
         then
            count = count + 1
        end
    end
    print_details(("found %s life animals"):format(count))
    print_details(("end 2 count_live_animals"))
    return count
end

local function validate_eggs(eggs)
    if not eggs.egg_flags.fertile then
        print_details("Newly laid eggs are not fertile, do nothing")
        return false
    end

    local should_be_nestbox = dfhack.items.getHolderBuilding(eggs)
    if should_be_nestbox ~= nil then
        for _, nestbox in ipairs(df.global.world.buildings.other.NEST_BOX) do
            if nestbox == should_be_nestbox then
                print_details("Found nestbox, continue with egg handling")
                return true
            end
        end
        print_details("Newly laid eggs are in building different than nestbox, we were to late")
        return false
    else
        print_details("Newly laid eggs are not in building, we were to late")
        return false
    end
    return true
end

local function handle_eggs(eggs)
    print_details(("start handle_eggs"))

    if not validate_eggs(eggs) then
        return
    end

    local race = eggs.race
    local race_config = get_config_for_race(race)
    local max_eggs = race_config[1]
    local count_children = race_config[2]
    local count_adults = race_config[3]
    local ignore = race_config[4]

    if ignore then
        print_details(("race is ignored, nothing to do here"))
        return
    end

    print_details(("max_eggs %s "):format(max_eggs))
    print_details(("count_children %s "):format(count_children))
    print_details(("count_adults %s "):format(count_adults))

    local current_eggs = eggs.stack_size

    local total_count = current_eggs
    total_count = total_count + count_forbidden_eggs_for_race_in_claimed_nestobxes(race)

    if total_count - current_eggs < max_eggs then
        print_details(
            ("Total count for %s only existing eggs is %s, about to count life animals if enabled"):format(
                race,
                total_count - current_eggs
            )
        )
        total_count = total_count + count_live_animals(race, count_children, count_adults)
    else
        print_details(
            ("Total count for %s eggs only is %s greater than maximum %s, no need to count life animals"):format(
                race,
                total_count,
                max_eggs
            )
        )
        print_details(("end 1 handle_eggs"))
        return
    end

    print_details(("Total count for %s eggs is %s"):format(race, total_count))

    if total_count - current_eggs < max_eggs then
    local egg_count_to_leave_in_source_stack = current_eggs
        if state.split_stacks and total_count > max_eggs then
             egg_count_to_leave_in_source_stack = max_eggs - total_count + current_eggs
            split_egg_stack(eggs, egg_count_to_leave_in_source_stack)
        end

        eggs.flags.forbid = true

        if eggs.flags.in_job then
            local job_ref = dfhack.items.getSpecificRef(eggs, df.specific_ref_type.JOB)
            if job_ref then
                print_details(("About to remove job related to egg(s)"))
                dfhack.job.removeJob(job_ref.data.job)
                eggs.flags.in_job = false
            end
        end

        print_local(
            ("Previously existing  %s egg(s) is %s lower than maximum %s , forbidden %s egg(s) out of %s new"):format(
                race,
                total_count - current_eggs,
                max_eggs,
                egg_count_to_leave_in_source_stack,
                current_eggs
            )
        )
    else
        print_local(
            ("Total count for %s egg(s) is %s over maximum %s, newly laid egg(s) %s , no action taken."):format(
                race,
                total_count,
                max_eggs,
                current_eggs
            )
        )
    end
    print_details(("end 2 handle_eggs"))
end

function check_item_created(item_id)
    --print_details(("start check_item_created"))
    local item = df.item.find(item_id)
    if not item or not is_egg(item) then
        --print_details(("end 1 check_item_created"))
        return
    end
    --print_local(("item_id for original eggs: %s"):format (item_id))
    handle_eggs(item)
    --print_details(("end 2 check_item_created"))
end

local function validate_creature_id(creature_id)
    print_details(("start validate_creature_id"))
    for i, c in ipairs(df.global.world.raws.creatures.all) do
        if c.creature_id == creature_id then
            print_details(("end 1 validate_creature_id"))
            return i
        end
    end
    print_details(("end 2 validate_creature_id"))
    return -1
end

local function set_target(target_race, target_count, count_children, count_adult, ignore)
    print_details(("start set_target"))

    if target_race == nil or target_race == "" then
        handle_error("must specify DEFAULT or valid creature_id")
    end

    local target_race_upper = string.upper(target_race)

    if tonumber(target_count) == nil or tonumber(target_count) < 0 then
        handle_error("No valid target count specified")
    end
    local race = validate_creature_id(target_race_upper)
    if target_race_upper == "DEFAULT" then
        state.default = {
            tonumber(target_count),
            string_or_int_to_boolean[count_children] or false,
            string_or_int_to_boolean[count_adult] or false,
            string_or_int_to_boolean[ignore] or false
        }
    elseif race >= 0 then
        print(race)
        state.target_eggs_count_per_race[race] = {
            tonumber(target_count),
            string_or_int_to_boolean[count_children] or false,
            string_or_int_to_boolean[count_adult] or false,
            string_or_int_to_boolean[ignore] or false
        }
    else
        handle_error("must specify DEFAULT or valid creature_id")
    end
    print_details(("end set_target"))
end

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    dfhack.printerr(GLOBAL_KEY .. " needs a loaded fortress to work")
    return
end

if dfhack_flags.module then
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
        {
            "h",
            "help",
            handler = function()
                opts.help = true
            end
        }
    }
)


local command = positionals[1]

if command == "help" or opts.help then
    print(dfhack.script_help())
elseif command == "enable" then
    do_enable()
elseif command == "disable" then
    do_disable()
elseif command == "target" then
    set_target(positionals[2], positionals[3], positionals[4], positionals[5], positionals[6])
    print_status()
elseif command == "verbose" then
    state.verbose = string_or_int_to_boolean[positionals[2]]
    print_status()
elseif command == "clear" then
    state = get_default_state()
    update_event_listener()
elseif command == "split_stacks" then
    state.split_stacks = string_or_int_to_boolean[positionals[2]]
    print_status()
elseif not command or command == "status" then
    print_status()
else
    handle_error(("Command '% s' is not recognized"):format(command))
end
persist_state()
