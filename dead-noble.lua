-- Repair or replace a fortress's dead/missing land holder (baron/count/duke).
--[====[

dead-noble
==========
Diagnose and fix a fortress that has lost its baron, count, or duke and
can no longer receive a replacement.

See dead-noble.rst for full documentation.

]====]

local argparse = require('argparse')

local world = df.global.world
local plotinfo = df.global.plotinfo
local utils = require('utils')

local function qerr(fmt, ...)
    qerror(fmt:format(...))
end

local function civ()
    return df.historical_entity.find(plotinfo.civ_id)
        or qerr('cannot resolve parent civ %d', plotinfo.civ_id)
end

local function position_def(entity, position_id)
    for _, def in ipairs(entity.positions.own) do
        if def.id == position_id then return def end
    end
end

local function def_for(entity, code)
    for _, def in ipairs(entity.positions.own) do
        if def.code == code then return def end
    end
end

local function find_assignment(entity, id)
    for _, a in ipairs(entity.positions.assignments) do
        if a.id == id then return a end
    end
end

local function site_link_to(entity, site_id)
    for _, link in ipairs(entity.site_links) do
        if link.target == site_id then return link end
    end
end

local function hf_of(hfid)
    return hfid ~= -1 and df.historical_figure.find(hfid) or nil
end

local function site_landmass(site)
    if not site then return nil end
    local col = world.world_data.region_map[site.pos.x]
    return col and col:_displace(site.pos.y).landmass_id or nil
end

local function hf_landmass(wb)
    if wb.abs_smm_x == -1 or wb.abs_smm_y == -1 then return nil end
    local col = world.world_data.region_map[wb.abs_smm_x // 0x30]
    return col and col:_displace(wb.abs_smm_y // 0x30).landmass_id or nil
end

local function hf_desc(hf)
    if not hf then return '<missing hf>' end
    local name = dfhack.df2utf(dfhack.translation.translateName(hf.name, true))
    local state = hf.died_year ~= -1 and ('DEAD ' .. hf.died_year) or 'alive'
    local site = 'site?'
    local wb = hf.info and hf.info.whereabouts or nil
    if wb then
        site = 'site ' .. tostring(wb.site_id)
        local lm = hf_landmass(wb)
        if lm then
            site = site .. ', landmass ' .. tostring(lm)
        end
    end
    return ('%s (hf %d, %s, %s)'):format(name, hf.id, state, site)
end

-- land-holder assignments the civ associates with our site.
-- strict=false lists every land-holder assignment (diagnostics);
-- strict=true keeps only those actually tied to this site: the
-- assignment our site link points at, plus any with st_id == our site.
local function site_land_holder_assignments(entity, strict)
    local out = {}
    local link = site_link_to(entity, plotinfo.site_id)
    local linked_id = link and link.position_profile_id or -1
    -- site links pointing at each assignment id
    local link_sites = {}
    for _, l in ipairs(entity.site_links) do
        if l.position_profile_id ~= -1 then
            link_sites[l.position_profile_id] =
                link_sites[l.position_profile_id] or {}
            table.insert(link_sites[l.position_profile_id], l.target)
        end
    end
    for _, a in ipairs(entity.positions.assignments) do
        local def = position_def(entity, a.position_id)
        if def and def.land_holder > 0 then
            local ours = a.st_id == plotinfo.site_id or a.id == linked_id
            if not ours and link_sites[a.id] then
                for _, sid in ipairs(link_sites[a.id]) do
                    if sid == plotinfo.site_id then ours = true break end
                end
            end
            if not strict or ours then
                table.insert(out, {
                    assignment = a, def = def,
                    ours = ours and true or false,
                    sites = link_sites[a.id],
                })
            end
        end
    end
    table.sort(out, function(x, y)
        return x.def.land_holder < y.def.land_holder
    end)
    return out, linked_id
end

local function in_vector(vec, item)
    for _, v in ipairs(vec) do
        if v == item then return true end
    end
    return false
end

local function vec_desc(vec, item)
    return in_vector(vec, item) and 'yes' or 'no'
end

local function holder_is_dead(hf)
    return hf == nil or hf.died_year ~= -1
end

local function holder_off_site(hf)
    return hf and hf.info and hf.info.whereabouts
        and hf.info.whereabouts.site_id ~= plotinfo.site_id
end

local function rd_i32(obj, off)
    local _, a = df.sizeof(obj)
    return df.reinterpret_cast('int32_t', a + off).value
end

local function nemesis_of_hfid(hfid)
    for _, n in ipairs(world.nemesis.all) do
        if n.figure and n.figure.id == hfid then return n end
    end
end

-- emulate FUN_14147d730's gate chain for one nemesis, printing each verdict
local function trace_sweep(nem, hf)
    local function gate(ok, name)
        print(('  [%s] %s'):format(ok and 'PASS' or 'FAIL', name))
        return ok
    end
    if not gate(hf.died_year == -1,
               ('figure+0x30 (died_year?) == -1 [=%d]'):format(rd_i32(hf, 0x30)))
        then return end
    if not gate(nem.group_leader_id == -1, 'group_leader_id == -1') then return end
    local uok = nem.unit == nil or ((nem.unit.flags1.whole >> 31) & 1) == 0
    if not gate(uok, 'unit == NULL or unit.flags1 bit31 clear') then return end
    -- entity-link scan: POSITION link -> entity -> assignments[assignment_id]
    -- native quirk: RSP+0x70 (dest's st_id source) is the LAST resolved link's
    -- assignment, while RSP+0x38/0x48 (fallback + army bookkeeping) is the
    -- MIN-precedence winner.
    local assignment, ent, def          -- min-precedence winner
    local last_asg, last_ent, last_def  -- last resolved link
    local best_prec = 30001
    for _, l in ipairs(hf.entity_links) do
        if l._type == df.histfig_entity_link_positionst and l.entity_id ~= -1 then
            local e = df.historical_entity.find(l.entity_id)
            local asg
            if e then
                for _, a2 in ipairs(e.positions.assignments) do
                    if a2.id == l.assignment_id then asg = a2 break end
                end
            end
            local d
            if asg then
                for _, p in ipairs(e.positions.own) do
                    if p.id == asg.position_id then d = p break end
                end
            end
            print(('  link: asg_id=%d ent=%s -> asg %s (%s) st_id=%s prec=%s%s'):
                format(l.assignment_id, tostring(l.entity_id),
                       asg and asg.id or 'UNRESOLVED',
                       d and d.code or '?',
                       asg and asg.st_id or '?',
                       d and d.precedence or '?',
                       asg and ' [last-wins candidate]' or ''))
            if asg then
                last_asg, last_ent, last_def = asg, e, d
                if d and d.precedence < best_prec then
                    best_prec = d.precedence
                    assignment, ent, def = asg, e, d
                end
            end
        end
    end
    if last_asg and last_asg ~= assignment then
        print(('  !! dest st_id read from LAST link (asg %s st_id=%s), ' ..
              'winner is asg %s'):
            format(last_asg.id, tostring(last_asg.st_id), assignment.id))
    end
    if not gate(assignment ~= nil,
                ('POSITION link resolved (asg=%s ent=%s prec=%d)'):format(
                    assignment and assignment.id or 'nil',
                    ent and ent.id or 'nil', best_prec)) then return end
    local wb = hf.info and hf.info.whereabouts
    if not gate(wb ~= nil, 'whereabouts present') then return end
    if not gate(wb.state ~= whereabouts_type.army_died and wb.state ~= whereabouts_type.army_survived,
                ('whereabouts.state %d not in {army_died,army_survived}'):format(wb.state))
        then return end
    if not gate(wb.abs_smm_x ~= -1, 'abs_smm_x set') then return end
    -- debugger-verified: land_holder>0 on the LAST resolved def skips
    -- unconditionally BEFORE destination resolution (def+0x2c8, jg -> tail)
    if not gate(last_def and last_def.land_holder <= 0,
                ('last def.land_holder %s <= 0 (unconditional skip)'):
                    format(last_def and last_def.land_holder))
        then return end
    -- destination: st_id is a site ID resolved by the sweep's get_site
    -- (verified live: st_id=1629 produced an army to site id 1629).
    local dest
    if last_asg.st_id ~= -1 then
        dest = df.world_site.find(last_asg.st_id)
        print(('  [dest] st_id path (asg %d st_id=%d) -> site %s'):
            format(last_asg.id, last_asg.st_id, dest and dest.id or 'nil'))
    elseif ent.type == df.historical_entity_type.Civilization then
        for _, l in ipairs(ent.site_links) do
            if l.flags.capital then dest = df.world_site.find(l.target) end
        end
        print(('  [dest] capital path -> site %s'):format(dest and dest.id or 'nil'))
    elseif ent.type == df.historical_entity_type.SiteGovernment
        or ent.type == df.historical_entity_type.Religion
        or ent.type == df.historical_entity_type.MilitaryUnit then
        for _, l in ipairs(ent.site_links) do
            if l.flags.residence then dest = df.world_site.find(l.target) end
        end
        print(('  [dest] residence path -> site %s'):format(dest and dest.id or 'nil'))
    else
        gate(false, ('winner entity type %s not in {0,1,5,7} -> skip'):
            format(tostring(ent.type)))
        return
    end
    if not gate(dest ~= nil, 'destination site resolved') then return end
    local lm_hf = hf_landmass(wb)
    local lm_dest = site_landmass(dest)
    gate(lm_hf ~= nil and lm_hf == lm_dest,
         ('landmass match %s == %s'):format(tostring(lm_hf), tostring(lm_dest)))
    local _, saddr = df.sizeof(dest)
    local g = dest.min_depth
    gate(g == 0, ('min_depth == 0 [=%d]'):format(g))
    local home = nil
    for _, l in ipairs(hf.site_links) do
        local t = l:getType()
        if (t == df.histfig_site_link_type.HOME_SITE_ABSTRACT_BUILDING or
        t == df.histfig_site_link_type.HOME_SITE_REALIZATION_BUILDING or
        t == df.histfig_site_link_type.LAIR or
        t == df.histfig_site_link_type.HOME_SITE_REALIZATION_SUL or
        t == df.histfig_site_link_type.HOME_SITE_SAVED_CIVZONE)
        and l.site ~= -1 then home = l.site break end
    end
    if not home then home = wb.site_id end
    if not gate(home ~= dest.id,
                ('not already home: home %d != dest %d'):format(home, dest.id))
        then return end
    for _, l in ipairs(hf.entity_links) do
        local t = l:getType()
        if (t == df.histfig_entity_link_type.SLAVE or t == df.histfig_entity_link_type.PRISONER) and l.link_strength ~= 0 then
            gate(false, ('PRISONER/SLAVE link strength %d'):format(l.link_strength))
            return
        end
    end
    for _, l in ipairs(hf.histfig_links) do
        if l._type == df.histfig_hf_link_type.IMPRISONER and l.link_strength ~= 0 then
            gate(false, 'IMPRISONER link')
            return
        end
    end
    print('  [OK] all gates pass -> native sweep SHOULD create MOVE_TO_SITE')
end

-- which world.nemesis.* vector is at world+0x13cb8 (the sweep's iterate)?
local function cmd_nemvecs()
    local _, waddr = df.sizeof(world)
    for _, name in ipairs{'all', 'independent_actor', 'civilized_actor',
                          'plotter_actor', 'new_plotter_actor',
                          'artist_actor', 'poet_actor', 'bard_actor',
                          'dancer_actor', 'scholar_actor', 'hero_actor',
                          'underbelly_actor', 'religious_actor',
                          'merchant_actor', 'order_load'} do
        local ok, a = pcall(function()
            local _, x = df.sizeof(world.nemesis:_field(name))
            return x
        end)
        if ok and a then
            print(('  %-22s +0x%x %s'):format(name, a - waddr,
                  (a - waddr) == 0x13cb8 and '<== sweep iterates THIS' or ''))
        end
    end
end

local function cmd_trace()
    local entity = civ()
    -- the native call needs cur_season_tick%120==50 AND the region_logic
    -- frame counter (every 144 calls) to coincide -> fires ~every 120-720 ticks
    print(('cur_season_tick %d (%%120 = %d, needs 50)'):
        format(df.global.cur_season_tick, df.global.cur_season_tick % 120))
    local rows = site_land_holder_assignments(entity, true)
    for _, row in ipairs(rows) do
        local hf = hf_of(row.assignment.histfig)
        if not hf then
            print(('assignment %d: no living holder'):format(row.assignment.id))
        else
            local nem = nemesis_of_hfid(hf.id)
            print(('assignment %d holder %s nemesis %s'):
                format(row.assignment.id, hf.id, nem and nem.id or 'nil'))
            if nem then trace_sweep(nem, hf) end
        end
    end
end

local function cmd_status()
    local entity = civ()
    local rows, linked_id = site_land_holder_assignments(entity, false)
    print(('civ %d (%s), site %d, site-link position_profile_id %d'):
        format(entity.id,
               dfhack.df2utf(dfhack.translation.translateName(entity.name, true)),
               plotinfo.site_id, linked_id))
    if #rows == 0 then
        print('no land-holder assignments found for this site')
        -- still show defs in case none were ever created
        for _, def in ipairs(entity.positions.own) do
            if def.land_holder > 0 then
                print(('  def %d %s land_holder=%d (no assignment)'):
                    format(def.id, def.code, def.land_holder))
            end
        end
        return
    end
    local fort_site = df.world_site.find(plotinfo.site_id)
    local fort_lm = site_landmass(fort_site)
    for _, row in ipairs(rows) do
        local a, def = row.assignment, row.def
        local cur = hf_of(a.histfig)
        local last = hf_of(a.histfig2)
        print(('assignment %d%s: %s (def %d, land_holder %d, st_id %d, flags {%s})'):
            format(a.id, row.ours and ' [THIS SITE]' or '', def.code,
                   def.id, def.land_holder, a.st_id,
                   a.flags.active and 'active' or 'INACTIVE'))
        if row.sites then
            print(('  holds land at sites: %s'):
                format(table.concat(row.sites, ' ')))
        end
        print(('  holder %d: %s'):format(a.histfig, hf_desc(cur)))
        if cur and cur.died_year == -1 and holder_off_site(cur) then
            local lm = hf_landmass(cur.info.whereabouts)
            if lm and fort_lm and lm ~= fort_lm then
                print('  !! holder is on a different landmass; the native ' ..
                      'succession-traveler army cannot bring them home')
            end
        end
        print(('  last_holder %d: %s'):format(a.histfig2, hf_desc(last)))
        if a.id == linked_id and cur then
            -- does the holder actually carry the position link?
            local has_link = false
            for _, l in ipairs(cur.entity_links) do
                if df.histfig_entity_link_positionst:is_instance(l)
                    and l.assignment_id == a.id
                then
                    has_link = true
                end
            end
            print(('  holder has POSITION link to this assignment: %s'):
                format(tostring(has_link)))
            for _, l in ipairs(cur.site_links) do
                if l.site ~= -1 then
                    print(('  holder site link: %s -> site %d'):
                        format(tostring(l._type), l.site))
                end
            end
        end
        print(('  caches: evaluate=%s succession=%s appointable=%s elected=%s claimable=%s'):
            format(vec_desc(entity.positions.possible_evaluate, a),
                   vec_desc(entity.positions.possible_succession, a),
                   vec_desc(entity.positions.possible_appointable, a),
                   vec_desc(entity.positions.possible_elected, a),
                   vec_desc(entity.positions.possible_claimable, a)))
    end
    local f = entity.flags
    print(('entity flags: eval_activity=%s possible_evaluate=%s succession=%s appointable=%s elected=%s nems_check=%s'):
        format(tostring(f.evaluate_position_profile_activity),
               tostring(f.possible_evaluate_position_profile),
               tostring(f.possible_succession_position_profile),
               tostring(f.possible_appointable_position_profile),
               tostring(f.possible_elected_position_profile),
               tostring(f.make_nems_check_positions)))

    -- which sites' civ links point at which assignments; flags on ours
    print('site links with land-holder pointers:')
    local linkflag_names = {
        'land_for_holding', 'central_holding_land', 'land_holder_residence',
        'residence', 'local_market',
    }
    for _, link in ipairs(entity.site_links) do
        if link.position_profile_id ~= -1 or link.flags.land_for_holding then
            local flagstr = {}
            for _, fn in ipairs(linkflag_names) do
                if link.flags[fn] then table.insert(flagstr, fn) end
            end
            local site = df.world_site.find(link.target)
            local sname = site and dfhack.df2utf(dfhack.translation.translateName(site.name, true)) or '?'
            print(('  site %d (%s) -> assignment %d [%s] type %s%s'):
                format(link.target, sname, link.position_profile_id,
                       table.concat(flagstr, ' '), tostring(link.type),
                       link.target == plotinfo.site_id and '  <== THIS SITE' or ''))
        end
    end
    -- the fortress entity's own residence link
    local gov = df.historical_entity.find(plotinfo.group_id)
    if gov then
        for _, link in ipairs(gov.site_links) do
            if link.flags.residence then
                print(('fortress gov RESIDENCE link: site %d, position_profile_id %d'):
                    format(link.target, link.position_profile_id))
            end
        end
    end
end

-- erase `item` from a pointer vector, returning success
local function vec_erase(vec, item)
    for i, v in ipairs(vec) do
        if v == item then vec:erase(i) return true end
    end
    return false
end

-- remove `assignment` from each responsibility slot its def claims
local function remove_from_responsibility_caches(entity, def, assignment)
    for resp, held in pairs(def.responsibilities) do
        if held then
            vec_erase(entity.assignments_by_type[resp], assignment)
        end
    end
end

local function add_to_responsibility_caches(entity, def, assignment)
    for resp, held in pairs(def.responsibilities) do
        if held then
            local vec = entity.assignments_by_type[resp]
            if not in_vector(vec, assignment) then vec:insert('#', assignment) end
        end
    end
end

-- queue a vacant assignment for re-evaluation (mirrors
-- history_figurest::remove_entity_position_link_by_index)
local function queue_vacancy(entity, assignment)
    if assignment.flags.active
        and not in_vector(entity.positions.possible_evaluate, assignment)
    then
        entity.positions.possible_evaluate:insert('#', assignment)
        entity.flags.possible_evaluate_position_profile = true
        world.flags.an_entity_has_possible_evaluate_position_profile = true
    end
    entity.flags.evaluate_position_profile_activity = true
    world.flags.an_entity_has_evaluate_position_profile_activity = true
end

local function new_remove_link_event(entity, hf, position_id)
    world.history.events:insert('#', {
        new = df.history_event_remove_hf_entity_linkst,
        id = df.global.hist_event_next_id,
        year = df.global.cur_year,
        seconds = df.global.cur_year_tick,
        civ = entity.id,
        histfig = hf.id,
        link_type = df.histfig_entity_link_type.POSITION,
        position_id = position_id,
    })
    df.global.hist_event_next_id = df.global.hist_event_next_id + 1

end

local function new_add_link_event(entity, hf, assignment)
    world.history.events:insert('#', {
        new = df.history_event_add_hf_entity_linkst,
        id = df.global.hist_event_next_id,
        year = df.global.cur_year,
        seconds = df.global.cur_year_tick,
        civ = entity.id,
        histfig = hf.id,
        link_type = df.histfig_entity_link_type.POSITION,
        position_id = assignment.id, -- native stores the assignment id here
    })
    df.global.hist_event_next_id = df.global.hist_event_next_id + 1
end

local function new_add_member_event(entity, hf)
    world.history.events:insert('#', {
        new = df.history_event_add_hf_entity_linkst,
        id = df.global.hist_event_next_id,
        year = df.global.cur_year,
        seconds = df.global.cur_year_tick,
        civ = entity.id,
        histfig = hf.id,
        link_type = df.histfig_entity_link_type.MEMBER,
        position_id = -1,
    })
    df.global.hist_event_next_id = df.global.hist_event_next_id + 1
end

local function new_change_state_event(hf, state, site_id, reason)
    local site = site_id ~= -1 and df.world_site.find(site_id) or nil
    local ev = df.history_event_change_hf_statest:new()
    ev.id = df.global.hist_event_next_id - 1
    ev.year = df.global.cur_year
    ev.seconds = df.global.cur_year_tick
    ev.hfid = hf.id
    ev.state = state
    ev.reason = reason or df.history_event_reason.none
    ev.site = site_id
    ev.region = -1
    ev.layer = -1
    if site then ev.region_pos:assign(site.pos) end
    world.history.events:insert('#', ev)
    df.global.hist_event_next_id = df.global.hist_event_next_id + 1
end

-- strip `hf`'s POSITION link for `assignment`, mirroring
-- history_figurest::remove_entity_position_link_by_index
local function strip_position_link(entity, hf, def, assignment)
    local start_year, link_strength
    for i = #hf.entity_links - 1, 0, -1 do
        local link = hf.entity_links[i]
        if df.histfig_entity_link_positionst:is_instance(link)
            and link.entity_id == entity.id
            and link.assignment_id == assignment.id
        then
            start_year = link.start_year
            link_strength = link.link_strength
            hf.entity_links:erase(i)
            link:delete()
        end
    end
    if start_year then
        hf.entity_links:insert('#', {
            new = df.histfig_entity_link_former_positionst,
            entity_id = entity.id,
            assignment_id = assignment.id,
            link_strength = link_strength or 100,
            start_year = start_year,
            end_year = df.global.cur_year,
        })
        new_remove_link_event(entity, hf, def.id)
    end
    remove_from_responsibility_caches(entity, def, assignment)
    assignment.histfig = -1 -- histfig2 (last holder) is kept for heirs
    queue_vacancy(entity, assignment)
end

-- vacancy cleanup when the dead hf record itself is gone
local function assignment_cleanup(entity, def, assignment)
    remove_from_responsibility_caches(entity, def, assignment)
    assignment.histfig = -1
    queue_vacancy(entity, assignment)
end

-- find the nemesis record for an hf, and report army/controller state
local function army_desc(a)
    local c = a.controller
    local goal = c and tostring(c.goal) or '?'
    return ('army %d pos(%d,%d) flags{%s} controller %s goal=%s site_id=%s')
        :format(a.id, a.pos.x, a.pos.y,
                a.flags.player and 'player' or '-',
                c and tostring(c.id) or 'none', goal,
                c and tostring(c.site_id) or '?')
end

-- native gate at world_site+0x348 == min_depth (FUN_14147d730 @0x14147e08c):
-- must be 0 for the sweep to send a noble there
local function probe_site_gate(site_id)
    local site = df.world_site.find(site_id)
    if not site then return end
    local gate = site.min_depth
    print(('  site %d (%s, type %s): min_depth = %d, raw min_depth=%d%s'):
        format(site_id,
               dfhack.df2utf(dfhack.translation.translateName(site.name)),
               tostring(site.type), gate, site.mined_hours,
               gate ~= 0 and ' -- nonzero BLOCKS native travel' or ''))
end

local function cmd_army()
    local entity = civ()
    local rows = site_land_holder_assignments(entity, true)
    if #rows == 0 then
        print('no land-holder assignment tied to this site')
        return
    end
    for _, row in ipairs(rows) do
        local a = row.assignment
        local hf = hf_of(a.histfig)
        if not hf then
            print(('assignment %d (%s): no living holder to track'):
                format(a.id, row.def.code))
            goto continue
        end
        print(('assignment %d (%s): st_id=%d ab_id=%d squad_id=%d army_controller=%d'):
            format(a.id, row.def.code, a.st_id, a.ab_id, a.squad_id,
                   a.assigned_army_controller_id))
        print(('  holder %s'):format(hf_desc(hf)))
        local nem = nemesis_of_hfid(hf.id)
        if not nem then
            print('  no nemesis record for this hf')
            goto continue
        end
        print(('  nemesis %d (unit_id %d, group_leader %d, travel_link %d)'):
            format(nem.id, nem.unit_id, nem.group_leader_id,
                   nem.travel_link_nemid))
        -- unit gate: unit==NULL passes; a unit with flags1 bit31 skips
        if nem.unit then
            print(('  ! nemesis.unit -> unit %d flags1=0x%x bit31=%d%s'):
                format(nem.unit.id, nem.unit.flags1.whole,
                       nem.unit.flags1.whole >> 31 & 1,
                       (nem.unit.flags1.whole >> 31 & 1) == 1
                       and ' -- native sweep SKIPS this nemesis' or ''))
        end
        -- duplicate nemesis records would confuse the sweep
        local nems = 0
        for _, n in ipairs(world.nemesis.all) do
            if n.figure and n.figure.id == hf.id then nems = nems + 1 end
        end
        if nems > 1 then
            print(('  ! %d nemesis records point at this hf'):format(nems))
        end
        -- is the nemesis in the civilized_actor sweep list?
        local in_sweep = false
        for _, n in ipairs(world.nemesis.civilized_actor) do
            if n == nem then in_sweep = true break end
        end
        print(('  in civilized_actor sweep: %s'):format(tostring(in_sweep)))
        -- native sweep gates (FUN_14147d730)
        local wb = hf.info and hf.info.whereabouts or nil
        if wb then
            print(('  whereabouts: state=%s site_id=%d abs_smm=(%d,%d)'):
                format(tostring(wb.state), wb.site_id,
                       wb.abs_smm_x, wb.abs_smm_y))
        else
            print('  whereabouts: <none> -- native sweep skips this hf')
        end
        for _, l in ipairs(hf.entity_links) do
            local t = l._type
            if t == df.histfig_entity_link_prisonerst
                or t == df.histfig_entity_link_slavest
            then
                print(('  ! %s link, link_strength=%d (blocks travel)'):
                    format(tostring(t), l.link_strength))
            end
        end
        for _, l in ipairs(hf.histfig_links) do
            if tostring(l._type):find('IMPRISONER') then
                print(('  ! IMPRISONER link, link_strength=%d (blocks travel)'):
                    format(l.link_strength))
            end
        end
        -- POSITION links: sweep resolves entity -> assignments[assignment_id]
        for _, l in ipairs(hf.entity_links) do
            if l._type == df.histfig_entity_link_positionst then
                local e = df.historical_entity.find(l.entity_id)
                print(('  POSITION link: entity=%d (%s) assignment_id=%d strength=%d'):
                    format(l.entity_id, e and tostring(e.type) or '?',
                           l.assignment_id, l.link_strength))
            end
        end
        -- HOME_SITE* site links (types 3-7): native treats the first as "home"
        for _, l in ipairs(hf.site_links) do
            local t = l:getType()
            if (t == df.histfig_site_link_type.HOME_SITE_ABSTRACT_BUILDING or
                t == df.histfig_site_link_type.HOME_SITE_REALIZATION_BUILDING or
                t == df.histfig_site_link_type.LAIR or
                t == df.histfig_site_link_type.HOME_SITE_REALIZATION_SUL or
                t == df.histfig_site_link_type.HOME_SITE_SAVED_CIVZONE)
            then
                print(('  home-site link: %s -> site %d'):
                    format(tostring(l._type), l.site))
            end
        end
        -- armies containing the nemesis
        local found = false
        for _, army in ipairs(world.armies.all) do
            for _, m in ipairs(army.members) do
                if m.nemesis_id == nem.id then
                    print('  member of ' .. army_desc(army))
                    found = true
                end
            end
        end
        if not found then print('  not in any army') end
        ::continue::
    end
    -- destination the native sweep would pick for a civ nemesis
    for _, l in ipairs(entity.site_links) do
        if l.flags.capital then
            print(('civ CAPITAL site link -> %d (army destination for civ nobles)')
                :format(l.target))
            probe_site_gate(l.target)
        end
    end
    probe_site_gate(plotinfo.site_id)
    -- any controller already headed for our site?
    for _, c in ipairs(world.army_controllers.all) do
        if c.site_id == plotinfo.site_id then
            print(('controller %d targets our site: goal=%s'):
                format(c.id, tostring(c.goal)))
        end
    end
    -- is the succession-traveler mechanism alive anywhere in the world?
    local goal_counts = {}
    for _, c in ipairs(world.army_controllers.all) do
        local g = tostring(c.goal)
        goal_counts[g] = (goal_counts[g] or 0) + 1
    end
    print('army_controller goals worldwide:')
    for g, n in pairs(goal_counts) do
        print(('  %s x%d'):format(g, n))
    end
    print(('civilized_actor nemeses: %d'):format(#world.nemesis.civilized_actor))
end

local function cmd_vacate(opts)
    local entity = civ()
    local rows = site_land_holder_assignments(entity, true)
    local touched = 0
    for _, row in ipairs(rows) do
        local a, def = row.assignment, row.def
        local hf = hf_of(a.histfig)
        local clear = false
        if a.histfig == -1 then
            -- already vacant; make sure it's queued
            queue_vacancy(entity, a)
            print(('assignment %d (%s): already vacant, re-queued'):
                format(a.id, def.code))
            touched = touched + 1
        elseif holder_is_dead(hf) then
            clear = true
        elseif opts.living and holder_off_site(hf) then
            clear = true
        end
        if clear then
            if hf then
                strip_position_link(entity, hf, def, a)
            else
                assignment_cleanup(entity, def, a)
            end
            print(('assignment %d (%s): cleared holder %d, queued for succession'):
                format(a.id, def.code, a.histfig2))
            touched = touched + 1
        end
    end
    if touched == 0 then
        print('nothing to vacate: no dead or absent land-holder assignments')
    else
        print(('%d assignment(s) queued; native succession will run on the '
               .. 'next entity tick'):format(touched))
    end
end

local function cmd_claim(opts)
    local entity = civ()
    local rows = site_land_holder_assignments(entity, true)
    local pushed = 0
    for _, row in ipairs(rows) do
        local a, def = row.assignment, row.def
        local hf = hf_of(a.histfig)
        if a.histfig ~= -1 and (holder_is_dead(hf)
                                or (opts.living and holder_off_site(hf))) then
            strip_position_link(entity, hf, def, a)
        end
        if a.histfig == -1 then
            if not in_vector(entity.positions.possible_claimable, a) then
                entity.positions.possible_claimable:insert('#', a)
            end
            entity.flags.make_nems_check_positions = true
            world.flags.an_entity_wants_to_mark_news_for_position_claim = true
            print(('assignment %d (%s): queued for claimant'):
                format(a.id, def.code))
            pushed = pushed + 1
        end
    end
    if pushed == 0 then
        print('no vacant land-holder assignments to claim')
    else
        print(('queued %d claim(s); a claimant should be generated and '
               .. 'travel to the fort'):format(pushed))
    end
end

-- Point the assignment's bound-site field (st_id, +0x2c) at our fort.
-- st_id is a SITE ID: the sweep resolves it through get_site and builds a
-- MOVE_TO_SITE army for the holder. NOTE: the sweep's land_holder>0 gate
-- (def+0x2c8, jg -> tail) fires BEFORE this read -- the native path only
-- works if that check is neutralized (debugger NOP test) or the position
-- is not a land-holder. If a created army heads for the wrong site, the
-- live controller can be retargeted: set site_id/pos_x/pos_y directly
-- (verified live: a retargeted army delivered the holder correctly).
local function cmd_recall(opts)
    local entity = civ()
    local rows = site_land_holder_assignments(entity, true)
    if #rows == 0 then
        print('no land-holder assignment tied to this site')
        return
    end
    for _, row in ipairs(rows) do
        local a, def = row.assignment, row.def
        local hf = hf_of(a.histfig)
        if not hf or holder_is_dead(hf) then
            print(('assignment %d (%s): no living holder to recall'):
                format(a.id, def.code))
        elseif holder_off_site(hf) == false then
            print(('assignment %d (%s): holder already at this site'):
                format(a.id, def.code))
        elseif plotinfo.site_id == a.st_id then
            print(('assignment %d (%s): st_id already points here; '
                   .. 'sweep should act next tick'):format(a.id, def.code))
        else
            local old = a.st_id
            a.st_id = plotinfo.site_id
            print(('assignment %d (%s): st_id %d -> %d; '
                   .. 'native sweep should create a MOVE_TO_SITE army'):
                format(a.id, def.code, old, a.st_id))
        end
    end
end

-- a recalled holder's MOVE_TO_SITE army delivers them as a visitor:
-- materialized at the fort but still flagged guest and uninstalled.
-- unitst::make_own (via dfhack.units.makeown) is the native routine the
-- petition-for-citizenship flow uses -- it grants the MEMBER link to the
-- fort's site government, updates the entity's member lists, switches
-- whereabouts to settler, and clears guest/visitor flags. Verified live:
-- after makeown the holder appears on the nobles screen and citizens
-- list. st_id is then reset to -1 (the settled-state convention).
local function cmd_settle(opts)
    local entity = civ()
    local rows = site_land_holder_assignments(entity, true)
    if #rows == 0 then
        print('no land-holder assignment tied to this site')
        return
    end
    for _, row in ipairs(rows) do
        local a, def = row.assignment, row.def
        local hf = hf_of(a.histfig)
        local wb = hf and hf.info and hf.info.whereabouts
        local nem = hf and nemesis_of_hfid(hf.id)
        local unit = nem and nem.unit
        if not hf then
            print(('assignment %d (%s): no holder to settle'):
                format(a.id, def.code))
        elseif not wb or wb.site_id ~= plotinfo.site_id then
            print(('assignment %d (%s): holder not at this site (site %d)'):
                format(a.id, def.code, wb and wb.site_id or -1))
        elseif not unit then
            print(('assignment %d (%s): holder unit not materialized yet'):
                format(a.id, def.code))
        elseif not (unit.flags3.guest or unit.flags2.visitor
                    or unit.flags2.visitor_uninvited
                    or wb.state ~= df.whereabouts_type.settler)
        then
            print(('assignment %d (%s): holder already settled'):
                format(a.id, def.code))
        else
            -- unitst::make_own is history-silent: emit the link/state
            -- events a natural settle produces so legends stay complete
            local gov = df.historical_entity.find(plotinfo.group_id)
            local had_member = false
            for _, l in ipairs(hf.entity_links) do
                if l:getType() == df.histfig_entity_link_type.MEMBER
                    and l.entity_id == plotinfo.group_id then
                    had_member = true break
                end
            end
            dfhack.units.makeown(unit)
            local has_member = false
            for _, l in ipairs(hf.entity_links) do
                if l:getType() == df.histfig_entity_link_type.MEMBER
                    and l.entity_id == plotinfo.group_id then
                    has_member = true break
                end
            end
            if gov and not had_member and has_member then
                new_add_member_event(gov, hf)
            end
            new_change_state_event(hf, df.whereabouts_type.settler,
                plotinfo.site_id, df.history_event_reason.become_citizen)
            if a.st_id == plotinfo.site_id then a.st_id = -1 end
            local who = dfhack.df2utf(
                dfhack.translation.translateName(hf.name, true))
            local what = def.name[0] ~= '' and def.name[0]
                         or def.code:lower()
            dfhack.gui.showAnnouncement(
                ('%s has arrived to take the position of %s.'):
                    format(who, what), COLOR_CYAN, true)
            print(('assignment %d (%s): settled holder hf %d at site %d '
                   .. '(st_id now %d)'):
                format(a.id, def.code, hf.id, plotinfo.site_id, a.st_id))
        end
    end
end

-- Emulated MOVE_TO_SITE army creation, replicating the tail of the
-- civilized-actor sweep (FUN_14147d730) for a single nemesis -- the
-- patch-free alternative to bypassing the land_holder gate.  Per the
-- decompile the sweep: allocates an army_controller, fills the
-- goal_move_to_site data, allocates an army, add_nemesis, places it at
-- the nemesis's smm position.  Uncertain fields (tracking/sneak/odor
-- ratings, path vectors, travel_rate) are left at benign defaults; the
-- native army-advance machinery drives the march itself.
local function cmd_fetch(opts)
    local entity = civ()
    local rows = site_land_holder_assignments(entity, true)
    if #rows == 0 then
        print('no land-holder assignment tied to this site')
        return
    end
    local site = df.world_site.find(plotinfo.site_id)
    if not site then qerr('cannot find our site %d', plotinfo.site_id) end
    -- smm coords = site rect (embark tiles) * 3, verified live
    local dst_x = math.floor((site.global_min_x + site.global_max_x) / 2) * 3
    local dst_y = math.floor((site.global_min_y + site.global_max_y) / 2) * 3
    for _, row in ipairs(rows) do
        local a, def = row.assignment, row.def
        local hf = hf_of(a.histfig)
        local wb = hf and hf.info and hf.info.whereabouts
        local nem = hf and nemesis_of_hfid(hf.id)
        if not hf or holder_is_dead(hf) then
            print(('assignment %d (%s): no living holder to fetch'):
                format(a.id, def.code))
        elseif not wb then
            print(('assignment %d (%s): holder has no whereabouts'):
                format(a.id, def.code))
        elseif wb.site_id == plotinfo.site_id then
            print(('assignment %d (%s): holder already at this site'):
                format(a.id, def.code))
        elseif wb.state == df.whereabouts_type.army_died
            or wb.state == df.whereabouts_type.army_survived then
            print(('assignment %d (%s): holder already traveling '
                   .. '(army %d)'):format(a.id, def.code, wb.army_id))
        elseif not nem then
            print(('assignment %d (%s): no nemesis record'):
                format(a.id, def.code))
        else
            -- mirror the native landmass gate: armies cannot pathfind
            -- across water, so a cross-landmass fetch would leave the
            -- holder stranded in-army forever (native blocks this too)
            local lm_hf, lm_dst = hf_landmass(wb), site_landmass(site)
            if lm_hf ~= nil and lm_dst ~= nil and lm_hf ~= lm_dst
                and not opts.force
            then
                print(('assignment %d (%s): holder on landmass %s, '
                       .. 'fort on %s -- armies cannot cross water; '
                       .. 'use --force to try anyway or install locally'):
                    format(a.id, def.code,
                           tostring(lm_hf), tostring(lm_dst)))
                goto continue
            end
            -- start at his smm pos; if abstract (-1), start at his site
            local src_x, src_y = wb.abs_smm_x, wb.abs_smm_y
            if (src_x == -1 or src_y == -1) and wb.site_id ~= -1 then
                local s = df.world_site.find(wb.site_id)
                if s then
                    src_x = math.floor(
                        (s.global_min_x + s.global_max_x) / 2) * 3
                    src_y = math.floor(
                        (s.global_min_y + s.global_max_y) / 2) * 3
                end
            end
            if src_x == -1 or src_y == -1 then
                print(('assignment %d (%s): cannot place army '
                       .. '(no smm position)'):format(a.id, def.code))
                goto continue
            end

            local c = df.army_controller:new()
            c.id = df.global.army_controller_next_id
            df.global.army_controller_next_id = c.id + 1
            c.entity_id = -1
            c.site_id = plotinfo.site_id
            c.subregion_id = -1
            c.pos_x = dst_x
            c.pos_y = dst_y
            c.year = df.global.cur_year
            c.year_tick = df.global.cur_season_tick
            c.parent_id = -1
            c.master_id = c.id
            c.master_hf = -1
            c.commander_hf = -1
            c.origin_task_holder_nemesis_id = -1
            c.origin_task_id = -1
            c.origin_plot_holder_nemesis_id = -1
            c.origin_plot_id = -1
            local g = df.army_controller_goal_move_to_sitest:new()
            g.goal_hfid = hf.id
            g.goal_srbid = -1
            g.flag.RETURNING_TO_CURRENT_HOME = true
            g.goal_ent_id = entity.id
            g.goal_epp_id = a.id
            g.goal_ab_id = -1
            g.reason = df.history_event_reason.none
            c.data.goal_move_to_site = g
            c.goal = df.army_controller_goal_type.MOVE_TO_SITE
            world.army_controllers.all:insert('#', c)

            local army = df.army:new()
            army.id = df.global.army_next_id
            df.global.army_next_id = army.id + 1
            army.pos:assign{x = src_x, y = src_y, z = 0}
            army.last_pos:assign{x = src_x, y = src_y, z = 0}
            army.controller_id = c.id
            army.controller = c
            army.travel_rate = 16
            army.item_type = df.item_type.NONE
            army.item_subtype = -1
            army.mat_type = -1
            army.mat_index = -1
            army.current_army_tracking_info_id = -1
            local m = df.army_nemesisst:new()
            m.nemesis_id = nem.id
            m.section_master_acid = -1
            m.section_index = -1
            army.members:insert('#', m)
            world.armies.all:insert('#', army)

            wb.state = df.whereabouts_type.army_died -- IN_ARMY
            wb.site_id = -1
            wb.army_id = army.id
            wb.abs_smm_x = -1
            wb.abs_smm_y = -1
            wb.subregion_id = -1
            wb.feature_layer_id = -1
            new_change_state_event(hf, df.whereabouts_type.army_died,
                -1, df.history_event_reason.none)

            -- pre-instate: grant the MEMBER link to the fort's site gov
            -- and insert the hf into its member lists NOW.  Verified
            -- live: the arrival-ingress machinery checks the hf's links
            -- at materialization time, so a holder with the link already
            -- written arrives as a citizen+officeholder with the native
            -- 'has returned' announcement, instead of a guest.
            local gov = df.historical_entity.find(plotinfo.group_id)
            if gov then
                local has_member = false
                for _, l in ipairs(hf.entity_links) do
                    if l:getType() == df.histfig_entity_link_type.MEMBER
                        and l.entity_id == gov.id then
                        has_member = true break
                    end
                end
                if not has_member then
                    hf.entity_links:insert('#', {
                        new = df.histfig_entity_link_memberst,
                        entity_id = gov.id,
                        link_strength = 100,
                    })
                    utils.insert_sorted(gov.histfig_ids, hf.id)
                    utils.insert_sorted(gov.hist_figures, hf, 'id')
                    if hf.nemesis_id >= 0 then
                        utils.insert_sorted(gov.nemesis_ids, hf.nemesis_id)
                    end
                    new_add_member_event(gov, hf)
                end
            end

            print(('assignment %d (%s): created army %d controller %d '
                   .. 'goal=MOVE_TO_SITE site %d, marching from (%d,%d) '
                   .. 'to (%d,%d); holder pre-instated as member'):
                format(a.id, def.code, army.id, c.id, plotinfo.site_id,
                       src_x, src_y, dst_x, dst_y))
        end
        ::continue::
    end
end

-- pick the land-holder assignment for this site's current rank:
-- prefer one that already exists (even dead-holder), then the def the
-- site link points at, then the lowest unfilled land-holder rank
local function choose_install_target(entity, opts)
    local rows, linked_id = site_land_holder_assignments(entity, true)
    if opts.position then
        local def = def_for(entity, opts.position)
        if not def then qerr('no position %s on this civ', opts.position) end
        if def.land_holder <= 0 then
            qerr('%s is not a land-holder position', opts.position)
        end
        for _, row in ipairs(rows) do
            if row.def == def then return row.def, row.assignment end
        end
        return def, nil
    end
    -- the assignment our site link names is THE one for this fort;
    -- otherwise the highest-tier site-tied assignment wins
    if linked_id ~= -1 then
        local a = find_assignment(entity, linked_id)
        if a then return position_def(entity, a.position_id), a end
    end
    if #rows > 0 then
        return rows[#rows].def, rows[#rows].assignment
    end
    -- never held: first (lowest) land-holder def
    local best
    for _, def in ipairs(entity.positions.own) do
        if def.land_holder > 0
            and (not best or def.land_holder < best.land_holder)
        then
            best = def
        end
    end
    if not best then qerr('this civ has no land-holder positions') end
    return best, nil
end

local function get_target_unit(opts)
    if opts.unit then
        return df.unit.find(opts.unit)
            or qerr('cannot find unit %d', opts.unit)
    end
    return dfhack.gui.getSelectedUnit()
        or qerr('no unit selected (use --unit ID)')
end

local function ensure_assignment(entity, def)
    -- reuse a vacant assignment for this def tied to our site if present
    for _, a in ipairs(entity.positions.assignments) do
        if a.position_id == def.id and a.histfig == -1
            and (a.st_id == plotinfo.site_id or a.st_id == -1)
        then
            return a, false
        end
    end
    local a = df.entity_position_assignment:new()
    a.id = entity.positions.next_assignment_id
    entity.positions.next_assignment_id = entity.positions.next_assignment_id + 1
    a.position_id = def.id
    a.st_id = -1 -- st_id is the recall-destination field; settled = -1
    a.flags.active = true
    entity.positions.assignments:insert('#', a)
    return a, true
end

local function cmd_install(opts)
    local entity = civ()
    local unit = get_target_unit(opts)
    local nemesis = dfhack.units.getNemesis(unit)
    if not nemesis or not nemesis.figure then
        qerr('selected unit has no historical figure/nemesis')
    end
    local hf = nemesis.figure

    local def, assignment = choose_install_target(entity, opts)

    -- clear any existing holder of the chosen assignment
    if assignment and assignment.histfig ~= -1 then
        local old = hf_of(assignment.histfig)
        if old then
            strip_position_link(entity, old, def, assignment)
        else
            assignment_cleanup(entity, def, assignment)
        end
    end
    assignment = assignment or ensure_assignment(entity, def)
    if assignment.histfig ~= -1 then
        assignment_cleanup(entity, def, assignment)
    end
    assignment.st_id = -1 -- holder is already local; no recall needed
    assignment.flags.active = true

    -- strip the candidate's existing position links on this civ, as
    -- assign_post_wg_entity_position_profile does before granting
    for i = #hf.entity_links - 1, 0, -1 do
        local link = hf.entity_links[i]
        if df.histfig_entity_link_positionst:is_instance(link)
            and link.entity_id == entity.id
        then
            local old_a = find_assignment(entity, link.assignment_id)
            local old_def = old_a and position_def(entity, old_a.position_id)
            if old_a and old_def then
                strip_position_link(entity, hf, old_def, old_a)
            else
                hf.entity_links:erase(i)
                link:delete()
            end
        end
    end

    -- grant: mirrors history_figurest::add_entity_position_link
    hf.entity_links:insert('#', {
        new = df.histfig_entity_link_positionst,
        entity_id = entity.id,
        assignment_id = assignment.id,
        link_strength = 100,
        start_year = df.global.cur_year,
    })
    assignment.histfig = hf.id
    assignment.histfig2 = hf.id
    add_to_responsibility_caches(entity, def, assignment)
    new_add_link_event(entity, hf, assignment)

    -- update the civ's site link to our fort, as ESTABLISH_LAND_HOLDER does
    local link = site_link_to(entity, plotinfo.site_id)
    if link then
        link.position_profile_id = assignment.id
        link.flags.land_for_holding = true
        link.flags.land_holder_residence = true
    end

    -- let the next entity tick refresh position activity natively
    entity.flags.evaluate_position_profile_activity = true
    world.flags.an_entity_has_evaluate_position_profile_activity = true

    local who = dfhack.df2utf(dfhack.translation.translateName(hf.name, true))
    local what = def.name[0] ~= '' and def.name[0] or def.code:lower()
    dfhack.gui.showAnnouncement(
        ('%s has been appointed to the position of %s.'):format(who, what),
        COLOR_CYAN, true)
    print(('installed %s as %s (assignment %d on civ %d)'):
        format(who, what, assignment.id, entity.id))
end

local function main(args)
    local opts = {}
    local positionals = argparse.processArgsGetopt(args, {
        {'h', 'help', handler = function() opts.help = true end},
        {nil, 'living', handler = function() opts.living = true end},
        {nil, 'force', handler = function() opts.force = true end},
        {nil, 'unit', hasArg = true,
         handler = function(v) opts.unit = tonumber(v) end},
        {nil, 'position', hasArg = true,
         handler = function(v) opts.position = v end},
    })
    if opts.help or #positionals ~= 1 then
        print(dfhack.script_help())
        return
    end
    if df.global.gamemode ~= df.game_mode.DWARF then
        qerr('only available in fortress mode')
    end
    local cmd = positionals[1]
    if cmd == 'status' then cmd_status()
    elseif cmd == 'army' then cmd_army()
    elseif cmd == 'vacate' then cmd_vacate(opts)
    elseif cmd == 'claim' then cmd_claim(opts)
    elseif cmd == 'recall' then cmd_recall(opts)
    elseif cmd == 'settle' then cmd_settle(opts)
    elseif cmd == 'fetch' then cmd_fetch(opts)
    elseif cmd == 'trace' then cmd_trace()
    elseif cmd == 'nemvecs' then cmd_nemvecs()
    elseif cmd == 'install' then cmd_install(opts)
    else qerr('unknown command %s', cmd) end
end

if not dfhack_flags.module then
    main({...})
end
