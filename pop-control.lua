--@module = true
--@enable = true

local argparse = require('argparse')
local repeatutil = require('repeat-util')
local utils = require('utils')

local GLOBAL_KEY = 'pop-control'

local function get_default_state()
    return {
        enabled=false,
        max_wave=10,
        max_pop=200,
    }
end

state = state or get_default_state()

function isEnabled()
    return state.enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, state)
end

local function adjust_caps()
    if not state.enabled then return end
    local new_cap = math.min(state.max_pop, #dfhack.units.getCitizens() + state.max_wave)
    if new_cap ~= df.global.d_init.dwarf.population_cap then
        df.global.d_init.dwarf.population_cap = new_cap
        print('pop-control: Population cap set to ' .. new_cap)
    end
end

local function do_enable()
    state.enabled = true
    repeatutil.scheduleEvery(GLOBAL_KEY, 1, "months", adjust_caps)
end

local function do_disable()
    state.enabled = false
    repeatutil.cancel(GLOBAL_KEY)
    df.global.d_init.dwarf.population_cap = state.max_pop
    print('pop-control: Population cap reset to ' .. state.max_pop)
end

local function do_set(which, val)
    local num = argparse.positiveInt(val, which)
    if which == 'wave-size' then
        state.max_wave = num
    elseif which == 'max-pop' then
        state.max_pop = num
    else
        qerror(('unknown setting: "%s"'):format(which))
    end
    adjust_caps()
end

local function do_reset()
    local enabled = state.enabled
    state = get_default_state()
    state.enabled = enabled
    adjust_caps()
end

local function print_status()
    print(('pop-control is %s.'):format(state.enabled and 'enabled' or 'disabled'))
    print()
    print('Settings:')
    print(('  wave-size: %3d'):format(state.max_wave))
    print(('  max-pop:   %3d'):format(state.max_pop))
    print()
    print('Current game caps:')
    print(('  population cap: %3d'):format(df.global.d_init.dwarf.population_cap))
    print(('  strict pop cap: %3d'):format(df.global.d_init.dwarf.strict_population_cap))
    print(('  visitor cap:    %3d'):format(df.global.d_init.dwarf.visitor_cap))
end

--- Handles automatic loading
dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc ~= SC_MAP_LOADED or not dfhack.world.isFortressMode() then
        return
    end

    state = get_default_state()
    utils.assign(state, dfhack.persistent.getSiteData(GLOBAL_KEY, state))
    if state.enabled then
        do_enable()
    end
end

if dfhack_flags.module then
    return
end

if not dfhack.world.isFortressMode() or not dfhack.isMapLoaded() then
    qerror('needs a loaded fortress map to work')
end

local args = {...}
local command = table.remove(args, 1)

if dfhack_flags and dfhack_flags.enable then
    if dfhack_flags.enable_state then
        do_enable()
    else
        do_disable()
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
