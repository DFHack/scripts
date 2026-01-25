--@module = true

local dlg = require('gui.dialogs')
local gui = require('gui')
local json = require('json')
local utils = require('utils')
local list_agreements = reqscript('list-agreements')
local repeat_util = require('repeat-util')
local stuck_squad = reqscript('fix/stuck-squad')
local warn_stranded = reqscript('warn-stranded')

local CONFIG_FILE = 'dfhack-config/notify.json'

local buildings = df.global.world.buildings
local caravans = df.global.plotinfo.caravans
local units = df.global.world.units

-- TODO: Add a proper API and UI for notification configuration
-- this is global so one can use `:lua reqscript('internal/notify/notifications').save_time_threshold_mins=X` to change the threshold to X mins.
save_time_threshold_mins = save_time_threshold_mins or 15

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
            dfhack.units.isAgitated(unit)
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

local function for_hostile(fn, reverse)
    for_iter(units.active, function(unit)
        return not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            not unit.flags1.caged and
            not unit.flags1.chained and
            not dfhack.units.isInvader(unit) and
            not dfhack.units.isFortControlled(unit) and
            not dfhack.units.isHidden(unit) and
            not dfhack.units.isAgitated(unit) and
            dfhack.units.isDanger(unit)
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

local function is_stealer(unit)
    local casteFlags = dfhack.units.getCasteRaw(unit).flags
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
            (is_stealer(unit) or dfhack.units.isMischievous(unit)) and
            not unit.flags1.caged and
            not unit.flags1.chained and
            not dfhack.units.isHidden(unit) and
            not dfhack.units.isFortControlled(unit) and
            not dfhack.units.isInvader(unit) and
            not dfhack.units.isAgitated(unit) and
            not dfhack.units.isDanger(unit)
    end, fn, reverse)
end

local function for_wildlife(fn, reverse)
    for_iter(units.active, function(unit)
        return not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            dfhack.units.isWildlife(unit) and
            not unit.flags1.caged and
            not unit.flags1.chained and
            not dfhack.units.isHidden(unit) and
            not dfhack.units.isDanger(unit) and
            not is_stealer(unit) and
            not dfhack.units.isMischievous(unit) and
            not dfhack.units.isVisitor(unit)
    end, fn, reverse)
end

local function for_wildlife_adv(fn, reverse)
    local adv_id = dfhack.world.getAdventurer().id
    for_iter(units.active, function(unit)
        return not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            dfhack.units.isWildlife(unit) and
            not unit.flags1.caged and
            not unit.flags1.chained and
            not dfhack.units.isHidden(unit) and
            unit.relationship_ids.GroupLeader ~= adv_id and
            unit.relationship_ids.PetOwner ~= adv_id and
            is_adv_unhidden(unit)
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
        local names = dfhack.units.getCasteRaw(unit).caste_name
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

local function get_blood()
    return dfhack.world.getAdventurer().body.blood_count
end

local function get_max_blood()
    return dfhack.world.getAdventurer().body.blood_max
end

local function get_max_breath()
    local adventurer = dfhack.world.getAdventurer()
    local toughness = dfhack.units.getPhysicalAttrValue(adventurer, df.physical_attribute_type.TOUGHNESS)
    local endurance = dfhack.units.getPhysicalAttrValue(adventurer, df.physical_attribute_type.ENDURANCE)
    local base_ticks = 200

    return math.floor((endurance + toughness) / 4) + base_ticks
end

local function get_breath()
    return get_max_breath() - dfhack.world.getAdventurer().counters.suffocation
end

local function get_bar(get_fn, get_max_fn, text, color)
    if get_fn() < get_max_fn() then
        local label_text = {}
        table.insert(label_text, {text=text, pen=color, width=6})

        local bar_width = 16
        local percentage = get_fn() / get_max_fn()
        local barstop = math.floor((bar_width * percentage) + 0.5)
        for idx = 0, bar_width-1 do
            local bar_color = color
            local char = 219
            if idx >= barstop then
                -- offset it to the hollow graphic
                bar_color = COLOR_DARKGRAY
                char = 177
            end
            table.insert(label_text, {width=1, tile={ch=char, fg=bar_color}})
        end
        return label_text
    end
    return nil
end

local function get_save_alert()
    local mins_since_save = dfhack.persistent.getUnsavedSeconds()//60
    local pen = COLOR_LIGHTCYAN
    if mins_since_save < save_time_threshold_mins then return end
    if mins_since_save >= 4*save_time_threshold_mins then
        pen = COLOR_LIGHTRED
    elseif mins_since_save >= 2*save_time_threshold_mins then
        pen = COLOR_YELLOW
    end
    return {
        {text='Last save: ', pen=COLOR_WHITE},
        {text=dfhack.formatInt(mins_since_save) ..' mins ago', pen=pen},
    }
end

local function save_popup()
    local mins_since_save = dfhack.persistent.getUnsavedSeconds()//60
    local message = 'It has been ' .. dfhack.formatInt(mins_since_save) .. ' minutes since your last save.'
    if dfhack.world.isFortressMode() then
        message = message .. '\n\nWould you like to save now? (Note: You can also close this reminder and save manually)'
        dlg.showYesNoPrompt('Save now?', message, nil, function() dfhack.run_script('quicksave') end)
    else
        message = message .. '\n\nClose this popup to open the options menu and select "Save and continue playing"'
        dlg.showMessage('Save reminder', message, COLOR_WHITE, function() gui.simulateInput(dfhack.gui.getDFViewscreen(true), 'OPTIONS') end)
    end
end

---@return string[]
local function get_active_units_with_missing_nemesis_records()
    local namelist = {}
    for _, unit in ipairs(df.global.world.units.active) do
        local ref = dfhack.units.getGeneralRef(unit, df.general_ref_type.IS_NEMESIS)
        if ref then
            local nrec = ref:getNemesis()
            if nrec == nil then
                table.insert(namelist, dfhack.units.getReadableName(unit))
            end
        end
    end
    return namelist
end

---@param vector any[]         # a df vector or array, or a Lua list.
---@param field string?        # nil, or the field name to sort on.
---@param comparator fun(a:any, b:any):integer|nil
---     # an optional comparator that returns -1,0,1 per utils.compare_* .
---     # nil falls back to utils.compare or utils.compare_field.
---     # if a comparator is given, the field parameter is ignored.
---@return boolean
local function verify_vector_is_sorted(vector, field, comparator)
    assert(type(vector) == 'table' or utils.is_container(vector))
    assert(type(field) == 'string' or field == nil)
    assert(type(comparator) == 'function' or comparator == nil)
    comparator = comparator or utils.compare_field(field)
    local lo, hi
    if type(vector) == 'table' then
        lo, hi = 1, #vector
    else
        lo, hi = 0, #vector-1
    end
    local sorted = true
    for i = lo, hi-1 do
        if comparator(vector[i], vector[i+1]) ~= -1 then
            sorted = false
            break
        end
    end
    return sorted
end

local cache_nemesis_all_is_sorted = {}
---only verifies if the vector length has changed.
---@return boolean
local function verify_nemesis_all_is_sorted()
    local vector = df.global.world.nemesis.all
    if #vector == cache_nemesis_all_is_sorted.length then
        return cache_nemesis_all_is_sorted.sorted
    end
    cache_nemesis_all_is_sorted.length = #vector
    cache_nemesis_all_is_sorted.sorted = verify_vector_is_sorted(vector, 'id')
    return cache_nemesis_all_is_sorted.sorted
end

-- the order of this list controls the order the notifications will appear in the overlay
NOTIFICATIONS_BY_IDX = {
    {
        name='missing_nemesis',
        desc='Reports missing nemesis records, indicating savegame corruption.',
        default=true,
        fn = function()
            if not verify_nemesis_all_is_sorted() then
                return { {
                    pen = COLOR_LIGHTRED,
                    text = 'nemesis vector not sorted'
                } }
            end
            local count = df.global.nemesis_next_id - #df.global.world.nemesis.all
            if count == 0 then return end
            return { {
                pen = COLOR_LIGHTRED,
                text = ('missing %d nemesis record%s'):format(count, count == 1 and '' or 's')
            } }
        end,
        on_click=function()
            if not verify_nemesis_all_is_sorted() then
                local message =
                    'This save game is corrupt.\n\nThe world.nemesis.global vector\n' ..
                    'of this savegame is not sorted.\n\nSome attempts to lookup the\n' ..
                    'nemesis record for a unit or\nhistorical figure will fail.\n\n' ..
                    'This should be reported to\nBay 12 Games as a bug.\n'
                dlg.showMessage('nemesis vector not sorted', message, COLOR_RED)
                return
            end
            local message = {
                { pen = COLOR_RED,   text = 'This save game may be corrupt.' }, NEWLINE,
                NEWLINE,
                { pen = COLOR_WHITE, text = 'This save game contains units which are missing' }, NEWLINE,
                { pen = COLOR_WHITE, text = 'their assigned nemesis records.' }, NEWLINE,
                NEWLINE,
                { pen = COLOR_WHITE, text = 'Missing nemesis records have been known to cause' }, NEWLINE,
                { pen = COLOR_WHITE, text = 'crashes during game save and when retiring forts.' }, NEWLINE,
                NEWLINE,
                { pen = COLOR_WHITE, text = 'Units with missing nemesis records will' }, NEWLINE,
                { pen = COLOR_RED,   text = 'permanently disappear' },
                { pen = COLOR_WHITE, text =                      ' if they leave the map or' }, NEWLINE,
                { pen = COLOR_WHITE, text = 'if the fort is retired.' }, NEWLINE,
                NEWLINE,
            }
            local redtext = get_active_units_with_missing_nemesis_records()
            if #redtext > 0 then
                table.insert(message, { pen = COLOR_RED,
                    text = 'These active units are missing their nemesis records:' })
                table.insert(message, NEWLINE)
                for _, line in ipairs(redtext) do
                    table.insert(message, { pen = COLOR_LIGHTRED, text = '  ' .. line })
                    table.insert(message, NEWLINE)
                end
            end
            dlg.showMessage((#redtext > 0 and 'Active units are' or 'This world is')
                .. ' missing nemesis records',message, COLOR_WHITE)
        end,
    },
    {
        name='stuck_squad',
        desc='Notifies when a squad is stuck on the world map.',
        default=true,
        dwarf_fn=function()
            local stuck_armies, outbound_army, returning_army = stuck_squad.scan_fort_armies()
            if #stuck_armies == 0 then return end
            if repeat_util.isScheduled('control-panel/fix/stuck-squad') and (outbound_army or returning_army) then
                return
            end
            return ('%d squad%s need%s rescue'):format(
                #stuck_armies,
                #stuck_armies == 1 and '' or 's',
                #stuck_armies == 1 and 's' or ''
            )
        end,
        on_click=function()
            local message = 'A squad is lost on the world map and needs rescue!\n\n' ..
                'Please send a messenger to a holding or a squad out on a mission\n' ..
                'that will return to the fort (e.g. a Demand one-time tribute mission,\n' ..
                'but not a Conquer and occupy mission). They will rescue the stuck\n' ..
                'squad on their way home.'
            if not repeat_util.isScheduled('control-panel/fix/stuck-squad') then
                message = message .. '\n\n' ..
                    'Please enable fix/stuck-squad in the DFHack control panel to enable\n'..
                    'missions to rescue stuck squads.'
            end
            dlg.showMessage('Rescue stuck squads', message, COLOR_WHITE)
        end,
    },
    {
        name='auto_train',
        desc='Notifies when there are no squads set up for training',
        default=true,
        dwarf_fn=function()
            local at = reqscript('autotraining')
            if (at.isEnabled() and at.checkSquads() == nil) then
                return {{text="autotraining: no squads selected",pen=COLOR_LIGHTRED}}
            end
        end,
        on_click=function()
            local message =
            "You have no squads selected for training.\n"..
            "You should have a squad set up to be constantly training with about 8 units needed for training.\n"..
            "Then you can select that squad for training in the config.\n\nWould you like to open the config? Alternatively, simply close this popup to go create a squad."
            dlg.showYesNoPrompt('Training Squads not configured', message, COLOR_WHITE, function () dfhack.run_command('gui/autotraining') end)
        end,
    },
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
            for _, mandate in ipairs(df.global.world.mandates.all) do
                if mandate.mode == df.mandate_type.Make and
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
                        message = {{text='moody dwarf can\'t find needed workshop!', pen=COLOR_LIGHTRED}}
                    end
                elseif job.flags.fetching or job.flags.bringing or
                    unit.path.goal == df.unit_path_goal.None
                then
                    message = 'moody dwarf is gathering items'
                elseif job.flags.working then
                    message = 'moody dwarf is working'
                else
                    message = {{text='moody dwarf can\'t find needed item!', pen=COLOR_LIGHTRED}}
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
    {
        name='suffocation_adv',
        desc='Shows a suffocation bar when you are drowning or breathless.',
        default=true,
        critical=true,
        adv_fn=curry(get_bar, get_breath, get_max_breath, "Air", COLOR_LIGHTCYAN),
        on_click=nil,
    },
    {
        name='bleeding_adv',
        desc='Shows a bleeding bar when you are losing blood.',
        default=true,
        critical=true,
        adv_fn=curry(get_bar, get_blood, get_max_blood, "Blood", COLOR_RED),
        on_click=nil,
    },
    {
        name='save-reminder',
        desc=('Shows a reminder if it has been more than %d minute%s since your last save.'):format(save_time_threshold_mins, save_time_threshold_mins == 1 and '' or 's'),
        default=true,
        fn=get_save_alert,
        on_click=save_popup,
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

dfhack.onStateChange['internal/notify/notifications'] = function(event)
    if event == SC_WORLD_LOADED or event == SC_WORLD_UNLOADED then
        cache_nemesis_all_is_sorted = {}
    end
end
