--@module = true

local gui = require('gui')
local json = require('json')
local list_agreements = reqscript('list-agreements')
local warn_stranded = reqscript('warn-stranded')

local CONFIG_FILE = 'dfhack-config/notify.json'

local buildings = df.global.world.buildings
local caravans = df.global.plotinfo.caravans
local units = df.global.world.units

function for_iter(vec, match_fn, action_fn, reverse)
    local offset = type(vec) == 'table' and 1 or 0
    local idx1 = reverse and #vec-1+offset or offset
    local idx2 = reverse and offset or #vec-1+offset
    local step = reverse and -1 or 1
    for idx=idx1,idx2,step do
        local elem = vec[idx]
        if match_fn(elem) then
            if action_fn(elem) then return end
        end
    end
end

local function get_active_depot()
    for _, bld in ipairs(buildings.other.TRADE_DEPOT) do
        if bld:getBuildStage() == bld:getMaxBuildStage() and
            (#bld.jobs == 0 or bld.jobs[0].job_type ~= df.job_type.DestroyBuilding) and
            #bld.contained_items > 0 and not bld.contained_items[0].item.flags.forbid
        then
            return bld
        end
    end
end

local function is_adv_unhidden(unit)
    local flags = dfhack.maps.getTileFlags(dfhack.units.getPosition(unit))
    return flags and not flags.hidden and flags.pile
end

local function for_agitated_creature(fn, reverse)
    for_iter(units.active, function(unit)
        return not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            not unit.flags1.caged and
            not unit.flags1.chained and
            unit.flags4.agitated_wilderness_creature
    end, fn, reverse)
end

local function for_invader(fn, reverse)
    for_iter(units.active, function(unit)
        return not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            not unit.flags1.caged and
            not unit.flags1.chained and
            dfhack.units.isInvader(unit) and
            not dfhack.units.isHidden(unit)
    end, fn, reverse)
end

local function is_likely_hostile(unit)
    return dfhack.units.isCrazed(unit) or
        dfhack.units.isOpposedToLife(unit) or
        dfhack.units.isSemiMegabeast(unit) or
        dfhack.units.isGreatDanger(unit)
end

local function for_hostile(fn, reverse)
    for_iter(units.active, function(unit)
        return not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            not unit.flags1.caged and
            not unit.flags1.chained and
            not dfhack.units.isInvader(unit) and
            not dfhack.units.isFortControlled(unit) and
            not dfhack.units.isHidden(unit) and
            not unit.flags4.agitated_wilderness_creature and
            is_likely_hostile(unit)
    end, fn, reverse)
end

local function is_in_dire_need(unit)
    return unit.counters2.hunger_timer > 75000 or
        unit.counters2.thirst_timer > 50000 or
        unit.counters2.sleepiness_timer > 150000
end

local function for_starving(fn, reverse)
    for_iter(units.active, function(unit)
        return not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            dfhack.units.isSane(unit) and
            dfhack.units.isFortControlled(unit) and
            is_in_dire_need(unit)
    end, fn, reverse)
end

local function for_moody(fn, reverse)
    for_iter(dfhack.units.getCitizens(true), function(unit)
        local job = unit.job.current_job
        return job and df.job_type_class[df.job_type.attrs[job.job_type].type] == 'StrangeMood'
    end, fn, reverse)
end

local races = df.global.world.raws.creatures.all

local function is_stealer(unit)
    local casteFlags = races[unit.race].caste[unit.caste].flags
    if casteFlags.CURIOUS_BEAST_EATER or
        casteFlags.CURIOUS_BEAST_GUZZLER or
        casteFlags.CURIOUS_BEAST_ITEM
    then
        return true
    end
end

local function for_nuisance(fn, reverse)
    for_iter(units.active, function(unit)
        return not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            not unit.flags1.caged and
            not unit.flags1.chained and
            not dfhack.units.isHidden(unit) and
            not dfhack.units.isFortControlled(unit) and
            not dfhack.units.isInvader(unit) and
            not unit.flags4.agitated_wilderness_creature and
            not is_likely_hostile(unit) and
            (is_stealer(unit) or dfhack.units.isMischievous(unit))
    end, fn, reverse)
end

local function for_wildlife(fn, reverse)
    for_iter(units.active, function(unit)
        return not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            not unit.flags1.caged and
            not unit.flags1.chained and
            not dfhack.units.isHidden(unit) and
            not dfhack.units.isFortControlled(unit) and
            not dfhack.units.isInvader(unit) and
            not unit.flags4.agitated_wilderness_creature and
            not is_likely_hostile(unit) and
            not is_stealer(unit) and
            not dfhack.units.isMischievous(unit) and
            not dfhack.units.isMerchant(unit) and
            not dfhack.units.isForest(unit) and
            not dfhack.units.isVisitor(unit) and
            unit.animal.population.population_idx >= 0
    end, fn, reverse)
end

local function for_wildlife_adv(fn, reverse)
    for_iter(units.active, function(unit)
        return not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            not unit.flags1.caged and
            not unit.flags1.chained and
            not dfhack.units.isHidden(unit) and
            is_adv_unhidden(unit) and
            unit.animal.population.population_idx >= 0
    end, fn, reverse)
end

local function for_injured(fn, reverse)
    for_iter(dfhack.units.getCitizens(true), function(unit)
        return unit.health and unit.health.flags.needs_healthcare
    end, fn, reverse)
end

function count_units(for_fn, which)
    local count = 0
    for_fn(function() count = count + 1 end)
    if count > 0 then
        return ('%d %s%s'):format(
            count,
            which,
            count == 1 and '' or 's'
        )
    end
end

local function has_functional_hospital(site)
    for _,loc in ipairs(site.buildings) do
        if not df.abstract_building_hospitalst:is_instance(loc) or loc.flags.DOES_NOT_EXIST then
            goto continue
        end
        local diag, bone, surg = false, false, false
        for _,occ in ipairs(loc.occupations) do
            if df.unit.find(occ.unit_id) then
                if occ.type == df.occupation_type.DOCTOR or occ.type == df.occupation_type.DIAGNOSTICIAN then
                    diag = true
                end
                if occ.type == df.occupation_type.DOCTOR or occ.type == df.occupation_type.BONE_DOCTOR then
                    bone = true
                end
                if occ.type == df.occupation_type.DOCTOR or occ.type == df.occupation_type.SURGEON then
                    surg = true
                end
            end
        end
        if diag and bone and surg then
            return true
        end
        ::continue::
    end
end

local function injured_units(for_fn, which)
    local message = count_units(for_fn, which)
    if message then
        if not has_functional_hospital(dfhack.world.getCurrentSite()) then
            message = message .. '; no functional hospital!'
        end
        return message
    end
end

local function summarize_units(for_fn)
    local counts = {}
    for_fn(function(unit)
        local names = races[unit.race].caste[unit.caste].caste_name
        local record = ensure_key(counts, names[0], {count=0, plural=names[1]})
        record.count = record.count + 1
    end)
    if not next(counts) then return end
    local strs = {}
    for singular,record in pairs(counts) do
        table.insert(strs, ('%d %s'):format(record.count, record.count > 1 and record.plural or singular))
    end
    return ('Wildlife: %s'):format(table.concat(strs, ', '))
end

function zoom_to_next(for_fn, state, reverse)
    local first_found, ret
    for_fn(function(unit)
        if not first_found then
            first_found = unit
        end
        if not state then
            dfhack.gui.revealInDwarfmodeMap(
                xyz2pos(dfhack.units.getPosition(unit)), true, true)
            ret = unit.id
            return true
        elseif unit.id == state then
            state = nil
        end
    end, reverse)
    if ret then return ret end
    if first_found then
        dfhack.gui.revealInDwarfmodeMap(
            xyz2pos(dfhack.units.getPosition(first_found)), true, true)
        return first_found.id
    end
end

local function get_stranded_message()
    local count = #warn_stranded.getStrandedGroups()
    if count > 0 then
        return ('%d group%s of citizens %s stranded'):format(
            count,
            count == 1 and '' or 's',
            count == 1 and 'is' or 'are'
        )
    end
end

-- the order of this list controls the order the notifications will appear in the overlay
NOTIFICATIONS_BY_IDX = {
    {
        name='traders_ready',
        desc='Notifies when traders are ready to trade at the depot.',
        default=true,
        dwarf_fn=function()
            if #caravans == 0 then return end
            local num_ready = 0
            for _, car in ipairs(caravans) do
                if car.trade_state ~= df.caravan_state.T_trade_state.AtDepot then
                    goto skip
                end
                local car_civ = car.entity
                for _, unit in ipairs(df.global.world.units.active) do
                    if unit.civ_id ~= car_civ or not dfhack.units.isMerchant(unit) then
                        goto continue
                    end
                    for _, inv_item in ipairs(unit.inventory) do
                        if inv_item.item.flags.trader then
                            goto skip
                        end
                    end
                    ::continue::
                end
                num_ready = num_ready + 1
                ::skip::
            end
            if num_ready > 0 then
                return ('%d trader%s %s ready to trade'):format(
                    num_ready,
                    num_ready == 1 and '' or 's',
                    num_ready == 1 and 'is' or 'are'
                )
            end
        end,
        on_click=function()
            local bld = get_active_depot()
            if bld then
                dfhack.gui.revealInDwarfmodeMap(
                    xyz2pos(bld.centerx, bld.centery, bld.z), true, true)
            end
        end,
    },
    {
        name='mandates_expiring',
        desc='Notifies when a production mandate is within 1 month of expiring.',
        default=true,
        dwarf_fn=function()
            local count = 0
            for _, mandate in ipairs(df.global.world.mandates) do
                if mandate.mode == df.mandate.T_mode.Make and
                    mandate.timeout_limit - mandate.timeout_counter < 2500
                then
                    count = count + 1
                end
            end
            if count > 0 then
                return ('%d production mandate%s near deadline'):format(
                    count,
                    count == 1 and '' or 's'
                )
            end
        end,
        on_click=function()
            gui.simulateInput(dfhack.gui.getDFViewscreen(), 'D_NOBLES')
        end,
    },
    {
        name='petitions_agreed',
        desc='Notifies when you have agreed to build (but have not yet built) a guildhall or temple.',
        default=true,
        dwarf_fn=function()
            local t_agr, g_agr = list_agreements.get_fort_agreements(true)
            local sum = #t_agr + #g_agr
            if sum > 0 then
                return ('%d petition%s outstanding'):format(
                    sum, sum == 1 and '' or 's')
            end
        end,
        on_click=function() dfhack.run_script('gui/petitions') end,
    },
    {
        name='moody_status',
        desc='Describes the status of the current moody dwarf: gathering materials, working, or stuck',
        default=true,
        dwarf_fn=function()
            local message
            for_moody(function(unit)
                local job = unit.job.current_job
                local bld = dfhack.job.getHolder(job)
                if not bld then
                    if dfhack.buildings.findAtTile(unit.path.dest) then
                        message = 'moody dwarf is claiming a workshop'
                    else
                        message = 'moody dwarf can\'t find needed workshop!'
                    end
                elseif job.flags.fetching or job.flags.bringing or
                    unit.path.goal == df.unit_path_goal.None
                then
                    message = 'moody dwarf is gathering items'
                elseif job.flags.working then
                    message = 'moody dwarf is working'
                else
                    message = 'moody dwarf can\'t find needed item!'
                end
                return true
            end)
            return message
        end,
        on_click=curry(zoom_to_next, for_moody),
    },
    {
        name='warn_starving',
        desc='Reports units that are dangerously hungry, thirsty, or drowsy.',
        default=true,
        dwarf_fn=curry(count_units, for_starving, 'starving, dehydrated, or drowsy unit'),
        on_click=curry(zoom_to_next, for_starving),
    },
    {
        name='agitated_count',
        desc='Notifies when there are agitated animals on the map.',
        default=true,
        dwarf_fn=curry(count_units, for_agitated_creature, 'agitated animal'),
        on_click=curry(zoom_to_next, for_agitated_creature),
    },
    {
        name='invader_count',
        desc='Notifies when there are active invaders on the map.',
        default=true,
        dwarf_fn=curry(count_units, for_invader, 'invader'),
        on_click=curry(zoom_to_next, for_invader),
    },
    {
        name='hostile_count',
        desc='Notifies when there are non-invader hostiles (e.g. megabeasts) on the map.',
        default=true,
        dwarf_fn=curry(count_units, for_hostile, 'hostile'),
        on_click=curry(zoom_to_next, for_hostile),
    },
    {
        name='warn_nuisance',
        desc='Notifies when thieving or mischievous creatures are on the map.',
        default=true,
        dwarf_fn=curry(count_units, for_nuisance, 'thieving or mischievous creature'),
        on_click=curry(zoom_to_next, for_nuisance),
    },
    {
        name='warn_stranded',
        desc='Notifies when units are stranded from the main group.',
        default=true,
        dwarf_fn=get_stranded_message,
        on_click=function() dfhack.run_script('warn-stranded') end,
    },
    {
        name='wildlife',
        desc='Gives a summary of visible wildlife on the map.',
        default=false,
        dwarf_fn=curry(summarize_units, for_wildlife),
        on_click=curry(zoom_to_next, for_wildlife),
    },
    {
        name='wildlife_adv',
        desc='Gives a summary of visible wildlife on the map.',
        default=false,
        adv_fn=curry(summarize_units, for_wildlife_adv),
        on_click=curry(zoom_to_next, for_wildlife_adv),
    },
    {
        name='injured',
        desc='Shows number of injured citizens and a warning if there is no functional hospital.',
        default=true,
        dwarf_fn=curry(injured_units, for_injured, 'injured citizen'),
        on_click=curry(zoom_to_next, for_injured),
    },
}

NOTIFICATIONS_BY_NAME = {}
for _, v in ipairs(NOTIFICATIONS_BY_IDX) do
    NOTIFICATIONS_BY_NAME[v.name] = v
end

local function get_config()
    local f = json.open(CONFIG_FILE)
    local updated = false
    if f.exists then
        -- remove unknown or out of date entries from the loaded config
        for k, v in pairs(f.data) do
            if not NOTIFICATIONS_BY_NAME[k] or NOTIFICATIONS_BY_NAME[k].version ~= v.version then
                updated = true
                f.data[k] = nil
            end
        end
    end
    for k, v in pairs(NOTIFICATIONS_BY_NAME) do
        if not f.data[k] or f.data[k].version ~= v.version then
            f.data[k] = {enabled=v.default, version=v.version}
            updated = true
        end
    end
    if updated then
        f:write()
    end
    return f
end

config = get_config()
