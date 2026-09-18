-- Citizens carry extra loose items when hauling goods.
--[====[

multihaul
=========

When a citizen picks up an item for a stockpile, they also grab up to
``max`` additional loose items of the same type within ``radius`` tiles --
both at the pickup site and along the way -- then drop everything off in
one trip. Not enabled by default; run ``multihaul enable`` or
``enable multihaul`` to turn it on.

Usage::

    multihaul enable|disable
    multihaul status
    multihaul max <n>        (default 4, max extra items per trip)
    multihaul radius <n>     (default 2, tiles around the pickup)
    multihaul weight <n>     (max combined weight of everything carried,
                             in DF mass units; default 0 = unlimited)
    multihaul weight auto    (derive the cap per dwarf from their
                             strength and body size)
    multihaul weight unlimited
    multihaul types same|all (default same; "all" also grabs items that
                             other haul jobs are taking to the same
                             destination, regardless of type)
    multihaul targets piles|all
                             (default piles; "all" also piggybacks loads
                             into minecarts, barrels, and bins)

]====]

--@ enable=true
--@ module=true

local repeatutil = require('repeat-util')

local GLOBAL_KEY = 'multihaul'
local TIMER_NAME = 'multihaul'

local POLL_FRAMES = 3

-- persisted state
enabled = enabled or false
s_max = s_max or 4
s_radius = s_radius or 2
s_weight = s_weight or 0
s_types_all = s_types_all or false
s_targets_all = s_targets_all or false

-- transient state
-- unit_id -> {
--     job_id=number, primary_id=number, extras={item_id -> item},
--     weight=number (weight of primary + container + extras),
--     pile=building        (stockpile destination), or
--     container=item       (vehicle/barrel/bin destination)
-- }
tracked = tracked or {}

function isEnabled()
    return enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, {
        enabled=enabled,
        s_max=s_max,
        s_radius=s_radius,
        s_weight=s_weight,
        s_types_all=s_types_all,
        s_targets_all=s_targets_all,
    })
end

local function load_state()
    local data = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    enabled = data.enabled or false
    s_max = data.s_max or 4
    s_radius = data.s_radius or 2
    s_weight = data.s_weight or 0
    s_types_all = data.s_types_all or false
    s_targets_all = data.s_targets_all or false
end

local function get_job_stockpile(job)
    for _,gr in ipairs(job.general_refs) do
        if df.general_ref_building_holderst:is_instance(gr) then
            local bld = gr:getBuilding()
            if bld and df.building_stockpilest:is_instance(bld) then
                return bld
            end
        end
    end
end

-- resolve the job's delivery destination and the item that anchors the
-- pickup. For piles and vehicles the anchor is the carried item; for
-- barrels/bins it is the item being stored, since the dwarf carries the
-- container to the goods.
local function get_job_dest(job)
    if job.job_type == df.job_type.StoreItemInStockpile then
        local pile = get_job_stockpile(job)
        if not pile then return end
        local anchor
        for _,ref in ipairs(job.items) do
            if ref.item and ref.item:isWheelbarrow() then
                -- the wheelbarrow already multi-hauls for this job
                return
            elseif ref.item and (ref.role == df.job_role_type.Hauled
                    or ref.role == df.job_role_type.Reagent) then
                anchor = anchor or ref.item
            end
        end
        if anchor then
            return {pile=pile, anchor=anchor}
        end
    elseif s_targets_all and #job.items > 1 then
        if job.job_type == df.job_type.StoreItemInVehicle then
            local load, vehicle
            for _,ref in ipairs(job.items) do
                if ref.role == df.job_role_type.TargetContainer then
                    vehicle = ref.item
                elseif ref.item and (ref.role == df.job_role_type.Hauled
                        or ref.role == df.job_role_type.Reagent) then
                    load = ref.item
                end
            end
            -- wheelbarrows only ever hold one item
            if load and vehicle and not vehicle:isWheelbarrow() then
                return {container=vehicle, anchor=load}
            end
        elseif job.job_type == df.job_type.StoreItemInBarrel
                or job.job_type == df.job_type.StoreItemInBin then
            local container, queued
            for _,ref in ipairs(job.items) do
                if ref.role == df.job_role_type.Hauled then
                    container = ref.item
                elseif ref.role == df.job_role_type.QueuedContainer then
                    queued = ref.item
                end
            end
            if container and queued then
                return {container=container, anchor=queued}
            end
        end
    end
end

local function near(a, b, radius)
    return a.z == b.z and math.abs(a.x - b.x) <= radius
        and math.abs(a.y - b.y) <= radius
end

-- the container (vehicle, barrel, bin, ...) an item is inside, or nil
local function contained_in(item)
    for _,ref in ipairs(item.general_refs) do
        if ref:getType() == df.general_ref_type.CONTAINED_IN_ITEM then
            return ref:getItem()
        end
    end
end

-- true if a real job claims the item. Our own piggybacked extras only
-- carry the in_job flag and never have a JOB specific_ref, so this
-- distinguishes the two.
local function real_job_claim(item)
    for _,sref in ipairs(item.specific_refs) do
        if sref.type == df.specific_ref_type.JOB and sref.data.job
                and df.isvalid(sref.data.job) == 'ref' then
            return true
        end
    end
    return false
end

-- item:getStockpile() reads a .stockpile field that only exists on some
-- item classes (tools, containers) and throws on others (cloth, bags)
local function stockpile_assigned(item)
    local ok, pile = pcall(function() return item:getStockpile() end)
    return ok and pile ~= nil
end

-- the item is already claimed by a job; true only if that job is also
-- delivering it to the given destination
local function claimed_for_dest(item, dest)
    if not item.flags.in_job then return false end
    for _,sref in ipairs(item.specific_refs) do
        if sref.type == df.specific_ref_type.JOB and sref.data.job
                and df.isvalid(sref.data.job) == 'ref' then
            local job = sref.data.job
            if job.job_type == df.job_type.StoreItemInStockpile
                    and dest.pile
                    and get_job_stockpile(job) == dest.pile then
                return true
            end
            if dest.container then
                local other = get_job_dest(job)
                if other and other.container == dest.container then
                    return true
                end
            end
        end
    end
    return false
end

local function extra_ok(cand, anchor, dest, origin, taken_weight, cap)
    local f = cand.flags
    if cand.id == anchor.id or not f.on_ground or f.in_inventory
            or f.in_building or f.forbid or f.owned or f.hostile
            or f.trader or f.spider_web or f.construction or f.encased
            or f.removed or f.garbage_collect or f.rotten or f.dump
            or f.melt or f.hidden or f.on_fire
            or not near(cand.pos, origin, s_radius)
            or contained_in(cand) then
        return false
    end
    if f.in_job then
        -- claimed item: only valid if a job is already taking it to our
        -- destination (lets one trip do several jobs' work)
        if not (s_types_all and claimed_for_dest(cand, dest)) then
            return false
        end
    else
        -- unclaimed items must match the anchor's type: we cannot verify
        -- that the destination accepts anything else
        if cand:getType() ~= anchor:getType()
                or stockpile_assigned(cand)
                or dfhack.buildings.findAtTile(
                    cand.pos.x, cand.pos.y, cand.pos.z) then
            return false
        end
    end
    if cap > 0 and cand.weight
            and taken_weight + cand.weight.whole > cap then
        return false
    end
    return true
end

local function held_by(unit, item)
    for _,e in ipairs(unit.inventory) do
        if e.item == item then return true end
    end
end

-- find the stockpile tile nearest to pos, or nil if pos is far from the pile
local function nearest_pile_tile(pile, pos, max_dist)
    if not pile or df.isvalid(pile) ~= 'ref' then return nil end
    local best, best_dist
    for x = pile.x1, pile.x2 do
        for y = pile.y1, pile.y2 do
            local d = math.abs(x - pos.x) + math.abs(y - pos.y)
                + 50 * math.abs(pile.z - pos.z)
            if (not best_dist or d < best_dist)
                    and dfhack.buildings.findAtTile(x, y, pile.z) == pile then
                best, best_dist = xyz2pos(x, y, pile.z), d
            end
        end
    end
    return (best_dist and best_dist <= max_dist) and best or nil
end

-- did the job's primary item actually reach the destination?
local function primary_delivered(t, primary)
    if t.pile then
        return primary and df.isvalid(primary) == 'ref'
            and dfhack.buildings.findAtTile(
                primary.pos.x, primary.pos.y, primary.pos.z) == t.pile
    end
    -- containers: a stored item can merge into a stack inside the container
    -- and be deleted, so a missing anchor counts as delivered
    if not primary or df.isvalid(primary) ~= 'ref' then return true end
    return contained_in(primary) == t.container
end

-- release all piggybacked items. If the job completed normally, land the
-- extras at the destination too: on the primary's pile tile (or the nearest
-- pile tile if the unit finished next to the pile, e.g. vehicle handoffs),
-- or inside the container. Otherwise drop them at the unit's feet.
local function release_all(unit_id)
    local t = tracked[unit_id]
    if not t then return end
    tracked[unit_id] = nil

    local unit = df.unit.find(unit_id)
    local drop_pos
    local container
    local primary = t.primary_id and df.item.find(t.primary_id)
    if t.pile then
        if primary_delivered(t, primary) then
            drop_pos = primary.pos
        elseif unit then
            drop_pos = nearest_pile_tile(t.pile, unit.pos, 4) or unit.pos
        end
    elseif t.container then
        if primary_delivered(t, primary)
                and df.isvalid(t.container) == 'ref' then
            container = t.container
        elseif unit then
            drop_pos = unit.pos
        end
    end
    for item_id, item in pairs(t.extras) do
        t.extras[item_id] = nil
        -- if a real job claimed the extra in the meantime its in_job flag
        -- is legitimate; leave it alone
        if df.isvalid(item) == 'ref' and not real_job_claim(item) then
            item.flags.in_job = false
            if container then
                -- insert items the unit still holds, and any the engine
                -- dropped at the unit's feet during the handoff
                if unit and (held_by(unit, item)
                        or near(item.pos, unit.pos, 4)) then
                    if not dfhack.items.moveToContainer(item, container) then
                        dfhack.items.moveToGround(item, unit.pos)
                    end
                end
                -- otherwise it was dropped mid-route: leave it there
            elseif unit and drop_pos then
                if held_by(unit, item) then
                    dfhack.items.moveToGround(item, drop_pos)
                elseif t.pile and item.flags.on_ground
                        and near(item.pos, drop_pos, 4) then
                    -- dropped by the engine at the destination
                    dfhack.items.moveToGround(item, drop_pos)
                end
            end
        end
    end
end

local function attached_count(t)
    local n = 0
    for _ in pairs(t.extras) do n = n + 1 end
    return n
end

local function item_weight(item)
    return (item and item.weight) and item.weight.whole or 0
end

-- 'weight auto': derive a per-unit carry cap from strength scaled by body
-- size (a child or small race carries less). A typical dwarf (~1200
-- strength) can manage ~900 units -- roughly three boulders of load.
local AUTO_CAP_FACTOR = 0.75
local AUTO_CAP_FALLBACK = 900

local function unit_carry_cap(unit)
    local ok, cap = pcall(function()
        local attrs = unit.body.physical_attrs
        local str = attrs.STRENGTH and attrs.STRENGTH.value or 0
        local base = unit.body.size_info.size_base
        local cur = unit.body.size_info.size_cur
        local ratio = (base and base > 0) and (cur / base) or 1
        ratio = math.max(0.25, math.min(ratio, 1.5))
        return math.floor(str * ratio * AUTO_CAP_FACTOR)
    end)
    return (ok and cap > 0) and cap or AUTO_CAP_FALLBACK
end

-- 0 = unlimited, 'auto' = per-unit, >0 = fixed cap
local function effective_weight_cap(unit)
    if s_weight == 'auto' then return unit_carry_cap(unit) end
    return s_weight
end

-- attach extras near origin until the count and weight caps are reached,
-- nearest first
local function grab_extras(t, unit, dest, anchor, origin)
    local cands = {}
    for _,cand in ipairs(df.global.world.items.other[
            df.items_other_id.IN_PLAY]) do
        if near(cand.pos, origin, s_radius) then
            cands[#cands+1] = cand
        end
    end
    table.sort(cands, function(a, b)
        return math.abs(a.pos.x - origin.x) + math.abs(a.pos.y - origin.y)
            < math.abs(b.pos.x - origin.x) + math.abs(b.pos.y - origin.y)
    end)
    local cap = effective_weight_cap(unit)
    for _,cand in ipairs(cands) do
        if attached_count(t) >= s_max then break end
        if extra_ok(cand, anchor, dest, origin, t.weight, cap)
                and dfhack.items.moveToInventory(
                    cand, unit, df.inv_item_role_type.Hauled, -1) then
            cand.flags.in_job = true
            t.extras[cand.id] = cand
            t.weight = t.weight + item_weight(cand)
        end
    end
end

local function scan_unit(unit)
    local job = unit.job.current_job
    local t = tracked[unit.id]

    -- drop tracking if the job ended or changed
    if t and (not job or job.id ~= t.job_id) then
        release_all(unit.id)
        t = nil
    end

    if not job then return end
    local dest = get_job_dest(job)
    if not dest then return end
    local anchor = dest.anchor
    if not anchor or df.isvalid(anchor) ~= 'ref' then return end

    local ready
    if dest.pile or job.job_type == df.job_type.StoreItemInVehicle then
        -- wait until the anchor item is actually picked up
        ready = anchor.flags.in_inventory and held_by(unit, anchor)
    else
        -- barrel/bin jobs: the dwarf carries the container to the goods;
        -- grab extras once the dwarf reaches the goods
        ready = near(unit.pos, anchor.pos, math.max(s_radius, 2))
    end
    if not ready then return end

    if not t then
        -- weight covers the whole carried load: the primary item, the
        -- container itself for barrel/bin runs, and every extra
        local weight = item_weight(anchor)
        if job.job_type == df.job_type.StoreItemInBarrel
                or job.job_type == df.job_type.StoreItemInBin then
            weight = weight + item_weight(dest.container)
        end
        t = {job_id=job.id, primary_id=anchor.id, pile=dest.pile,
             container=dest.container, extras={}, weight=weight,
             scan_cd=5}
        tracked[unit.id] = t
        grab_extras(t, unit, dest, anchor, anchor.pos)
    else
        -- the game drops non-job-linked hauled items; keep re-attaching our
        -- extras while the job is in flight so they ride along
        for item_id, extra in pairs(t.extras) do
            local valid = df.isvalid(extra) == 'ref'
            local real_claim = valid and real_job_claim(extra)
            if not valid or real_claim or extra.flags.forbid
                    or extra.flags.removed
                    or stockpile_assigned(extra) then
                if valid and not real_claim then
                    extra.flags.in_job = false
                end
                t.extras[item_id] = nil
            elseif t.pile and extra.flags.on_ground
                    and dfhack.buildings.findAtTile(
                        extra.pos.x, extra.pos.y, extra.pos.z) == t.pile then
                -- the game dropped it directly inside the pile: done
                extra.flags.in_job = false
                t.extras[item_id] = nil
            elseif t.container and contained_in(extra) == t.container then
                -- it is already inside the destination container: done
                extra.flags.in_job = false
                t.extras[item_id] = nil
            elseif not extra.flags.in_inventory then
                if dfhack.items.moveToInventory(
                        extra, unit, df.inv_item_role_type.Hauled, -1) then
                    extra.flags.in_job = true
                end
            end
        end
        -- opportunistically pick up more extras the dwarf walks past,
        -- throttled to every few polls
        t.scan_cd = (t.scan_cd or 0) - 1
        if t.scan_cd <= 0 and attached_count(t) < s_max then
            t.scan_cd = 5
            grab_extras(t, unit, dest, anchor, unit.pos)
        end
    end
end

-- self-healing sweep: our extras carry only the in_job flag, never a JOB
-- specific_ref. If the tracking table is ever lost (script reload, env
-- reset) a dropped extra would keep that flag forever and become
-- unclaimable. Clear any in_job flag that has no job behind it and is not
-- a currently-tracked extra.
local function sweep_orphans()
    local riding = {}
    for _,t in pairs(tracked) do
        for id in pairs(t.extras) do riding[id] = true end
    end
    for _,item in ipairs(df.global.world.items.all) do
        if item.flags.in_job and not riding[item.id]
                and not real_job_claim(item) then
            item.flags.in_job = false
        end
    end
end

local sweep_countdown = 0

local function event_loop()
    if not enabled then return end
    for _,unit in ipairs(dfhack.units.getCitizens()) do
        local ok, err = pcall(scan_unit, unit)
        if not ok then
            dfhack.printerr(('multihaul: scan_unit(%d): %s\n'):format(
                unit.id, tostring(err)))
        end
    end
    sweep_countdown = sweep_countdown - 1
    if sweep_countdown <= 0 then
        sweep_countdown = 500
        local ok, err = pcall(sweep_orphans)
        if not ok then
            dfhack.printerr(('multihaul: sweep: %s\n'):format(tostring(err)))
        end
    end
    repeatutil.scheduleUnlessAlreadyScheduled(
        TIMER_NAME, POLL_FRAMES, 'frames', event_loop)
end

local function print_status()
    print(('multihaul is %s (max=%d, radius=%d, weight=%s, types=%s, targets=%s)')
        :format(enabled and 'enabled' or 'disabled', s_max, s_radius,
            s_weight == 'auto' and 'auto'
                or (s_weight > 0 and tostring(s_weight) or 'unlimited'),
            s_types_all and 'all' or 'same',
            s_targets_all and 'all' or 'piles'))
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_WORLD_UNLOADED or sc == SC_MAP_UNLOADED then
        -- best effort: unmark extras before the save is written so they
        -- don't persist with a bogus in_job flag
        for _,t in pairs(tracked) do
            for _,item in pairs(t.extras) do
                pcall(function()
                    if df.isvalid(item) == 'ref'
                            and not real_job_claim(item) then
                        item.flags.in_job = false
                    end
                end)
            end
        end
        tracked = {}
    elseif sc == SC_WORLD_LOADED then
        load_state()
        if enabled then event_loop() end
    end
end

if dfhack_flags.module then
    return
end

local args = {...}
if dfhack_flags and dfhack_flags.enable then
    table.insert(args, dfhack_flags.enable_state and 'enable' or 'disable')
end
local cmd = args[1]

if cmd == 'enable' then
    enabled = true
    persist_state()
    sweep_orphans()
    event_loop()
    print_status()
elseif cmd == 'disable' then
    enabled = false
    for unit_id in pairs(tracked) do release_all(unit_id) end
    repeatutil.cancel(TIMER_NAME)
    persist_state()
    print_status()
elseif cmd == 'max' then
    s_max = math.max(1, math.floor(tonumber(args[2]) or s_max))
    persist_state()
    print_status()
elseif cmd == 'radius' then
    s_radius = math.max(0, math.floor(tonumber(args[2]) or s_radius))
    persist_state()
    print_status()
elseif cmd == 'weight' then
    if args[2] == 'auto' then
        s_weight = 'auto'
    elseif args[2] == 'unlimited' then
        s_weight = 0
    else
        local n = tonumber(args[2])
        if not n then
            qerror('usage: multihaul weight <n>|auto|unlimited')
        end
        s_weight = math.max(0, math.floor(n))
    end
    persist_state()
    print_status()
elseif cmd == 'types' then
    if args[2] ~= 'same' and args[2] ~= 'all' then
        qerror('usage: multihaul types same|all')
    end
    s_types_all = args[2] == 'all'
    persist_state()
    print_status()
elseif cmd == 'targets' then
    if args[2] ~= 'piles' and args[2] ~= 'all' then
        qerror('usage: multihaul targets piles|all')
    end
    s_targets_all = args[2] == 'all'
    persist_state()
    print_status()
elseif cmd == 'help' or cmd == '--help' then
    print(dfhack.script_help())
elseif cmd == 'status' or not cmd then
    print_status()
else
    qerror(('unknown command: %s'):format(cmd))
end
