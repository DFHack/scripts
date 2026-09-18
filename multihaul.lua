-- Citizens carry extra loose items when hauling to a stockpile.
--[====[

multihaul
=========

When a citizen picks up an item for a stockpile, they also grab up to
``max`` additional loose items of the same type within ``radius`` tiles,
then drop everything off in one trip. Not enabled by default; run
``multihaul enable`` or ``enable multihaul`` to turn it on.

Usage::

    multihaul enable|disable
    multihaul status
    multihaul max <n>      (default 4, max extra items per trip)
    multihaul radius <n>   (default 2, tiles around the pickup)

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

-- transient state
-- unit_id -> {job_id=number, primary_id=number, pile=building, extras={item_id -> item}}
tracked = tracked or {}

function isEnabled()
    return enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, {
        enabled=enabled,
        s_max=s_max,
        s_radius=s_radius,
    })
end

local function load_state()
    local data = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    enabled = data.enabled or false
    s_max = data.s_max or 4
    s_radius = data.s_radius or 2
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

local function is_loose_item(item)
    local f = item.flags
    return f.on_ground and not f.in_job and not f.in_inventory
        and not f.in_building and not f.forbid and not f.owned
        and not f.hostile and not f.trader and not f.spider_web
        and not f.construction and not f.encased and not f.removed
        and not f.garbage_collect and not f.container and not f.rotten
        and not f.dump and not f.melt and item:getStockpile() == nil
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

-- release all piggybacked items. If the job completed normally, the primary
-- item was just placed on a stockpile tile: land the extras on that same
-- tile so they are stocked too. If the job ended while the unit was at or
-- next to the pile (e.g. a vehicle handoff), land them on the closest pile
-- tile instead. Otherwise drop them at the unit's feet.
local function release_all(unit_id)
    local t = tracked[unit_id]
    if not t then return end
    tracked[unit_id] = nil

    local unit = df.unit.find(unit_id)
    local drop_pos
    local primary = t.primary_id and df.item.find(t.primary_id)
    if primary and df.isvalid(primary) == 'ref'
            and dfhack.buildings.findAtTile(
                primary.pos.x, primary.pos.y, primary.pos.z) == t.pile then
        drop_pos = primary.pos
    elseif unit then
        drop_pos = nearest_pile_tile(t.pile, unit.pos, 4) or unit.pos
    end
    for item_id, item in pairs(t.extras) do
        if df.isvalid(item) == 'ref' then
            item.flags.in_job = false
            if unit and drop_pos and held_by(unit, item) then
                dfhack.items.moveToGround(item, drop_pos)
            end
        end
        t.extras[item_id] = nil
    end
end

local function job_item_of(job)
    if #job.items == 0 then return nil end
    local item = job.items[0].item
    return (item and df.isvalid(item) == 'ref') and item or nil
end

local function scan_unit(unit)
    local job = unit.job.current_job
    local t = tracked[unit.id]

    -- drop tracking if the job ended or changed
    if t then
        if not job or job.id ~= t.job_id then
            release_all(unit.id)
            t = nil
        end
    end

    if not job or job.job_type ~= df.job_type.StoreItemInStockpile then
        return
    end

    local item = job_item_of(job)
    if not item then return end
    local pile = get_job_stockpile(job)
    if not pile then return end

    if not item.flags.in_inventory then
        -- still walking to the pickup
        return
    end

    -- job item has been picked up: deliver any extras we're carrying, or
    -- attach extras if this is the first poll after pickup
    if not t then
        t = {job_id=job.id, primary_id=item.id, pile=pile, extras={}}
        tracked[unit.id] = t
        local job_type = item:getType()
        local attached = 0
        for _,cand in ipairs(df.global.world.items.other[
                df.items_other_id.IN_PLAY]) do
            if attached >= s_max then break end
            if cand ~= item and is_loose_item(cand)
                    and cand:getType() == job_type
                    and not dfhack.buildings.findAtTile(
                        cand.pos.x, cand.pos.y, cand.pos.z)
                    and cand.pos.z == unit.pos.z
                    and math.abs(cand.pos.x - unit.pos.x) <= s_radius
                    and math.abs(cand.pos.y - unit.pos.y) <= s_radius
                    and dfhack.items.moveToInventory(
                        cand, unit, df.inv_item_role_type.Hauled, -1) then
                cand.flags.in_job = true
                t.extras[cand.id] = cand
                attached = attached + 1
            end
        end
    else
        -- the game drops non-job-linked hauled items; keep re-attaching our
        -- extras while the job is in flight so they ride along
        for item_id, extra in pairs(t.extras) do
            local valid = df.isvalid(extra) == 'ref'
            if not valid or extra.flags.forbid
                    or extra:getStockpile() ~= nil then
                if valid then extra.flags.in_job = false end
                t.extras[item_id] = nil
            elseif extra.flags.on_ground and dfhack.buildings.findAtTile(
                    extra.pos.x, extra.pos.y, extra.pos.z) == t.pile then
                -- the game dropped it directly inside the pile: done
                extra.flags.in_job = false
                t.extras[item_id] = nil
            elseif not extra.flags.in_inventory then
                dfhack.items.moveToInventory(
                    extra, unit, df.inv_item_role_type.Hauled, -1)
            end
        end
    end
end

local function event_loop()
    if not enabled then return end
    for _,unit in ipairs(dfhack.units.getCitizens()) do
        local ok, err = pcall(scan_unit, unit)
        if not ok then
            dfhack.printerr(('multihaul: scan_unit(%d): %s\n'):format(
                unit.id, tostring(err)))
        end
    end
    repeatutil.scheduleUnlessAlreadyScheduled(
        TIMER_NAME, POLL_FRAMES, 'frames', event_loop)
end

local function print_status()
    print(('multihaul is %s (max=%d, radius=%d)'):format(
        enabled and 'enabled' or 'disabled', s_max, s_radius))
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_WORLD_UNLOADED or sc == SC_MAP_UNLOADED then
        tracked = {}
    elseif sc == SC_WORLD_LOADED then
        load_state()
        if enabled then event_loop() end
    end
end

local args = {...}
if dfhack_flags and dfhack_flags.enable then
    table.insert(args, dfhack_flags.enable_state and 'enable' or 'disable')
end
local cmd = args[1]

if cmd == 'enable' then
    enabled = true
    persist_state()
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
elseif cmd == 'status' or not cmd then
    print_status()
else
    qerror(('unknown command: %s'):format(cmd))
end
