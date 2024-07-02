--@module = true
--@enable = true

local argparse = require('argparse')
local repeatutil = require("repeat-util")
local utils = require('utils')

DEBUG = DEBUG or false

------------------------------------
-- state management

local GLOBAL_KEY = 'timestream'

local SETTINGS = {
    {
        name='fps',
        validate=function(arg)
            local val = argparse.positiveInt(arg, 'fps')
            if val < 10 then qerror('target fps must be at least 10') end
            return val
        end,
        default=function() return df.global.init.fps_cap end,
    },
    {
        name='calendar-rate',
        internal_name='calendar_rate',
        validate=function(arg)
            local val = tonumber(arg)
            if not val or val <= 0 then qerror('calendar-rate must be larger than 0') end
            return val
        end,
        default=1.0,
    },
}

local function get_default_state()
    local settings = {}
    for _, v in ipairs(SETTINGS) do
        settings[v.internal_name or v.name] = utils.getval(v.default)
    end
    return {
        enabled=false,
        settings=settings,
    }
end

state = state or get_default_state()

function isEnabled()
    return state.enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, state)
end

------------------------------------
-- business logic

-- ensure we never skip over cur_year_tick values that match this list
local TICK_TRIGGERS = {
    {mod=10, rem={0}}, -- season ticks and (mod=100) crop growth
}

-- "owed" ticks we would like to skip at the next opportunity
local timeskip_deficit, calendar_timeskip_deficit = 0.0, 0.0

local function get_desired_timeskip(real_fps, desired_fps)
    -- minus 1 to account for the current frame
    return (desired_fps / real_fps) - 1
end

local function get_next_trigger_year_tick(next_tick)
    local next_trigger_tick = math.huge
    for _, trigger in ipairs(TICK_TRIGGERS) do
        local cur_rem = next_tick % trigger.mod
        for _, rem in ipairs(trigger.rem) do
            if cur_rem <= rem then
                next_trigger_tick = math.min(next_trigger_tick, next_tick + (rem - cur_rem))
                goto continue
            end
        end
        next_trigger_tick = math.min(next_trigger_tick, next_tick + trigger.mod - cur_rem + trigger.rem[#trigger.rem])
        ::continue::
    end
    return next_trigger_tick
end

local function clamp_timeskip(timeskip)
    if timeskip <= 0 then return 0 end
    local next_tick = df.global.cur_year_tick + 1
    return math.min(timeskip, get_next_trigger_year_tick(next_tick)-next_tick)
end

local function increment_counter(obj, counter_name, timeskip)
    if obj[counter_name] <= 0 then return end
    obj[counter_name] = obj[counter_name] + timeskip
end

local function decrement_counter(obj, counter_name, timeskip)
    if obj[counter_name] <= 0 then return end
    obj[counter_name] = math.max(1, obj[counter_name] - timeskip)
end

local function adjust_unit_counters(unit, timeskip)
    local c1 = unit.counters
    decrement_counter(c1, 'think_counter', timeskip)
    decrement_counter(c1, 'job_counter', timeskip)
    decrement_counter(c1, 'swap_counter', timeskip)
    decrement_counter(c1, 'winded', timeskip)
    decrement_counter(c1, 'stunned', timeskip)
    decrement_counter(c1, 'unconscious', timeskip)
    decrement_counter(c1, 'suffocation', timeskip)
    decrement_counter(c1, 'webbed', timeskip)
    decrement_counter(c1, 'soldier_mood_countdown', timeskip)
    decrement_counter(c1, 'pain', timeskip)
    decrement_counter(c1, 'nausea', timeskip)
    decrement_counter(c1, 'dizziness', timeskip)
    local c2 = unit.counters2
    decrement_counter(c2, 'paralysis', timeskip)
    decrement_counter(c2, 'numbness', timeskip)
    decrement_counter(c2, 'fever', timeskip)
    decrement_counter(c2, 'exhaustion', timeskip * 3)
    increment_counter(c2, 'hunger_timer', timeskip)
    increment_counter(c2, 'thirst_timer', timeskip)
    local job = unit.job.current_job
    if job and job.job_type == df.job_type.Rest then
        decrement_counter(c2, 'sleepiness_timer', timeskip * 200)
    elseif job and job.job_type == df.job_type.Sleep then
        decrement_counter(c2, 'sleepiness_timer', timeskip * 19)
    else
        increment_counter(c2, 'sleepiness_timer', timeskip)
    end
    decrement_counter(c2, 'stomach_content', timeskip * 5)
    decrement_counter(c2, 'stomach_food', timeskip * 5)
    decrement_counter(c2, 'vomit_timeout', timeskip)
    -- stored_fat wanders about based on other state; we can probably leave it alone
end

-- unit needs appear to be incremented on season ticks, so we don't need to worry about those
local function adjust_units(timeskip)
    for _, unit in ipairs(df.global.world.units.active) do
        if not dfhack.units.isActive(unit) then goto continue end
        decrement_counter(unit, 'pregnancy_timer', timeskip)
        dfhack.units.subtractGroupActionTimers(unit, timeskip, df.unit_action_type_group.All)
        if not dfhack.units.isOwnGroup(unit) then goto continue end
        adjust_unit_counters(unit, timeskip)
        ::continue::
    end
end

-- behavior ascertained from in-game observation
local function adjust_activities(timeskip)
    for i, act in ipairs(df.global.world.activities.all) do
        for _, ev in ipairs(act.events) do
            if df.activity_event_training_sessionst:is_instance(ev) then
                -- no counters
            elseif df.activity_event_combat_trainingst:is_instance(ev) then
                -- has organize_counter at a non-zero value, but it doesn't seem to move
            elseif df.activity_event_skill_demonstrationst:is_instance(ev) then
                -- can be negative or positive, but always counts towards 0
                if ev.organize_counter < 0 then
                    ev.organize_counter = math.min(-1, ev.organize_counter + timeskip)
                else
                    decrement_counter(ev, 'organize_counter', timeskip)
                end
                decrement_counter(ev, 'train_countdown', timeskip)
            elseif df.activity_event_fill_service_orderst:is_instance(ev) then
                -- no counters
            elseif df.activity_event_individual_skill_drillst:is_instance(ev) then
                -- only counts down on season ticks, nothing to do here
            elseif df.activity_event_sparringst:is_instance(ev) then
                decrement_counter(ev, 'countdown', timeskip * 2)
            elseif df.activity_event_ranged_practicest:is_instance(ev) then
                -- countdown appears to never move from 0
                decrement_counter(ev, 'countdown', timeskip)
            elseif df.activity_event_harassmentst:is_instance(ev) then
                -- TODO: counter behavior not yet analyzed
                -- print(i)
            elseif df.activity_event_encounterst:is_instance(ev) then
                -- TODO: counter behavior not yet analyzed
                -- print(i)
            elseif df.activity_event_reunionst:is_instance(ev) then
                -- TODO: counter behavior not yet analyzed
                -- print(i)
            elseif df.activity_event_conversationst:is_instance(ev) then
                increment_counter(ev, 'pause', timeskip)
            elseif df.activity_event_guardst:is_instance(ev) then
                -- no counters
            elseif df.activity_event_conflictst:is_instance(ev) then
                increment_counter(ev, 'inactivity_timer', timeskip)
                increment_counter(ev, 'attack_inactivity_timer', timeskip)
                increment_counter(ev, 'stop_fort_fights_timer', timeskip)
            elseif df.activity_event_prayerst:is_instance(ev) then
                decrement_counter(ev, 'timer', timeskip)
            elseif df.activity_event_researchst:is_instance(ev) then
                -- no counters
            elseif df.activity_event_playst:is_instance(ev) then
                increment_counter(ev, 'down_time_counter', timeskip)
            elseif df.activity_event_worshipst:is_instance(ev) then
                increment_counter(ev, 'down_time_counter', timeskip)
            elseif df.activity_event_socializest:is_instance(ev) then
                increment_counter(ev, 'down_time_counter', timeskip)
            elseif df.activity_event_ponder_topicst:is_instance(ev) then
                decrement_counter(ev, 'timer', timeskip)
            elseif df.activity_event_discuss_topicst:is_instance(ev) then
                decrement_counter(ev, 'timer', timeskip)
            elseif df.activity_event_teach_topicst:is_instance(ev) then
                decrement_counter(ev, 'time_left', timeskip)
            elseif df.activity_event_readst:is_instance(ev) then
                decrement_counter(ev, 'timer', timeskip)
            elseif df.activity_event_writest:is_instance(ev) then
                decrement_counter(ev, 'timer', timeskip)
            elseif df.activity_event_copy_written_contentst:is_instance(ev) then
                decrement_counter(ev, 'time_left', timeskip)
            elseif df.activity_event_make_believest:is_instance(ev) then
                decrement_counter(ev, 'time_left', timeskip)
            elseif df.activity_event_play_with_toyst:is_instance(ev) then
                decrement_counter(ev, 'time_left', timeskip)
            elseif df.activity_event_performancest:is_instance(ev) then
                increment_counter(ev, 'current_position', timeskip)
            elseif df.activity_event_store_objectst:is_instance(ev) then
                -- TODO: counter behavior not yet analyzed
                -- print(i)
            end
        end
    end
end

local function on_tick()
    local real_fps = math.max(1, dfhack.internal.getUnpausedFps())
    if real_fps >= state.settings.fps then
        timeskip_deficit, calendar_timeskip_deficit = 0.0, 0.0
        return
    end

    local desired_timeskip = get_desired_timeskip(real_fps, state.settings.fps) + timeskip_deficit
    local timeskip = math.floor(clamp_timeskip(desired_timeskip))

    -- add some jitter so we don't fall into a constant pattern
    -- this reduces the risk of repeatedly missing an unknown threshold
    -- also keeps the game from looking robotic at lower frame rates
    local jitter_strategy = math.random(1, 10)
    if jitter_strategy <= 1 then
        timeskip = math.random(0, timeskip)
    elseif jitter_strategy <= 3 then
        timeskip = math.random(math.max(0, timeskip-2), timeskip)
    elseif jitter_strategy <= 5 then
        timeskip = math.random(math.max(0, timeskip-4), timeskip)
    end

    -- don't let our deficit grow unbounded if we can never catch up
    timeskip_deficit = math.min(desired_timeskip - timeskip, 100.0)

    if DEBUG then print(('timeskip (%d, +%.2f)'):format(timeskip, timeskip_deficit)) end
    if timeskip <= 0 then return end

    local desired_calendar_timeskip = (timeskip * state.settings.calendar_rate) + calendar_timeskip_deficit
    local calendar_timeskip = math.max(1, math.floor(desired_calendar_timeskip))
    calendar_timeskip_deficit = math.max(0, desired_calendar_timeskip - calendar_timeskip)

    df.global.cur_year_tick = df.global.cur_year_tick + calendar_timeskip

    adjust_units(timeskip)
    adjust_activities(timeskip)
end

------------------------------------
-- hook management

local function do_enable()
    timeskip_deficit, calendar_timeskip_deficit = 0.0, 0.0
    state.enabled = true
    repeatutil.scheduleEvery(GLOBAL_KEY, 1, 'ticks', on_tick)
end

local function do_disable()
    state.enabled = false
    repeatutil.cancel(GLOBAL_KEY)
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
    if state.enabled then
        do_enable()
    end
end

------------------------------------
-- interface

if dfhack_flags.module then
    return
end

if not dfhack.world.isFortressMode() or not dfhack.isMapLoaded() then
    qerror('needs a loaded fortress map to work')
end

local function print_status()
    print(GLOBAL_KEY .. ' is ' .. (state.enabled and 'enabled' or 'not enabled'))
    print()
    print('settings:')
    for _,v in ipairs(SETTINGS) do
        print(('  %15s: %s'):format(v.name, state.settings[v.internal_name or v.name]))
    end
end

local function do_set(setting_name, arg)
    if not setting_name or not arg then
        qerror('must specify setting and value')
    end
    local _, setting = utils.linear_index(SETTINGS, setting_name, 'name')
    if not setting then
        qerror('setting not found: ' .. setting_name)
    end
    state.settings[setting.internal_name or setting.name] = setting.validate(arg)
    print(('set %s to %s'):format(setting_name, state.settings[setting.internal_name or setting.name]))
end

local function do_reset()
    state = get_default_state()
end

local args = {...}
local command = table.remove(args, 1)

if dfhack_flags and dfhack_flags.enable then
    if dfhack_flags.enable_state then do_enable()
    else do_disable()
    end
elseif command == 'set' then
    do_set(args[1], args[2])
elseif command == 'reset' then
    do_reset()
elseif not command or command == 'status' then
    print_status()
    return
else
    print(dfhack.script_help())
    return
end

persist_state()
