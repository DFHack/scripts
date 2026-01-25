-- Weaken and eventually destroy undead over time.
--@enable = true
--@module = true

local argparse = require('argparse')
local utils = require('utils')

local GLOBAL_KEY = 'starvingdead'

local function get_default_state()
  return {
      enabled=false,
      decay_rate=1,
      death_threshold=6,
      last_cycle_tick=0,
  }
end

state = state or get_default_state()

function isEnabled()
    return state.enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, state)
end

-- threshold each attribute should reach before death.
local ATTRIBUTE_THRESHOLD_PERCENT = 10

local TICKS_PER_DAY = 1200
local TICKS_PER_MONTH = 28 * TICKS_PER_DAY
local TICKS_PER_YEAR = 12 * TICKS_PER_MONTH

local function do_decay()
    local decay_exponent = state.decay_rate / (state.death_threshold * 28)
    local attribute_decay = (ATTRIBUTE_THRESHOLD_PERCENT ^ decay_exponent) / 100

    for _, unit in pairs(df.global.world.units.active) do
        if (unit.enemy.undead and not unit.flags1.inactive) then
            for _,attribute in pairs(unit.body.physical_attrs) do
                attribute.value = math.floor(attribute.value - (attribute.value * attribute_decay))
            end

            if unit.usable_interaction.time_on_site > (state.death_threshold * TICKS_PER_MONTH) then
                unit.animal.vanish_countdown = 1
            end
        end
    end
end

local function get_normalized_tick()
    return dfhack.world.ReadCurrentTick() + TICKS_PER_YEAR * dfhack.world.ReadCurrentYear()
end

timeout_id = timeout_id or nil

local function event_loop()
    if not state.enabled then return end

    local current_tick = get_normalized_tick()
    local ticks_per_cycle = TICKS_PER_DAY * state.decay_rate
    local timeout_ticks = ticks_per_cycle

    if current_tick - state.last_cycle_tick < ticks_per_cycle then
        timeout_ticks = state.last_cycle_tick - current_tick + ticks_per_cycle
    else
        do_decay()
        state.last_cycle_tick = current_tick
        persist_state()
    end
    timeout_id = dfhack.timeout(timeout_ticks, 'ticks', event_loop)
end

local function do_enable()
    if state.enabled then return end

    state.enabled = true
    state.last_cycle_tick = get_normalized_tick()
    event_loop()
end

local function do_disable()
    if not state.enabled then return end

    state.enabled = false
    if timeout_id then
        dfhack.timeout_active(timeout_id, nil)
        timeout_id = nil
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

    event_loop()
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then
    qerror('This script requires a fortress map to be loaded')
end

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        do_enable()
    else
        do_disable()
    end
end

local opts = {}
local positionals = argparse.processArgsGetopt({...}, {
    {'h', 'help', handler=function() opts.help = true end},
    {'r', 'decay-rate', hasArg=true,
        handler=function(arg) opts.decay_rate = argparse.positiveInt(arg, 'decay-rate') end },
    {'t', 'death-threshold', hasArg=true,
        handler=function(arg) opts.death_threshold = argparse.positiveInt(arg, 'death-threshold') end },
})


if positionals[1] == "help" or opts.help then
    print(dfhack.script_help())
    return
end

if opts.decay_rate then
    state.decay_rate = opts.decay_rate
end
if opts.death_threshold then
    state.death_threshold = opts.death_threshold
end
persist_state()

if state.enabled then
    print(([[StarvingDead is running, decaying undead every %s day%s and killing off at %s month%s]]):format(
        state.decay_rate, state.decay_rate == 1 and '' or 's', state.death_threshold, state.death_threshold == 1 and '' or 's'))
else
    print(([[StarvingDead is not running, but would decay undead every %s day%s and kill off at %s month%s]]):format(
        state.decay_rate, state.decay_rate == 1 and '' or 's', state.death_threshold, state.death_threshold == 1 and '' or 's'))
end
