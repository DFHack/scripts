--@module = true
--@enable = true

local eventful = require('plugins.eventful')
local exterminate = reqscript('exterminate')
local gui = require('gui')
local overlay = require('plugins.overlay')
local utils = require('utils')
local widgets = require('gui.widgets')

local GLOBAL_KEY = 'agitation-rebalance'
local UNIT_EVENT_FREQ = 5

local presets = {
    casual={
        wild_irritate_min=100000,
        wild_sens=100000,
        wild_irritate_decay=100000,
        cavern_dweller_max_attackers=0,
    },
    lenient={
        wild_irritate_min=10000,
        wild_sens=10000,
        wild_irritate_decay=5000,
        cavern_dweller_max_attackers=20,
    },
    strict={
        wild_irritate_min=2500,
        wild_sens=500,
        wild_irritate_decay=1000,
        cavern_dweller_max_attackers=50,
    },
    insane={
        wild_irritate_min=600,
        wild_sens=200,
        wild_irritate_decay=200,
        cavern_dweller_max_attackers=100,
    },
}

local vanilla_presets = {
    casual={
        wild_irritate_min=2000,
        wild_sens=10000,
        wild_irritate_decay=500,
        cavern_dweller_max_attackers=0,
    },
    lenient={
        wild_irritate_min=2000,
        wild_sens=10000,
        wild_irritate_decay=500,
        cavern_dweller_max_attackers=50,
    },
    strict={
        wild_irritate_min=0,
        wild_sens=10000,
        wild_irritate_decay=100,
        cavern_dweller_max_attackers=75,
    },
}

local function get_default_state()
    return {
        enabled=false,
        features={
            auto_preset=true,
            surface=true,
            cavern=true,
            cap_invaders=true,
        },
        caverns={
            last_invasion_id=-1,
            last_year_roll=-1,
            last_season_roll=-1,
            baseline=0,
            player_visible_baseline=0,
        },
        stats={
            surface_attacks=0,
            cavern_attacks=0,
            invasions_diverted=0,
            invaders_vaporized=0,
        },
    }
end

state = state or get_default_state()
new_unit_min_frame_counter = new_unit_min_frame_counter or -1
num_cavern_invaders = num_cavern_invaders or 0
num_cavern_invaders_frame_counter = num_cavern_invaders_frame_counter or -1

function isEnabled()
    return state.enabled
end

local function get_stat(stat)
    return ensure_key(state, 'stats')[stat] or 0
end

local function inc_stat(stat)
    local cur_val = get_stat(stat)
    state.stats[stat] = cur_val + 1
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, state)
end

local world = df.global.world
local map_features = world.features.map_features
local plotinfo = df.global.plotinfo
local custom_difficulty = plotinfo.main.custom_difficulty

local function on_surface_attack()
    if plotinfo.outdoor_irritation > custom_difficulty.wild_irritate_min then
        plotinfo.outdoor_irritation = custom_difficulty.wild_irritate_min
        inc_stat('surface_attacks')
        persist_state()
    end
end

local function get_cumulative_irritation()
    local irritation = 0
    for _, map_feature in ipairs(map_features) do
        if df.feature_init_subterranean_from_layerst:is_instance(map_feature) then
            irritation = irritation + map_feature.feature.irritation_level
        end
    end
    return irritation
end

local function get_cavern_irritation(which)
    for _,map_feature in ipairs(map_features) do
        if not df.feature_init_subterranean_from_layerst:is_instance(map_feature) then
            goto continue
        end
        if map_feature.start_depth == which then
            return map_feature.feature.irritation_level
        end
        ::continue::
    end
end

-- returns the minimum irritation level that will max out chances of
-- both cavern invasions and forgotten beasts
local function get_normalized_irritation(which)
    local irritation = get_cavern_irritation(which)
    if not irritation then return 0 end
    local wealth_rating = plotinfo.tasks.wealth.total // custom_difficulty.forgotten_wealth_div
    local irritation_min = custom_difficulty.forgotten_irritate_min
    return math.max(10000, irritation_min - wealth_rating + custom_difficulty.forgotten_sens)
end

local function get_cavern_sens()
    return (custom_difficulty.wild_irritate_min + custom_difficulty.wild_sens)//2
end

local function on_cavern_attack(invasion_id)
    state.caverns.last_invasion_id = invasion_id
    for _,map_feature in ipairs(map_features) do
        if not df.feature_init_subterranean_from_layerst:is_instance(map_feature) then
            goto continue
        end
        local normalized_irritation = get_normalized_irritation(map_feature.start_depth)
        map_feature.feature.irritation_level = math.min(
            map_feature.feature.irritation_level,
            100000-get_cavern_sens(),  -- values above this are too close to max limit
            normalized_irritation)     -- values above this are effectively the same
        ::continue::
    end
    state.caverns.baseline = get_cumulative_irritation()
    inc_stat('cavern_attacks')
    persist_state()
end

local function is_unkilled(unit)
    return not dfhack.units.isKilled(unit) and
        unit.animal.vanish_countdown <= 0  -- not yet exterminated
end

local function is_cavern_invader(unit)
    local invasion = df.invasion_info.find(unit.invasion_id)
    return invasion and
        invasion.origin_master_army_controller_id == -1 and
        not unit.flags1.caged and
        not dfhack.units.isTame(unit)
end

local function on_cavern_invader_over_max()
    -- process units from the end of the active units first so we tend to
    -- preserve animal person invaders over the war animals they bring
    for i=#world.units.active-1,0,-1 do
        local unit = world.units.active[i]
        if not is_cavern_invader(unit) or not is_unkilled(unit) then
            goto continue
        end
        exterminate.killUnit(unit, exterminate.killMethod.DISINTEGRATE)
        num_cavern_invaders = num_cavern_invaders - 1
        inc_stat('invaders_vaporized')
        if num_cavern_invaders <= custom_difficulty.cavern_dweller_max_attackers then
            break
        end
        ::continue::
    end
    persist_state()
end

local function get_cavern_invaders()
    local invaders = {}
    for _, unit in ipairs(world.units.active) do
        if is_unkilled(unit) and is_cavern_invader(unit) then
            table.insert(invaders, unit)
        end
    end
    return invaders
end

local function get_num_cavern_invaders(slack)
    slack = slack or 0
    if num_cavern_invaders_frame_counter + slack < world.frame_counter then
        num_cavern_invaders = #get_cavern_invaders()
        num_cavern_invaders_frame_counter = world.frame_counter
        if num_cavern_invaders == 0 and
            state.caverns.baseline ~= state.caverns.player_visible_baseline
        then
            state.caverns.player_visible_baseline = state.caverns.baseline
            persist_state()
        end
    end
    return num_cavern_invaders
end

local function get_agitated_units()
    local agitators = {}
    for _, unit in ipairs(world.units.active) do
        if is_unkilled(unit) and dfhack.units.isAgitated(unit) then
            table.insert(agitators, unit)
        end
    end
    return agitators
end

local function check_new_unit(unit_id)
    -- when just enabling, ignore the first batch of "new" units so we
    -- don't react to existing agitated units or cavern invaders
    if new_unit_min_frame_counter >= world.frame_counter then return end
    local unit = df.unit.find(unit_id)
    if not unit or not is_unkilled(unit) then return end
    if state.features.surface and dfhack.units.isAgitated(unit) then
        on_surface_attack()
        return
    end
    if not state.features.cap_invaders or not is_cavern_invader(unit) then
        return
    end
    if state.caverns.last_invasion_id ~= unit.invasion_id then
        on_cavern_attack(unit.invasion_id)
    end
    if state.features.cap_invaders and
        get_num_cavern_invaders() > custom_difficulty.cavern_dweller_max_attackers
    then
        on_cavern_invader_over_max()
    end
end

local function cull_invaders()
    if not state.features.cap_invaders then return end
    if get_num_cavern_invaders() > custom_difficulty.cavern_dweller_max_attackers then
        on_cavern_invader_over_max()
    end
end

local function get_cavern_attack_independent_natural_chance(which)
    return math.min(1, (get_cavern_irritation(which) or 0) / 10000)
end

local function get_cavern_attack_natural_chances()
    local cavern_1_chance = get_cavern_attack_independent_natural_chance(df.layer_type.Cavern1)
    local cavern_2_chance = get_cavern_attack_independent_natural_chance(df.layer_type.Cavern2)
    local cavern_3_chance = get_cavern_attack_independent_natural_chance(df.layer_type.Cavern3)
    return cavern_1_chance,
        (1-cavern_1_chance) * cavern_2_chance,
        (1-cavern_1_chance) * (1-cavern_2_chance) * cavern_3_chance
end

local function cavern_attack_passes_roll()
    local irritation = get_cumulative_irritation() - state.caverns.baseline
    local irr_max = get_cavern_sens()
    if state.caverns.baseline == 0 then
        -- normalize chances if irritation < 10000
        local c1, c2, c3 = get_cavern_attack_natural_chances()
        irr_max = math.floor(irr_max * (c1 + c2 + c3))
    end
    if irritation >= irr_max then return true end
    return math.random(1, irr_max) <= irritation
end

local function throttle_invasions()
    if not state.features.cavern then return end
    if state.caverns.last_year_roll == df.global.cur_year and
        state.caverns.last_season_roll >= df.global.cur_season or
        state.caverns.last_year_roll >= df.global.cur_year
    then
        -- only roll once per season
        return
    end
    local over_cap = state.features.cap_invaders and
        get_num_cavern_invaders() >= custom_difficulty.cavern_dweller_max_attackers
    for idx=#df.global.timed_events-1,0,-1 do
        local ev = df.global.timed_events[idx]
        if ev.type ~= df.timed_event_type.FeatureAttack then goto continue end
        local civ = ev.entity
        if not civ then goto continue end
        if over_cap or not cavern_attack_passes_roll() then
            inc_stat('invasions_diverted')
            df.global.timed_events:erase(idx)
            ev:delete()
        end
        ::continue::
    end
    state.caverns.last_year_roll = df.global.cur_year
    state.caverns.last_season_roll = df.global.cur_season
    persist_state()
end

local function do_preset(preset_name)
    local preset = presets[preset_name]
    if not preset then
        qerror(('preset not found: "%s"'):format(preset_name))
    end
    utils.assign(custom_difficulty, preset)
    print('agitation-rebalance: preset applied: ' .. preset_name)
end

local TICKS_PER_DAY = 1200
local TICKS_PER_MONTH = 28 * TICKS_PER_DAY
local TICKS_PER_SEASON = 3 * TICKS_PER_MONTH

local function seasons_cleaning()
    if not state.enabled then return end
    cull_invaders()
    throttle_invasions()
    local ticks_until_next_season = TICKS_PER_SEASON - df.global.cur_season_tick + 1
    dfhack.timeout(ticks_until_next_season, 'ticks', seasons_cleaning)
end

local function check_preset()
    for preset_name,vanilla_settings in pairs(vanilla_presets) do
        local matched = true
        for k,v in pairs(vanilla_settings) do
            if custom_difficulty[k] ~= v then
                matched = false
                break
            end
        end
        if matched then
            do_preset(preset_name)
            break
        end
    end
end

local function do_enable()
    state.enabled = true
    new_unit_min_frame_counter = world.frame_counter + UNIT_EVENT_FREQ + 1
    num_cavern_invaders_frame_counter = -(UNIT_EVENT_FREQ+1)
    eventful.enableEvent(eventful.eventType.UNIT_NEW_ACTIVE, UNIT_EVENT_FREQ)
    eventful.onUnitNewActive[GLOBAL_KEY] = check_new_unit
    if state.features.auto_preset then check_preset() end
    seasons_cleaning()
end

local function do_disable()
    state.enabled = false
    eventful.onUnitNewActive[GLOBAL_KEY] = nil
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
    num_cavern_invaders = num_cavern_invaders or 0
    num_cavern_invaders_frame_counter = -(UNIT_EVENT_FREQ+1)
    if state.enabled then
        do_enable()
    end
end

-----------------------------------
-- IrritationOverlay
--

IrritationOverlay = defclass(IrritationOverlay, overlay.OverlayWidget)
IrritationOverlay.ATTRS{
    desc='Monitors irritation and shows chances of invasion.',
    default_pos={x=-32,y=5},
    viewscreens='dwarfmode/Default',
    overlay_onupdate_max_freq_seconds=5,
    frame={w=24, h=13},
}

local function get_savagery()
    -- need to check at (or about) ground level since biome data may be missing or incorrect
    -- in the extreme top or bottom levels of the map
    local ground_level = (world.map.z_count-2) - world.worldgen.worldgen_parms.levels_above_ground
    local rgnX, rgnY
    for z=ground_level,0,-1 do
        rgnX, rgnY = dfhack.maps.getTileBiomeRgn(0, 0, z)
        if rgnX then break end
    end
    local biome = dfhack.maps.getRegionBiome(rgnX, rgnY)
    return biome and biome.savagery or 0
end

-- returns chance for next wildlife group
local function get_surface_attack_chance()
    local adjusted_irritation = plotinfo.outdoor_irritation - custom_difficulty.wild_irritate_min
    if adjusted_irritation <= 0 or get_savagery() <= 65 then return 0 end
    return custom_difficulty.wild_sens <= 0 and 100 or
        math.min(100, (adjusted_irritation*100)//custom_difficulty.wild_sens)
end

-- returns chance for next season
local function get_fb_attack_chance(which)
    local irritation = get_cavern_irritation(which)
    if not irritation then return 0 end
    local wealth_rating = plotinfo.tasks.wealth.total // custom_difficulty.forgotten_wealth_div
    local irritation_min = custom_difficulty.forgotten_irritate_min
    local adjusted_irritation = wealth_rating + irritation - irritation_min
    if adjusted_irritation < 0 then return 0 end
    return custom_difficulty.forgotten_sens <= 0 and 33 or
        math.min(33, (adjusted_irritation*33)//custom_difficulty.forgotten_sens)
end

local function get_cavern_attack_natural_chance(which)
    local c1, c2, c3 = get_cavern_attack_natural_chances()
    if which == df.layer_type.Cavern1 then
        return math.floor(c1 * 100)
    elseif which == df.layer_type.Cavern2 then
        return math.floor(c2 * 100)
    elseif which == df.layer_type.Cavern3 then
        return math.floor(c3 * 100)
    else
        return math.floor((c1+c2+c3) * 100)
    end
end

local function get_cavern_invasion_chance(which)
    if not state.enabled then
        return get_cavern_attack_natural_chance(which)
    end

    -- don't divilge new lowered chances until the current crop of invaders is gone
    local baseline = num_cavern_invaders == 0 and
        state.caverns.baseline or state.caverns.player_visible_baseline
    local irritation = get_cumulative_irritation() - baseline
    local irr_max = get_cavern_sens()
    local c1, c2, c3 = get_cavern_attack_natural_chances()
    local natural_chance = c1 + c2 + c3
    if state.caverns.baseline == 0 then
        -- normalize chances if we've never had an attack
        irr_max = math.floor(irr_max * natural_chance)
    end
    local overall_chance = math.min(1, irritation * natural_chance / irr_max)

    if which == df.layer_type.Cavern1 then
        return math.floor(c1 * 100 * overall_chance)
    elseif which == df.layer_type.Cavern2 then
        return math.floor(c2 * 100 * overall_chance)
    elseif which == df.layer_type.Cavern3 then
        return math.floor(c3 * 100 * overall_chance)
    else
        return math.floor(natural_chance * 100 * overall_chance)
    end
end

local function get_chance_color(chance_fn, chance_arg)
    local chance = chance_fn(chance_arg)
    if chance < 1 then
        return COLOR_GREEN
    elseif chance < 33 then
        return COLOR_YELLOW
    elseif chance < 51 then
        return COLOR_LIGHTRED
    end
    return COLOR_RED
end

local function obfuscate_chance(chance_fn, chance_arg)
    local chance = chance_fn(chance_arg)
    if chance < 1 then
        return 'None'
    elseif chance < 33 then
        return 'Low'
    elseif chance < 51 then
        return 'Med'
    end
    return 'High'
end

local function get_invader_color()
    if num_cavern_invaders <= 0 then
        return COLOR_GREEN
    elseif num_cavern_invaders < custom_difficulty.cavern_dweller_max_attackers then
        return COLOR_YELLOW
    else
        return COLOR_RED
    end
end

-- set to true with :lua reqscript('agitation-rebalance').monitor_debug=true
-- to see more information on the monitor panel
monitor_debug = monitor_debug or false

function IrritationOverlay:init()
    local panel = widgets.Panel{
        frame_style=gui.FRAME_MEDIUM,
        frame_background=gui.CLEAR_PEN,
        frame={t=0, r=0, w=15, h=5},
        visible=function() return not monitor_debug end,
    }
    panel:addviews{
        widgets.Label{
            frame={t=0},
            text='Irrit. Threat',
            auto_width=true,
        },
        widgets.Label{
            frame={t=1, l=0},
            text={
                'Surface:',
                {gap=1, text=curry(obfuscate_chance, get_surface_attack_chance)},
            },
            text_pen=curry(get_chance_color, get_surface_attack_chance),
        },
        widgets.Label{
            frame={t=2, l=0},
            text={
                'Caverns:',
                {gap=1, text=curry(obfuscate_chance, get_cavern_invasion_chance)},
            },
            text_pen=curry(get_chance_color, get_cavern_invasion_chance),
        },
    }

    local debug_panel = widgets.Panel{
        frame_style=gui.FRAME_MEDIUM,
        frame_background=gui.CLEAR_PEN,
        visible=function() return monitor_debug end,
    }
    debug_panel:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text='Attack chance',
        },
        widgets.Label{
            frame={t=1, l=0},
            text={
                ' Surface:',
                {gap=1, text=get_surface_attack_chance, width=3, rjustify=true},
                '%',
            },
            text_pen=curry(get_chance_color, get_surface_attack_chance),
        },
        widgets.Label{
            frame={t=2, l=0},
            text={
                'Caverns:',
                {gap=2, text='FBs:'},
            },
        },
        widgets.Label{
            frame={t=3, l=0},
            text={
                '1:',
                {gap=2, text=curry(get_cavern_invasion_chance, df.layer_type.Cavern1), width=3, rjustify=true},
                '%',
            },
            text_pen=curry(get_chance_color, get_cavern_invasion_chance, df.layer_type.Cavern1),
        },
        widgets.Label{
            frame={t=3, l=10},
            text={
                {text=curry(get_fb_attack_chance, df.layer_type.Cavern1), width=3, rjustify=true},
                '%',
            },
            text_pen=curry(get_chance_color, get_fb_attack_chance, df.layer_type.Cavern1),
        },
        widgets.Label{
            frame={t=4, l=0},
            text={
                '2:',
                {gap=2, text=curry(get_cavern_invasion_chance, df.layer_type.Cavern2), width=3, rjustify=true},
                '%',
            },
            text_pen=curry(get_chance_color, get_cavern_invasion_chance, df.layer_type.Cavern2),
        },
        widgets.Label{
            frame={t=4, l=10},
            text={
                {text=curry(get_fb_attack_chance, df.layer_type.Cavern2), width=3, rjustify=true},
                '%',
            },
            text_pen=curry(get_chance_color, get_fb_attack_chance, df.layer_type.Cavern2),
        },
        widgets.Label{
            frame={t=5, l=0},
            text={
                '3:',
                {gap=2, text=curry(get_cavern_invasion_chance, df.layer_type.Cavern3), width=3, rjustify=true},
                '%',
            },
            text_pen=curry(get_chance_color, get_cavern_invasion_chance, df.layer_type.Cavern3),
        },
        widgets.Label{
            frame={t=5, l=10},
            text={
                {text=curry(get_fb_attack_chance, df.layer_type.Cavern3), width=3, rjustify=true},
                '%',
            },
            text_pen=curry(get_chance_color, get_fb_attack_chance, df.layer_type.Cavern3),
        },
        widgets.Label{
            frame={t=0, r=0},
            text='Irrit',
            auto_width=true,
        },
        widgets.Label{
            frame={t=1, r=0},
            text={{text=function() return plotinfo.outdoor_irritation end, width=6, rjustify=true}},
            text_pen=curry(get_chance_color, get_surface_attack_chance),
            auto_width=true,
        },
        widgets.Label{
            frame={t=3, r=0},
            text={{text=function() return get_cavern_irritation(df.layer_type.Cavern1) end, width=6, rjustify=true}},
            text_pen=curry(get_chance_color, get_cavern_invasion_chance, df.layer_type.Cavern1),
            auto_width=true,
        },
        widgets.Label{
            frame={t=4, r=0},
            text={{text=function() return get_cavern_irritation(df.layer_type.Cavern2) end, width=6, rjustify=true}},
            text_pen=curry(get_chance_color, get_cavern_invasion_chance, df.layer_type.Cavern2),
            auto_width=true,
        },
        widgets.Label{
            frame={t=5, r=0},
            text={{text=function() return get_cavern_irritation(df.layer_type.Cavern3) end, width=6, rjustify=true}},
            text_pen=curry(get_chance_color, get_cavern_invasion_chance, df.layer_type.Cavern3),
            auto_width=true,
        },
        widgets.Label{
            frame={t=6, l=0},
            text={
                'Invaders:',
                {gap=1, text=function() return num_cavern_invaders end, width=4, rjustify=true},
                '/',
                {text=function() return custom_difficulty.cavern_dweller_max_attackers end},
            },
            text_pen=function() return get_invader_color() end,
        },
        widgets.Label{
            frame={t=7, l=0},
            text={
                'Surface attacks:',
                {gap=1, text=function() return get_stat('surface_attacks') end, width=5, rjustify=true},
            },
        },
        widgets.Label{
            frame={t=8, l=0},
            text={
                ' Cavern attacks:',
                {gap=1, text=function() return get_stat('cavern_attacks') end, width=5, rjustify=true},
            },
        },
        widgets.Label{
            frame={t=9, l=0},
            text={
                'Invasions erased:',
                {gap=1, text=function() return get_stat('invasions_diverted') end, width=4, rjustify=true},
            },
        },
        widgets.Label{
            frame={t=10, l=0},
            text={
                'Invaders culled:',
                {gap=1, text=function() return get_stat('invaders_vaporized') end, width=5, rjustify=true},
            },
        },
    }

    self:addviews{
        panel,
        debug_panel,
        widgets.HelpButton{command='agitation-rebalance'}
    }
end

function IrritationOverlay:overlay_onupdate()
    get_num_cavern_invaders(UNIT_EVENT_FREQ)
end

OVERLAY_WIDGETS = {monitor=IrritationOverlay}

-----------------------------------
-- CLI
--

if dfhack_flags.module then
    return
end

if not dfhack.world.isFortressMode() or not dfhack.isMapLoaded() then
    qerror('needs a loaded fortress map to work')
end

local WIDGET_NAME = dfhack.current_script_name() .. '.monitor'

local function print_status()
    print(GLOBAL_KEY .. ' is ' .. (state.enabled and 'enabled' or 'not enabled'))
    print()
    print('features:')
    for k,v in pairs(state.features) do
        print(('  %15s: %s'):format(k, v))
    end
    print(('  %15s: %s'):format('monitor',
        overlay.get_state().config[WIDGET_NAME].enabled or 'false'))
    print()
    print('difficulty settings:')
    print(('     Wilderness irritation minimum: %d (about %d tree(s) until initial attacks are possible)'):format(
        custom_difficulty.wild_irritate_min, custom_difficulty.wild_irritate_min // 100))
    print(('            Wilderness sensitivity: %d (each tree past the miniumum makes an attack %.2f%% more likely)'):format(
        custom_difficulty.wild_sens, 10000 / custom_difficulty.wild_sens))
    print(('       Wilderness irritation decay: %d (about %d additional tree(s) allowed per year)'):format(
        custom_difficulty.wild_irritate_decay, custom_difficulty.wild_irritate_decay // 100))
    print(('  Cavern dweller maximum attackers: %d (maximum allowed across all caverns)'):format(
        custom_difficulty.cavern_dweller_max_attackers))
    print()
    local unhidden_invaders = {}
    for _, unit in ipairs(get_cavern_invaders()) do
        if not dfhack.units.isHidden(unit) then
            table.insert(unhidden_invaders, unit)
        end
    end
    print(('current agitated wildlife:     %5d'):format(#get_agitated_units()))
    print(('current known cavern invaders: %5d'):format(#unhidden_invaders))
    print()
    print('current chances for an upcoming attack:')
    print(('  Surface: %s'):format(obfuscate_chance(get_surface_attack_chance)))
    print(('  Caverns: %s'):format(obfuscate_chance(get_cavern_invasion_chance)))
end

local function enable_feature(which, enabled)
    if which == 'monitor' then
        dfhack.run_command('overlay', enabled and 'enable' or 'disable', WIDGET_NAME)
        return
    end
    local feature = state.features[which]
    if feature == nil then
        qerror(('feature not found: "%s"'):format(which))
    end
    state.features[which] = enabled
    print(('feature %sabled: %s'):format(enabled and 'en' or 'dis', which))
end

local args = {...}
local command = table.remove(args, 1)

if dfhack_flags and dfhack_flags.enable then
    if dfhack_flags.enable_state then do_enable()
    else do_disable()
    end
elseif command == 'preset' then
    do_preset(args[1] or '')
elseif command == 'enable' or command == 'disable' then
    enable_feature(args[1] or '', command == 'enable')
elseif not command or command == 'status' then
    print_status()
    return
else
    print(dfhack.script_help())
    return
end

persist_state()
