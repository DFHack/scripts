--@module=true

local utils = require('utils')

local function get_translation(race_id)
    local race_name = df.global.world.raws.creatures.all[race_id].creature_id
    for _,translation in ipairs(df.global.world.raws.language.translations) do
        if translation.name == race_name then
            return translation
        end
    end
    return df.global.world.raws.language.translations[0]
end

local function pick_first_name(race_id)
    local translation = get_translation(race_id)
    return translation.words[math.random(0, #translation.words-1)].value
end

local LANGUAGE_IDX = 0
local word_table = df.global.world.raws.language.word_table[LANGUAGE_IDX][35]

function name_unit(unit)
    if unit.name.has_name then return end

    unit.name.first_name = pick_first_name(unit.race)
    unit.name.words.FrontCompound = word_table.words.FrontCompound[math.random(0, #word_table.words.FrontCompound-1)]
    unit.name.words.RearCompound = word_table.words.RearCompound[math.random(0, #word_table.words.RearCompound-1)]

    unit.name.language = LANGUAGE_IDX
    unit.name.parts_of_speech.FrontCompound = df.part_of_speech.Noun
    unit.name.parts_of_speech.RearCompound = df.part_of_speech.Verb3rdPerson
    unit.name.type = df.language_name_type.Figure
    unit.name.has_name = true

    local hf = df.historical_figure.find(unit.hist_figure_id)
    if not hf then return end
    hf.name:assign(unit.name)
end

local function fix_clothing_ownership(unit)
    if #unit.uniform.uniform_drop == 0 then return end
    -- makeown'd units do not own their clothes which results in them dropping all their clothes and
    -- becoming unhappy because they are naked
    -- so we need to make them own their clothes and add them to their uniform
    for _, inv_item in ipairs(unit.inventory) do
        local item = inv_item.item
        -- only act on worn items, not weapons
        if inv_item.mode == df.unit_inventory_item.T_mode.Worn and
            not dfhack.items.getOwner(item) and
            dfhack.items.setOwner(item, unit)
        then
            -- unforbid items (for the case of kidnapping caravan escorts who have their stuff forbidden by default)
            item.flags.forbid = false
            unit.uniform.uniforms[df.unit_uniform_mode_type.CLOTHING]:insert('#', item.id)
        end
    end
    -- clear uniform_drop (without this they would drop their clothes and pick them up some time later)
    unit.uniform.uniform_drop:resize(0)
end

function clear_enemy_status(unit)
    if unit.enemy.enemy_status_slot <= -1 then return end

    local status_cache = df.global.world.enemy_status_cache
    local status_slot = unit.enemy.enemy_status_slot

    unit.enemy.enemy_status_slot = -1
    status_cache.slot_used[status_slot] = false

    for index in ipairs(status_cache.rel_map[status_slot]) do
        status_cache.rel_map[status_slot][index] = -1
    end

    for index in ipairs(status_cache.rel_map) do
        status_cache.rel_map[index][status_slot] = -1
    end

    -- TODO: what if there were status slots taken above status_slot?
    -- does everything need to be moved down by one to fill the gap?
    if status_cache.next_slot > status_slot then
        status_cache.next_slot = status_slot
    end
end

local prof_map = {
    [df.profession.MERCHANT]=df.profession.TRADER,
    [df.profession.THIEF]=df.profession.STANDARD,
    [df.profession.MASTER_THIEF]=df.profession.STANDARD,
    [df.profession.CRIMINAL]=df.profession.STANDARD,
    [df.profession.DRUNK]=df.profession.STANDARD,
    [df.profession.MONSTER_SLAYER]=df.profession.STANDARD,
    [df.profession.SCOUT]=df.profession.STANDARD,
    [df.profession.BEAST_HUNTER]=df.profession.STANDARD,
    [df.profession.SNATCHER]=df.profession.STANDARD,
    [df.profession.MERCENARY]=df.profession.STANDARD,
}

local function sanitize_profession(prof)
    return prof_map[prof] or prof
end

local hostile_jobs = utils.invert{
    df.job_type.Kidnap,
    df.job_type.HeistItem,
    df.job_type.AcceptHeistItem,
}

local function cancel_hostile_jobs(job)
    if not job or not hostile_jobs[job.job_type] then return end
    dfhack.job.removeJob(job)
end

local function fix_unit(unit)
    unit.flags1.marauder = false;
    unit.flags1.merchant = false;
    unit.flags1.forest = false;
    unit.flags1.diplomat = false;
    unit.flags1.active_invader = false;
    unit.flags1.hidden_in_ambush = false;
    unit.flags1.invader_origin = false;
    unit.flags1.coward = false
    unit.flags1.hidden_ambusher = false;
    unit.flags1.invades = false;
    unit.flags2.underworld = false;        --or on a demon!
    unit.flags2.resident = false;
    unit.flags2.visitor_uninvited = false; --in case you use makeown on a beast :P
    unit.flags2.visitor = false;
    unit.flags3.guest = false;
    unit.flags4.invader_waits_for_parley = false;
    unit.flags4.agitated_wilderness_creature = false;

    unit.civ_id = df.global.plotinfo.civ_id;

    unit.profession = sanitize_profession(unit.profession)
    unit.profession2 = sanitize_profession(unit.profession2)

    unit.invasion_id = -1
    unit.enemy.army_controller_id = -1
    unit.enemy.army_controller = nil

    unit.relationship_ids.GroupLeader = -1
    for _,other in ipairs(df.global.world.units.active) do
        if other.relationship_ids.GroupLeader == unit.id then
            other.relationship_ids.GroupLeader = -1
        end
    end

    -- remove unit from all current conflicts
    unit.activities:resize(0)
    for _,act in ipairs(df.global.world.activities.all) do
        if act.type ~= df.activity_entry_type.Conflict then goto continue end
        for _,ev in ipairs(act.events) do
            if ev:getType() ~= df.activity_event_type.Conflict then goto next_ev end
            for _,side in ipairs(ev.sides) do
                utils.erase_sorted(side.histfig_ids, unit.hist_figure_id)
                utils.erase_sorted(side.unit_ids, unit.id)
            end
            ::next_ev::
        end
        ::continue::
    end

    clear_enemy_status(unit)

    cancel_hostile_jobs(unit.job.current_job)
end

local function add_to_entity(hf, eid)
    local en = df.historical_entity.find(eid)
    if not en then return end
    utils.insert_sorted(en.histfig_ids, hf.id)
    utils.insert_sorted(en.hist_figures, hf, 'id')
    if hf.nemesis_id < 0 then return end
    utils.insert_sorted(en.nemesis_ids, hf.nemesis_id)
end

local function remove_from_entity(hf, eid)
    local en = df.historical_entity.find(eid)
    if not en then return end
    utils.erase_sorted(en.histfig_ids, hf.id)
    utils.erase_sorted(en.hist_figures, hf, 'id')
    if hf.nemesis_id < 0 then return end
    utils.erase_sorted(en.nemesis_ids, hf.nemesis_id)
end

local function entity_link(hf, eid, do_event, add, replace_idx)
    do_event = (do_event == nil) and true or do_event
    add = (add == nil) and true or add
    replace_idx = replace_idx or -1

    local link = add and df.histfig_entity_link_memberst:new() or df.histfig_entity_link_former_memberst:new()
    link.entity_id = eid

    if replace_idx > -1 then
        local e = hf.entity_links[replace_idx]
        link.link_strength = (e.link_strength > 3) and (e.link_strength - 2) or e.link_strength
        hf.entity_links[replace_idx] = link -- replace member link with former member link
        e:delete()
    else
        link.link_strength = 100
        hf.entity_links:insert('#', link)
    end

    if do_event then
        local event = add and df.history_event_add_hf_entity_linkst:new() or df.history_event_remove_hf_entity_linkst:new()
        event.year = df.global.cur_year
        event.seconds = df.global.cur_year_tick
        event.civ = eid
        event.histfig = hf.id
        event.link_type = 0
        event.position_id = -1
        event.id = df.global.hist_event_next_id
        df.global.world.history.events:insert('#',event)
        df.global.hist_event_next_id = df.global.hist_event_next_id + 1
    end

    if add then
        add_to_entity(hf, eid)
    else
        remove_from_entity(hf, eid)
    end
end

local function fix_whereabouts(hf, site_id)
    hf.info.whereabouts.state = df.whereabouts_type.settler
    if hf.info.whereabouts.site_id == site_id then return end
    hf.info.whereabouts.site_id = site_id
    local event = df.history_event_change_hf_statest:new()
    event.year = df.global.cur_year
    event.seconds = df.global.cur_year_tick
    event.id = df.global.hist_event_next_id
    event.hfid = hf.id
    event.state = df.whereabouts_type.settler
    event.reason = df.history_event_reason.whim
    event.site = site_id
    event.region = -1
    event.layer = -1
    event.region_pos:assign(df.world_site.find(site_id).pos)
    df.global.world.history.events:insert('#', event)
    df.global.hist_event_next_id = df.global.hist_event_next_id + 1
end

local function fix_histfig(unit)
    local hf = df.historical_figure.find(unit.hist_figure_id)
    if not hf then return end

    local civ_id = df.global.plotinfo.civ_id
    local group_id = df.global.plotinfo.group_id

    hf.civ_id = civ_id
    if hf.info and hf.info.whereabouts then
        fix_whereabouts(hf, df.global.plotinfo.site_id)
    end

    -- make former members of any civ/site that isn't ours that they are currently a member of
    local found_civlink = false
    local found_fortlink = false
    for k=#hf.entity_links-1,0,-1 do
        local el = hf.entity_links[k]
        if df.histfig_entity_link_memberst:is_instance(el) then
            local eid = el.entity_id
            local he = df.historical_entity.find(eid)
            if not he then goto continue end
            if he.type == df.historical_entity_type.Civilization then
                if he.id == civ_id then
                    found_civlink = true
                    goto continue
                end
            elseif he.type == df.historical_entity_type.SiteGovernment then
                if he.id == group_id then
                    found_fortlink = true
                    goto continue
                end
            else
                -- don't touch other kinds of memberships
                goto continue
            end
            entity_link(hf, eid, true, false, k)
            ::continue::
        end
    end

    -- add them to our civ/site if they aren't already
    if not found_civlink  then entity_link(hf, civ_id)   end
    if not found_fortlink then entity_link(hf, group_id) end

    hf.profession = sanitize_profession(unit.profession)
end

---@param unit df.unit
function make_own(unit)
    dfhack.units.makeown(unit)

    fix_unit(unit)
    fix_histfig(unit)
    fix_clothing_ownership(unit)

    local caste_flags = unit.enemy.caste_flags
    if caste_flags.CAN_SPEAK or caste_flags.CAN_LEARN then
        -- generate a name for the unit if it doesn't already have one
        name_unit(unit)
    else
        unit.flags1.tame = true
        unit.training_level = df.animal_training_level.Domesticated
    end
end

if dfhack_flags.module then
    return
end

unit = dfhack.gui.getSelectedUnit(true)
if not unit then
    qerror('No unit selected!')
else
    make_own(unit)
end
