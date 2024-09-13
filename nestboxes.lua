--@enable = true
--@module = true

local argparse = require("argparse")
local eventful = require("plugins.eventful")
local utils = require("utils")
local nestboxes_common = reqscript("internal/nestboxes/common")
local print_local = nestboxes_common.print_local
local print_details = nestboxes_common.print_details
local handle_error = nestboxes_common.handle_error
local GLOBAL_KEY = "nestboxes"
local EVENT_FREQ = 7
local default_table = {10, false, false, false}
local string_or_int_to_boolean = {
    ["true"] = true,
    ["false"] = false,
    ["1"] = true,
    ["0"] = false,
    ["Y"] = true,
    ["N"] = false,
    [1] = true,
    [0] = false
}
---------------------------------------------------------------------------------------------------
local function get_default_state()
    return {
        enabled = false,
        verbose = false,
        default = default_table,
        split_stacks = true,
        migration_from_cpp_to_lua_done = false,
        target_eggs_count_per_race = {}
    }
end

state = state or get_default_state()
-- isEnabled added for enabled API
function isEnabled()
    return state.enabled
end
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--<State change functions>
function persist_state()
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
---------------------------------------------------------------------------------------------------
local function read_persistent_config(key, index)
    if dfhack.internal.readPersistentSiteConfigInt ~= nil then
        return dfhack.internal.readPersistentSiteConfigInt(key, index)
    else
        return nil
    end
end
---------------------------------------------------------------------------------------------------
local function migrate_enabled_status_from_cpp_nestboxes()
    print_local("About to attempt migration from cpp to lua")
    local nestboxes_status = read_persistent_config("nestboxes/config", "0")
    print_local(
        ("Migrating status %s from cpp nestboxes to lua"):format(
            string_or_int_to_boolean[nestboxes_status] and "enabled" or "disabled"
        )
    )
    state.enabled = string_or_int_to_boolean[nestboxes_status] or false
    state.migration_from_cpp_to_lua_done = true
    dfhack.persistent["deleteSiteData"]("nestboxes/config")
    persist_state()
    print_local("Migrating from cpp to lua done")
end
---------------------------------------------------------------------------------------------------
local function init_nestboxes_common()
    nestboxes_common.verbose = state.verbose
    nestboxes_common.GLOBAL_KEY = GLOBAL_KEY
end
---------------------------------------------------------------------------------------------------
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
                local default = utils.clone(default_table)
                processed_persisted_data.target_eggs_count_per_race[tonumber(k)] = utils.assign(default, v)
            end
        end
    end

    state = get_default_state()
    utils.assign(state, processed_persisted_data)

    if not state.migration_from_cpp_to_lua_done then
        migrate_enabled_status_from_cpp_nestboxes()
    end

    init_nestboxes_common()
    print_details(("end load_state"))
end
---------------------------------------------------------------------------------------------------
local function update_event_listener()
    print_details(("start update_event_listener"))
    if state.enabled then
        eventful.enableEvent(eventful.eventType.ITEM_CREATED, EVENT_FREQ)
        eventful.onItemCreated[GLOBAL_KEY] = check_item_created
        print_local(("Subscribing in eventful for %s with frequency %s"):format("ITEM_CREATED", EVENT_FREQ))
    else
        eventful.onItemCreated[GLOBAL_KEY] = nil
        print_local(("Unregistering from eventful for %s"):format("ITEM_CREATED"))
    end
    print_details(("end update_event_listener"))
end
---------------------------------------------------------------------------------------------------
local function do_enable()
    print_details(("start do_enable"))
    state.enabled = true
    update_event_listener()
    print_details(("end do_enable"))
end
---------------------------------------------------------------------------------------------------
local function do_disable()
    print_details(("start do_disable"))
    state.enabled = false
    update_event_listener()
    print_details(("end do_disable"))
end
--<State change functions/>
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--<event handling functions>
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
---------------------------------------------------------------------------------------------------
-- check_item_created function, called from eventfful on ITEM_CREATED event
function check_item_created(item_id)
    local item = df.item.find(item_id)
    if item == nil or df.item_type.EGG ~= item:getType() then
        return
    else
        local nestboxes_event = reqscript("internal/nestboxes/event")
        if nestboxes_event.validate_eggs(item) then
            local race_config = get_config_for_race(item.race)
            nestboxes_event.handle_eggs(item, race_config, state.split_stacks)
        end
    end
end
--<event handling functions/>
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--<Input handling functions>
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
---------------------------------------------------------------------------------------------------
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
---------------------------------------------------------------------------------------------------
local function set_split_stacks(value)
    state.split_stacks = string_or_int_to_boolean[value]
end
---------------------------------------------------------------------------------------------------
local function clear_config(value)
    state = get_default_state()
    update_event_listener()
end
---------------
local function set_verbose(value)
    state.verbose = string_or_int_to_boolean[value]
    nestboxes_common.verbose = state.verbose
end
--<Input handling functions/>
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--<Output handling functions>
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
---------------------------------------------------------------------------------------------------
local function format_target_count_row(category, row)
    return category ..
        ": " ..
            "target count: " ..
                row[1] ..
                    "; count children: " ..
                        tostring(row[2]) ..
                            "; count adults: " .. tostring(row[3]) .. "; ignore race: " .. tostring(row[4])
end
---------------------------------------------------------------------------------------------------
local function print_status()
    print_local((GLOBAL_KEY .. " is currently %s."):format(state.enabled and "enabled" or "disabled"))
    print_local(("Egg stack splitting is %s"):format(state.split_stacks and "enabled" or "disabled"))
    print_local(format_target_count_row("Default", state.default))
    if state.target_eggs_count_per_race ~= nil then
        for k, v in pairs(state.target_eggs_count_per_race) do
            print_local(format_target_count_row(df.global.world.raws.creatures.all[k].creature_id, v))
        end
    end
    print_details("verbose mode enabled")
    print_details(dump(state))
end
--<Output handling functions/>
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

if dfhack_flags.module then
    return
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        do_disable()
        if state.unforbid_eggs then
            repeatutil.cancel(GLOBAL_KEY)
        end
        return
    end
    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end
    load_state()
    print_status()
    update_event_listener()
    schedule_loop()
end

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    dfhack.printerr(GLOBAL_KEY .. " needs a loaded fortress to work")
    return
end

load_state()

local args, opts = {...}, {}

if dfhack_flags and dfhack_flags.enable then
    args = {dfhack_flags.enable_state and "ENABLE" or "DISABLE"}
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

if command ~= nil then
    command = string.upper(command)
end

if command == "HELP" or opts.help then
    print(dfhack.script_help())
elseif command == "ENABLE" then
    do_enable()
elseif command == "DISABLE" then
    do_disable()
elseif command == "TARGET" then
    set_target(positionals[2], positionals[3], positionals[4], positionals[5], positionals[6])
elseif command == "VERBOSE" then
    set_verbose(positionals[2])
elseif command == "CLEAR" then
    clear_config()
elseif command == "SPLIT_STACKS" then
    set_split_stacks(positionals[2])
elseif positionals[1] ~= nil then
    handle_error(("Command '% s' is not recognized"):format(positionals[1]))
end

print_status()
persist_state()
