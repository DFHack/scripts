-- Automatically boost the priority of selected job types.
--@module = true
--@enable = true

local argparse = require('argparse')
local eventful = require('plugins.eventful')
local gui = require('gui')
local overlay = require('plugins.overlay')
local utils = require('utils')
local widgets = require('gui.widgets')

local GLOBAL_KEY = 'prioritize' -- used for state change hooks and persistence

local DEFAULT_HAUL_LABORS = {'Food', 'Body', 'Animals'}
local DEFAULT_REACTION_NAMES = {'TAN_A_HIDE', 'ADAMANTINE_WAFERS'}
local DEFAULT_JOB_TYPES = {
    -- take care of rottables before they rot
    'StoreItemInStockpile', 'CustomReaction', 'StoreItemInBarrel',
    'PrepareRawFish', 'PlaceItemInTomb',
    -- ensure medical, hygiene, and hospice tasks get done
    'ApplyCast', 'BringCrutch', 'CleanPatient', 'CleanSelf',
    'DiagnosePatient', 'DressWound', 'GiveFood', 'GiveWater',
    'ImmobilizeBreak', 'PlaceInTraction', 'RecoverWounded',
    'SeekInfant', 'SetBone', 'Surgery', 'Suture',
    -- ensure prisoners and animals are tended to quickly
    -- (Animal/prisoner storage already covered by 'StoreItemInStockpile' above)
    'SlaughterAnimal', 'ButcherAnimal', 'PenLargeAnimal', 'ChainAnimal', 'LoadCageTrap',
    -- ensure noble tasks never get starved
    'InterrogateSubject', 'ManageWorkOrders', 'ReportCrime', 'TradeAtDepot',
    -- get tasks done quickly that might block the player from getting on to
    -- the next thing they want to do
    'BringItemToDepot', 'DestroyBuilding', 'DumpItem', 'FellTree',
    'RemoveConstruction', 'PullLever', 'FillPond', 'PutItemOnDisplay',
}

-- set of job types that we are watching. maps job_type (as a number) to
-- {
--   hauler_matchers=map of type to num_prioritized,
--   reaction_matchers=map of string to num_prioritized,
-- }
-- this needs to be global so we don't lose player-set state when the script is
-- reparsed. Also a getter function that can be mocked out by unit tests.
g_watched_job_matchers = g_watched_job_matchers or {}
function get_watched_job_matchers() return g_watched_job_matchers end

eventful.enableEvent(eventful.eventType.UNLOAD, 1)
eventful.enableEvent(eventful.eventType.JOB_INITIATED, 5)

function isEnabled()
    return next(get_watched_job_matchers())
end

local function persist_state()
    local data_to_persist = {}
    -- convert enum keys into strings so json doesn't get confused and think the map is a sparse list
    for k, v in pairs(get_watched_job_matchers()) do
        data_to_persist[tostring(k)] = v
    end
    dfhack.persistent.saveSiteData(GLOBAL_KEY, data_to_persist)
end

local function make_matcher_map(keys)
    if not keys then return nil end
    local t = {}
    for _,key in ipairs(keys) do
        t[key] = true
    end
    return t
end

local function make_job_matcher(unit_labors, reaction_names)
    return {
        hauler_matchers=make_matcher_map(unit_labors),
        reaction_matchers=make_matcher_map(reaction_names),
    }
end

local function matches(job_matcher, job)
    if not job_matcher then return false end
    if job_matcher.hauler_matchers and
            not job_matcher.hauler_matchers[job.item_subtype] then
        return false
    end
    if job_matcher.reaction_matchers and
            not job_matcher.reaction_matchers[job.reaction_name] then
        return false
    end
    return true
end

-- returns true if the job is matched
local function boost_job_if_matches(job, job_matchers)
    if matches(job_matchers[job.job_type], job) then
        job.flags.do_now = true
        return true
    end
    return false
end

local function on_new_job(job)
    boost_job_if_matches(job, get_watched_job_matchers())
end

local function clear_watched_job_matchers()
    local watched_job_matchers = get_watched_job_matchers()
    for job_type in pairs(watched_job_matchers) do
        watched_job_matchers[job_type] = nil
    end
    eventful.onUnload.prioritize = nil
    eventful.onJobInitiated.prioritize = nil
end

local function update_handlers()
    if next(get_watched_job_matchers()) then
        eventful.onUnload.prioritize = clear_watched_job_matchers
        eventful.onJobInitiated.prioritize = on_new_job
    else
        clear_watched_job_matchers()
    end
end

local function get_unit_labor_str(unit_labor)
    local labor_str = df.unit_labor[unit_labor]
    return ('%s%s'):format(labor_str:sub(6,6), labor_str:sub(7):lower())
end

local function get_unit_labor_annotation_str(unit_labor)
    return (' --haul-labor %s'):format(get_unit_labor_str(unit_labor))
end

local function get_reaction_annotation_str(reaction)
    return (' --reaction-name %s'):format(reaction)
end

local function get_status_line(job_type, annotation)
    annotation = annotation or ''
    return ('  %s%s'):format(df.job_type[job_type], annotation)
end

local function status()
    local lines = {}
    local watched_job_matchers = get_watched_job_matchers()
    for k,v in pairs(watched_job_matchers) do
        if v.hauler_matchers then
            for hk in pairs(v.hauler_matchers) do
                table.insert(lines, get_status_line(k, get_unit_labor_annotation_str(hk)))
            end
        elseif v.reaction_matchers then
            for rk in pairs(v.reaction_matchers) do
                table.insert(lines, get_status_line(k, get_reaction_annotation_str(rk)))
            end
        else
            table.insert(lines, get_status_line(k))
        end
    end
    if not next(lines) then
        print('Not automatically prioritizing any jobs.')
        return
    end
    table.sort(lines)
    print('Automatically prioritized jobs:')
    for _, line in ipairs(lines) do
        print(line)
    end
end

-- encapsulate df state in functions so unit tests can mock them out
function get_postings()
    return df.global.world.jobs.postings
end
function get_reactions()
    return df.global.world.raws.reactions.reactions
end
function get_job_list()
    return df.global.world.jobs.list
end

local function for_all_live_postings(cb)
    for _,posting in ipairs(get_postings()) do
        if posting.job and not posting.flags.dead then
            cb(posting)
        end
    end
end

local function for_all_jobs(cb)
    for _,job in utils.listpairs(get_job_list()) do
        if not job.flags.special then
            cb(job)
        end
    end
end

local function boost(job_matchers, opts)
    local count, already_prioritized = 0, 0
    for_all_jobs(
        function(job)
            local was_prioritized = job.flags.do_now
            if boost_job_if_matches(job, job_matchers) then
                if was_prioritized then
                    already_prioritized = already_prioritized + 1
                else
                    count = count + 1
                end
            end
        end)
    if not opts.quiet then
        print(('Prioritized %d job%s.'):format(count, count == 1 and '' or 's'))
        if already_prioritized > 0 then
            print(('%d job%s already prioritized.'):format(already_prioritized, already_prioritized == 1 and '' or 's'))
        end
    end
end

local function print_add_message(job_type, annotation)
    annotation = annotation or ''
    print(('Automatically prioritizing future jobs of type: %s%s')
          :format(df.job_type[job_type], annotation))
end

local function print_skip_add_message(job_type, annotation)
    annotation = annotation or ''
    print(('Skipping already-watched type: %s%s')
          :format(df.job_type[job_type], annotation))
end

local function boost_and_watch_special(job_type, job_matcher,
                                       get_special_matchers_fn,
                                       clear_special_matchers_fn, annotation_fn,
                                       quiet)
    local watched_job_matchers = get_watched_job_matchers()
    local watched_job_matcher = watched_job_matchers[job_type]
    local special_matchers = get_special_matchers_fn(job_matcher)
    local wspecial_matchers = watched_job_matcher and
            get_special_matchers_fn(watched_job_matcher) or nil
    if not watched_job_matcher then
        -- no similar job already being watched; add the matcher verbatim
        watched_job_matchers[job_type] = job_matcher
        if not quiet then
            if not special_matchers then
                print_add_message(job_type)
            else
                for key in pairs(special_matchers) do
                    print_add_message(job_type, annotation_fn(key))
                end
            end
        end
    elseif not wspecial_matchers and not special_matchers then
        -- no special matchers for existing matcher or new matcher; nothing new
        -- to watch
        if not quiet then
            print_skip_add_message(job_type)
        end
    elseif not wspecial_matchers then
        -- existing matcher is broader than new matchers; nothing new to watch
        for key in pairs(special_matchers) do
            if not quiet then
                print_skip_add_message(job_type, annotation_fn(key))
            end
        end
    elseif not special_matchers then
        -- new matcher is broader than existing matcher; overwrite with new
        if not quiet then
            print_add_message(job_type)
        end
        clear_special_matchers_fn(watched_job_matcher)
    else
        -- diff new matcher into existing matcher
        for key in pairs(special_matchers) do
            if wspecial_matchers[key] then
                if not quiet then
                    print_skip_add_message(job_type, annotation_fn(key))
                end
            else
                wspecial_matchers[key] = 0
                if not quiet then
                    print_add_message(job_type, annotation_fn(key))
                end
            end
        end
    end
end

local JOB_TYPES_DENYLIST = utils.invert{
    df.job_type.CarveFortification,
    df.job_type.SmoothWall,
    df.job_type.SmoothFloor,
    df.job_type.DetailWall,
    df.job_type.DetailFloor,
    df.job_type.Dig,
    df.job_type.CarveUpwardStaircase,
    df.job_type.CarveDownwardStaircase,
    df.job_type.CarveUpDownStaircase,
    df.job_type.CarveRamp,
    df.job_type.DigChannel,
}

local DIG_SMOOTH_WARNING = {
    'Priortizing current jobs, but skipping automatic boosting of dig and',
    'smooth/engrave job types. Automatic priority boosting of these types of jobs',
    'will overwhelm the DF job scheduler. Instead, consider specializing units for',
    'mining and related work details, and using vanilla designation priorities.',
}

local function boost_and_watch(job_matchers, opts)
    local quiet = opts.quiet
    boost(job_matchers, opts)
    local watched_job_matchers = get_watched_job_matchers()
    for job_type,job_matcher in pairs(job_matchers) do
        if job_type == df.job_type.StoreItemInStockpile then
            boost_and_watch_special(job_type, job_matcher,
                function(jm) return jm.hauler_matchers end,
                function(jm) jm.hauler_matchers = nil end,
                get_unit_labor_annotation_str, quiet)
        elseif job_type == df.job_type.CustomReaction then
            boost_and_watch_special(job_type, job_matcher,
                function(jm) return jm.reaction_matchers end,
                function(jm) jm.reaction_matchers = nil end,
                get_reaction_annotation_str, quiet)
        elseif JOB_TYPES_DENYLIST[job_type] then
            for _,msg in ipairs(DIG_SMOOTH_WARNING) do
                dfhack.printerr(msg)
            end
        elseif watched_job_matchers[job_type] then
            if not quiet then
                print_skip_add_message(job_type)
            end
        else
            watched_job_matchers[job_type] = job_matcher
            if not quiet then
                print_add_message(job_type)
            end
        end
    end
    update_handlers()
end

local function print_del_message(job_type, annotation)
    annotation = annotation or ''
    print(('No longer automatically prioritizing jobs of type: %s%s')
          :format(df.job_type[job_type], annotation))
end

local function print_skip_del_message(job_type, annotation)
    annotation = annotation or ''
    print(('Skipping unwatched type: %s%s')
          :format(df.job_type[job_type], annotation))
end

local function remove_watch_special(job_type, job_matcher,
                                    get_special_matchers_fn,
                                    fill_special_matcher_fn,
                                    annotation_fn, quiet)
    local watched_job_matchers = get_watched_job_matchers()
    local watched_job_matcher = watched_job_matchers[job_type]
    local special_matchers = get_special_matchers_fn(job_matcher)
    local wspecial_matchers = watched_job_matcher and
            get_special_matchers_fn(watched_job_matcher) or nil
    if not wspecial_matchers then
        -- if we're removing specific subtypes from an all-inclusive spec, then
        -- add all the possible individual subtypes before we remove the ones
        -- that were specified.
        wspecial_matchers = fill_special_matcher_fn(watched_job_matcher)
    end
    -- remove the specified subtypes
    for key in pairs(special_matchers) do
        if wspecial_matchers[key] then
            if not quiet then
                print_del_message(job_type, annotation_fn(key))
            end
            wspecial_matchers[key] = nil
        else
            if not quiet then
                print_skip_del_message(job_type, annotation_fn(key))
            end
        end
    end
    if not next(wspecial_matchers) then
        watched_job_matchers[job_type] = nil
    end
end

local function remove_watch(job_matchers, opts)
    local quiet = opts.quiet
    local watched_job_matchers = get_watched_job_matchers()
    for job_type,job_matcher in pairs(job_matchers) do
        local wjm = watched_job_matchers[job_type]
        if not wjm then
            -- job type not being watched; nothing to remove
            if not quiet then
                print_skip_del_message(job_type)
            end
        elseif not job_matcher.hauler_matchers
                and not job_matcher.reaction_matchers then
            -- no special matchers in job_matchers; stop watching all
            watched_job_matchers[job_type] = nil
            if not quiet then
                print_del_message(job_type)
            end
        elseif job_type == df.job_type.StoreItemInStockpile then
            remove_watch_special(job_type, job_matcher,
                function(jm) return jm.hauler_matchers end,
                function(jm)
                    jm.hauler_matchers = {}
                    for id,name in ipairs(df.unit_labor) do
                        if name:startswith('HAUL_')
                                and id <= df.unit_labor.HAUL_ANIMALS then
                            jm.hauler_matchers[id] = 0
                        end
                    end
                    return jm.hauler_matchers
                end,
                get_unit_labor_annotation_str, quiet)
        elseif job_type == df.job_type.CustomReaction then
            remove_watch_special(job_type, job_matcher,
                function(jm) return jm.reaction_matchers end,
                function(jm)
                    jm.reaction_matchers = {}
                    for _,v in ipairs(get_reactions()) do
                        jm.reaction_matchers[v.code] = 0
                    end
                    return jm.reaction_matchers
                end,
                get_reaction_annotation_str, quiet)
        else
            error('unhandled case') -- should not ever happen
        end
    end
    update_handlers()
end

local function get_job_type_str(job)
    local job_type = job.job_type
    local job_type_str = df.job_type[job_type]
    if job_type == df.job_type.StoreItemInStockpile then
        return ('%s%s'):format(job_type_str,
                               get_unit_labor_annotation_str(job.item_subtype))
    elseif job_type == df.job_type.CustomReaction then
        return ('%s%s'):format(job_type_str,
                               get_reaction_annotation_str(job.reaction_name))
    else
        return job_type_str
    end
end

local function print_current_jobs(job_matchers, opts)
    local all_jobs, unclaimed_jobs = {}, {}
    local filtered = next(job_matchers)
    local function count_job(jobs, job)
        if filtered and not job_matchers[job.job_type] then return end
        if job.flags.do_now then return end
        local job_type = get_job_type_str(job)
        jobs[job_type] = (jobs[job_type] or 0) + 1
    end
    for_all_jobs(curry(count_job, all_jobs))
    for_all_live_postings(function(posting) count_job(unclaimed_jobs, posting.job) end)
    local first = true
    for k,v in pairs(all_jobs) do
        if first then
            print('Current prioritizable jobs:')
            print()
            print(('unclaimed  total  job type'))
            print(('---------  -----  --------'))
            first = false
        end
        print(('%9d  %5d  %s'):format(unclaimed_jobs[k] or 0, v, k))
    end
    if first then print('No current prioritizable jobs.') end
end

local function print_registry_section(header, t)
    print('\n' .. header .. ':')
    table.sort(t)
    for _,v in ipairs(t) do
        print('  ' .. v)
    end
end

local function print_registry()
    local t = {}
    for _,v in ipairs(df.job_type) do
        -- don't clutter the output with esoteric or non-prioritizable job types
        if v and df.job_type[v] and v:find('^%u%l')
                and not v:find('^StrangeMood') then
            table.insert(t, v)
        end
    end
    print_registry_section('Job types', t)

    t = {}
    for i,v in ipairs(df.unit_labor) do
        if v:startswith('HAUL_') then
            table.insert(t, get_unit_labor_str(i))
        end
        if i >= df.unit_labor.HAUL_ANIMALS then
            -- don't include irrelevant HAUL_TRADE or HAUL_WATER labors
            break
        end
    end
    print_registry_section('Hauling labors (for StoreItemInStockpile jobs)', t)

    t = {}
    for _,v in ipairs(get_reactions()) do
        -- don't clutter the output with generated reactions (like instrument
        -- piece creation reactions). space characters seem to be a good
        -- discriminator.
        if not v.code:find(' ') then
            table.insert(t, v.code)
        end
    end
    if not next(t) then
        t = {'Load a game to see reactions'}
    end
    print_registry_section('Reaction names (for CustomReaction jobs)', t)
end

local function parse_commandline(args)
    local opts, action, unit_labors, reaction_names = {}, status, nil, nil
    local positionals = argparse.processArgsGetopt(args, {
            {'a', 'add', handler=function() action = boost_and_watch end},
            {'d', 'delete', handler=function() action = remove_watch end},
            {'h', 'help', handler=function() opts.help = true end},
            {'j', 'jobs', handler=function() action = print_current_jobs end},
            {'l', 'haul-labor', hasArg=true,
             handler=function(arg) unit_labors = argparse.stringList(arg) end},
            {'n', 'reaction-name', hasArg=true,
             handler=function(arg)
                reaction_names = argparse.stringList(arg) end},
            {'q', 'quiet', handler=function() opts.quiet = true end},
            {'r', 'registry', handler=function() action = print_registry end},
        })

    if positionals[1] == 'help' then opts.help = true end
    if opts.help then return opts end

    -- expand defaults, if requested
    for i,job_type_name in ipairs(positionals) do
        if not job_type_name:lower():find('^defaults?') then
            goto continue
        end
        table.remove(positionals, i)
        unit_labors = unit_labors or {}
        for _,ul in ipairs(DEFAULT_HAUL_LABORS) do
            table.insert(unit_labors, ul)
        end
        reaction_names = reaction_names or {}
        for _,rn in ipairs(DEFAULT_REACTION_NAMES) do
            table.insert(reaction_names, rn)
        end
        for _,jt in ipairs(DEFAULT_JOB_TYPES) do
            table.insert(positionals, jt)
        end
        break
        ::continue::
    end

    -- validate any specified hauler types and convert the list to ids
    if unit_labors then
        local ul_ids = nil
        for _,ulabor in ipairs(unit_labors) do
            ulabor = 'HAUL_'..ulabor:upper()
            if not df.unit_labor[ulabor] then
                dfhack.printerr(('Ignoring unknown unit labor: "%s". Run' ..
                    ' "prioritize -h" for a list of valid hauling labors.')
                    :format(ulabor))
            else
                ul_ids = ul_ids or {}
                table.insert(ul_ids, df.unit_labor[ulabor])
            end
        end
        unit_labors = ul_ids
    end

    -- validate any specified reaction names
    if reaction_names then
        local rns = nil
        for _,v in ipairs(reaction_names) do
            local found = false
            for _,r in ipairs(get_reactions()) do
                if r.code == v then
                    found = true
                    break
                end
            end
            if not found then
                dfhack.printerr(('Ignoring unknown reaction name: "%s". Run' ..
                    ' "prioritize -r" for a list of valid reaction names.')
                    :format(v))
            else
                rns = rns or {}
                table.insert(rns, v)
            end
        end
        reaction_names = rns
    end

    -- validate the specified job types and create matchers
    local job_matchers = {}
    for _,job_type_name in ipairs(positionals) do
        local job_type = df.job_type[job_type_name]
        if not job_type then
            dfhack.printerr(('Ignoring unknown job type: "%s". Run' ..
                ' "prioritize -r" for a list of valid job types.')
                :format(job_type_name))
        else
            local job_matcher = make_job_matcher(
                    job_type == df.job_type.StoreItemInStockpile and
                        unit_labors or nil,
                    job_type == df.job_type.CustomReaction and
                        reaction_names or nil)
            job_matchers[job_type] = job_matcher
        end
    end
    opts.job_matchers = job_matchers

    if action == status and next(job_matchers) then
        action = boost
    end
    opts.action = action

    return opts
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end
    local persisted_data = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    -- convert the string keys back into enum values
    g_watched_job_matchers = {}
    for k,v in pairs(persisted_data) do
        -- very old saves may still have numbers in the persisted table
        if type(k) ~= 'number' then
            k = tonumber(k)
        end
        if k then
            g_watched_job_matchers[k] = v
        end
    end
    update_handlers()
end

if dfhack.internal.IN_TEST then
    unit_test_hooks = {
        clear_watched_job_matchers=clear_watched_job_matchers,
        on_new_job=on_new_job,
        status=status,
        boost=boost,
        boost_and_watch=boost_and_watch,
        remove_watch=remove_watch,
        print_current_jobs=print_current_jobs,
        print_registry=print_registry,
        parse_commandline=parse_commandline,
    }
end

--------------------------------
-- EnRouteOverlay
--

--- Return the selected active construction or destruction job
local function getSelectedActiveBuildingJob()
    -- This is not relying on dfhack.gui.getSelectedJob() because we don't want
    -- the job of a selected or followed unit, only of a selected building
    local building = dfhack.gui.getSelectedBuilding(true)
    if not building then
        return nil
    end

    -- Find if the building is being constructed
    for _, job in ipairs(building.jobs) do
        if not job.flags.suspend and (job.job_type == df.job_type.ConstructBuilding or job.job_type == df.job_type.ConstructBuilding) then
            return job
        end
    end

    return nil
end


local function is_visible()
    return getSelectedActiveBuildingJob() ~= nil
end

EnRouteOverlay = defclass(EnRouteOverlay, overlay.OverlayWidget)
EnRouteOverlay.ATTRS{
    desc='Adds a panel to unbuilt buildings indicating whether a dwarf is on their way to build.',
    default_pos={x=-40, y=26},
    default_enabled=true,
    viewscreens='dwarfmode/ViewSheets/BUILDING',
    frame={w=57, h=5},
    frame_style=gui.FRAME_MEDIUM,
    frame_background=gui.CLEAR_PEN,
    visible=is_visible,
}

function EnRouteOverlay:init()
    self:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text={
                'Job taken by:',
                {gap=1, text=self:callback('get_builder_name'), pen=self:callback('get_builder_name_pen')}
            },
            on_click=self:callback('zoom_to_builder'),
        },
        widgets.ToggleHotkeyLabel{
            view_id='do_now',
            frame={t=2, l=0},
            label='Make top priority:',
            key='CUSTOM_CTRL_T',
            on_change=function(val)
                local job = getSelectedActiveBuildingJob()
                if not job then return end
                job.flags.do_now = val
            end,
        },
    }
end

function EnRouteOverlay:get_builder_name()
    if not self.builder then return 'N/A' end
    return dfhack.units.getReadableName(self.builder, true)
end

function EnRouteOverlay:get_builder_name_pen()
    if not self.builder then return COLOR_DARKGRAY end
    return COLOR_GREEN
end

function EnRouteOverlay:zoom_to_builder()
    local job = getSelectedActiveBuildingJob()
    if not job then return end
    local builder = dfhack.job.getWorker(job)
    if builder then
        dfhack.gui.revealInDwarfmodeMap(xyz2pos(dfhack.units.getPosition(builder)), true, true)
    end
end

function EnRouteOverlay:render(dc)
    local job = getSelectedActiveBuildingJob()
    self.builder = dfhack.job.getWorker(job)
    self.subviews.do_now:setOption(job.flags.do_now)
    EnRouteOverlay.super.render(self, dc)
    self.builder = nil
end

OVERLAY_WIDGETS = {enroute=EnRouteOverlay}

if dfhack_flags.module then
    return
end

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    dfhack.printerr('prioritize needs a loaded fortress map to work')
    return
end

--------------------------------
-- main
--

local args = {...}

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        args = {'-aq', 'defaults'}
    else
        clear_watched_job_matchers()
        persist_state()
        return
    end
end

local opts = parse_commandline(args)
if opts.help then print(dfhack.script_help()) return end
opts.action(opts.job_matchers, opts)
persist_state()
