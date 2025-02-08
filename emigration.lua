--@module = true
--@enable = true

local utils = require('utils')

local nobles = reqscript('internal/emigration/emigrate-nobles')
local unit_link_utils = reqscript('internal/emigration/unit-link-utils')

local GLOBAL_KEY = 'emigration' -- used for state change hooks and persistence

local function get_default_state()
    return {enabled=false, last_cycle_tick=0}
end

state = state or get_default_state()

function isEnabled()
    return state.enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, state)
end

local TICKS_PER_MONTH = 33600
local TICKS_PER_YEAR = 12 * TICKS_PER_MONTH

function desireToStay(unit,method,civ_id)
    -- on a percentage scale
    local value = 100 - unit.status.current_soul.personality.stress / 5000
    if method == 'merchant' then
        if civ_id ~= unit.civ_id then value = value*2 end end
    if method == 'wild' then
        value = value*5 end
    return value
end

function desert(u,method,civ)
    u.following = nil
    local line = dfhack.units.getReadableName(u) .. " has "
    if method == 'merchant' then
        line = line.."joined the merchants"
        unit_link_utils.markUnitForEmigration(u, civ, false)
    else
        line = line.."abandoned the settlement in search of a better life."
        unit_link_utils.markUnitForEmigration(u, civ, true)
    end

    local hf_id = u.hist_figure_id
    local hf = df.historical_figure.find(u.hist_figure_id)
    local fort_ent = df.global.plotinfo.main.fortress_entity
    local civ_ent = df.historical_entity.find(hf.civ_id)
    local newent_id = -1
    local newsite_id = -1

    unit_link_utils.removeUnitAssociations(u)
    unit_link_utils.removeHistFigFromEntity(hf, fort_ent)

    -- try to find a new entity for the unit to join
    for k,v in ipairs(civ_ent.entity_links) do
        if v.type == df.entity_entity_link_type.CHILD and v.target ~= fort_ent.id then
            newent_id = v.target
            break
        end
    end

    if newent_id > -1 then
        hf.entity_links:insert("#", {new = df.histfig_entity_link_memberst, entity_id = newent_id, link_strength = 100})

        -- try to find a new site for the unit to join
        for k,v in ipairs(df.global.world.entities.all[hf.civ_id].site_links) do
            local site_id = df.global.plotinfo.site_id
            if v.type == df.entity_site_link_type.Claim and v.target ~= site_id then
                newsite_id = v.target
                break
            end
        end
        local newent = df.historical_entity.find(newent_id)
        newent.histfig_ids:insert('#', hf_id)
        newent.hist_figures:insert('#', hf)
        local hf_event_id = df.global.hist_event_next_id
        df.global.hist_event_next_id = df.global.hist_event_next_id+1
        df.global.world.history.events:insert("#", {new = df.history_event_add_hf_entity_linkst, year = df.global.cur_year, seconds = df.global.cur_year_tick, id = hf_event_id, civ = newent_id, histfig = hf_id, link_type = 0})
        if newsite_id > -1 then
            local hf_event_id = df.global.hist_event_next_id
            df.global.hist_event_next_id = df.global.hist_event_next_id+1
            df.global.world.history.events:insert("#", {new = df.history_event_change_hf_statest, year = df.global.cur_year, seconds = df.global.cur_year_tick, id = hf_event_id, hfid = hf_id, state = 1, reason = -1, site = newsite_id})
        end
    end
    print(dfhack.df2console(line))
    dfhack.gui.showAnnouncement(line, COLOR_WHITE)
end

function canLeave(unit)
    if not unit.status.current_soul then
        return false
    end

    return dfhack.units.isActive(unit) and
        dfhack.units.isCitizen(unit) and
        not dfhack.units.getNoblePositions(unit) and
        not unit.flags1.chained and
        unit.military.squad_id == -1 and
        not dfhack.units.isBaby(unit) and
        not dfhack.units.isChild(unit)
end

function checkForDeserters(method,civ_id)
    local allUnits = df.global.world.units.active
    for i=#allUnits-1,0,-1 do   -- search list in reverse
        local u = allUnits[i]
        if canLeave(u) and math.random(100) > desireToStay(u,method,civ_id) then
            desert(u,method,civ_id)
        end
    end
end

function checkmigrationnow()
    local merchant_civ_ids = {} --as:number[]
    local allUnits = df.global.world.units.active
    for i=0, #allUnits-1 do
        local unit = allUnits[i]
        if dfhack.units.isSane(unit)
        and dfhack.units.isActive(unit)
        and not dfhack.units.isOpposedToLife(unit)
        and not unit.flags1.tame
        then
            if unit.flags1.merchant then table.insert(merchant_civ_ids, unit.civ_id) end
        end
    end

    if #merchant_civ_ids == 0 then
        checkForDeserters('wild', df.global.plotinfo.main.fortress_entity.entity_links[0].target)
    else
        for _, civ_id in pairs(merchant_civ_ids) do checkForDeserters('merchant', civ_id) end
    end

    state.last_cycle_tick = dfhack.world.ReadCurrentTick() + TICKS_PER_YEAR * dfhack.world.ReadCurrentYear()
end

local function event_loop()
    if state.enabled then
        local current_tick = dfhack.world.ReadCurrentTick() + TICKS_PER_YEAR * dfhack.world.ReadCurrentYear()
        if current_tick - state.last_cycle_tick < TICKS_PER_MONTH then
            local timeout_ticks = state.last_cycle_tick - current_tick + TICKS_PER_MONTH
            dfhack.timeout(timeout_ticks, 'ticks', event_loop)
        else
            checkmigrationnow()
            dfhack.timeout(1, 'months', event_loop)
        end
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        state.enabled = false
        return
    end

    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end

    state = get_default_state()
    utils.assign(state, dfhack.persistent.getSiteData(GLOBAL_KEY, state))

    event_loop()
end

if dfhack_flags.module then
    return
end

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    dfhack.printerr('emigration needs a loaded fortress map to work')
    return
end

local args = {...}
if dfhack_flags and dfhack_flags.enable then
    args = {dfhack_flags.enable_state and 'enable' or 'disable'}
end

if args[1] == "enable" then
    state.enabled = true
elseif args[1] == "disable" then
    state.enabled = false
elseif args[1] == "nobles" then
    table.remove(args, 1)
    nobles.run(args)
else
    print('emigration is ' .. (state.enabled and 'enabled' or 'not enabled'))
    return
end

event_loop()
persist_state()
