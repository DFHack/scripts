-- instantly completes unsuspended building construction jobs

local argparse = require('argparse')
local gui = require('gui')
local utils = require('utils')

local ok, buildingplan = pcall(require, 'plugins.buildingplan')
if not ok then
    buildingplan = nil
end

local function min_to_max(...)
    local args = {...}
    table.sort(args, function(a, b) return a < b end)
    return table.unpack(args)
end

local function parse_commandline(args)
    local opts = {}
    local positionals = argparse.processArgsGetopt(args, {
            {'h', 'help', handler=function() opts.help = true end},
            {'q', 'quiet', handler=function() opts.quiet = true end},
            {'z', 'zlevel', handler=function() opts.zlevel = true end},
        })

    if positionals[1] == 'help' then opts.help = true end
    if opts.help then return opts end

    if #positionals >= 1 then
        opts.start = argparse.coords(positionals[1])
        if #positionals >= 2 then
            opts['end'] = argparse.coords(positionals[2])
            opts.start.x, opts['end'].x = min_to_max(opts.start.x,opts['end'].x)
            opts.start.y, opts['end'].y = min_to_max(opts.start.y,opts['end'].y)
            opts.start.z, opts['end'].z = min_to_max(opts.start.z,opts['end'].z)
        else
            opts['end'] = opts.start
        end
    else
        -- default to covering entire map
        opts.start = xyz2pos(0, 0, 0)
        local x, y, z = dfhack.maps.getTileSize()
        opts['end'] = xyz2pos(x-1, y-1, z-1)
    end
    if opts.zlevel then
        opts.start.z = df.global.window_z
        opts['end'].z = df.global.window_z
    end
    return opts
end

-- gets list of jobs that meet all of the following criteria:
--   is a building construction job
--   has all job_items attached
--   is not suspended
--   target building is within the processing area
local function get_jobs(opts)
    local num_suspended, num_incomplete, num_clipped, jobs = 0, 0, 0, {}
    for _,job in utils.listpairs(df.global.world.jobs.list) do
        if job.job_type ~= df.job_type.ConstructBuilding then goto continue end
        if job.flags.suspend then
            num_suspended = num_suspended + 1
            goto continue
        end

        -- job_items are not items, they're filters that describe the kinds of
        -- items that need to be attached.
        for _,job_item in ipairs(job.job_items.elements) do
            -- we have to check for quantity != 0 instead of just the existence
            -- of the job_item since buildingplan leaves 0-quantity job_items in
            -- place to protect against persistence errors.
            if job_item.quantity > 0 then
                num_incomplete = num_incomplete + 1
                goto continue
            end
        end

        local bld = dfhack.job.getHolder(job)
        if not bld then
            dfhack.printerr(
                'skipping construction job without attached building')
            goto continue
        end

        -- accept building if any part is within the processing area
        if bld.z < opts.start.z or bld.z > opts['end'].z
                or bld.x2 < opts.start.x or bld.x1 > opts['end'].x
                or bld.y2 < opts.start.y or bld.y1 > opts['end'].y then
            num_clipped = num_clipped + 1
            goto continue
        end

        table.insert(jobs, job)
        ::continue::
    end
    if not opts.quiet then
        if num_suspended > 0 then
            print(('Skipped %d suspended building%s')
                  :format(num_suspended, num_suspended ~= 1 and 's' or ''))
        end
        if num_incomplete > 0 then
            print(('Skipped %d building%s with pending items')
                  :format(num_incomplete, num_incomplete ~= 1 and 's' or ''))
        end
        if num_clipped > 0 then
            print(('Skipped %d building%s out of processing range')
                  :format(num_clipped, num_clipped ~= 1 and 's' or ''))
        end
    end
    return jobs
end

-- returns a list of map blocks that contain items that are in the footprint
local function get_map_blocks_with_items_in_footprint(bld)
    local blockset = {}
    for x = bld.x1,bld.x2 do
        for y = bld.y1,bld.y2 do
            local block = dfhack.maps.ensureTileBlock(x, y, bld.z)
            if block.occupancy[x%16][y%16].item ~= 0 then
                blockset[block] = true
            end
        end
    end
    local blocks = {}
    for block in pairs(blockset) do table.insert(blocks, block) end
    return blocks
end

local function transform(tab, transform_fn)
    local ret = {}
    for k,v in pairs(tab) do
        ret[k] = transform_fn(v)
    end
    return ret
end

local function get_item_id(item)
    return item.id
end

local function get_items_within_footprint(blocks, bld, ignore_items)
    -- can't compare userdata items directly, so we'll compare ids
    local ignore_set = utils.invert(transform(ignore_items, get_item_id))
    local items = {}
    for _,block in ipairs(blocks) do
        for _,itemid in ipairs(block.items) do
            local item = df.item.find(itemid)
            local pos = item.pos
            if item.flags.on_ground and gui.is_in_rect(bld, pos.x, pos.y) then
                if item.flags.in_job then
                    -- if the job that the item is associated with is the one
                    -- for building this building, then that's ok. it will be
                    -- moved directly into the building later.
                    if not ignore_set[item.id] then
                        return false
                    end
                else
                    table.insert(items, item)
                end
            end
        end
    end
    return true, items
end

-- returns whether this is a match and whether we should continue searching
-- beyond this tile
local function is_good_dump_pos(pos)
    local tt = dfhack.maps.getTileType(pos)
    -- reject bad coordinates (or map blocks that haven't been loaded)
    if not tt then return false, false end
    local flags, occupancy = dfhack.maps.getTileFlags(pos)
    local attrs = df.tiletype.attrs[tt]
    local shape_attrs = df.tiletype_shape.attrs[attrs.shape]
    -- reject hidden tiles
    if flags.hidden then return false, false end
    -- reject unwalkable tiles
    if not shape_attrs.walkable then return false, false end
    -- reject footprints within other buildings. this could potentially be
    -- relaxed a bit since we can technically dump items on passable tiles
    -- within other buildings, but that would look messy.
    if occupancy.building ~= df.tile_building_occ.None then
        return false, true
    end
    -- success!
    return true
end

-- noop if pos is in the seen map. otherwise marks pos in the seen map and
-- enqueues pos in queue
local function enqueue_if_unseen(seen, queue, pos)
    if seen[pos.x] and seen[pos.x][pos.y] then return end
    seen[pos.x] = seen[pos.x] or {}
    seen[pos.x][pos.y] = true
    table.insert(queue, pos)
end

local function check_and_flood(seen, queue, pos)
    local is_match, should_flood = is_good_dump_pos(pos)
    if is_match then return pos end
    if not should_flood then return end
    local x, y, z = pos.x, pos.y, pos.z
    enqueue_if_unseen(seen, queue, xyz2pos(x-1, y-1, z))
    enqueue_if_unseen(seen, queue, xyz2pos(x,   y-1, z))
    enqueue_if_unseen(seen, queue, xyz2pos(x+1, y-1, z))
    enqueue_if_unseen(seen, queue, xyz2pos(x-1, y,   z))
    enqueue_if_unseen(seen, queue, xyz2pos(x+1, y,   z))
    enqueue_if_unseen(seen, queue, xyz2pos(x-1, y+1, z))
    enqueue_if_unseen(seen, queue, xyz2pos(x,   y+1, z))
    enqueue_if_unseen(seen, queue, xyz2pos(x+1, y+1, z))
end

-- does a flood search to find the nearest tile where we can freely dump items
local function search_dump_pos(bld)
    local seen = {[bld.centerx]={[bld.centery]=true}}
    local queue, i = {xyz2pos(bld.centerx, bld.centery, bld.z)}, 1
    while queue[i] do
        local good_pos = check_and_flood(seen, queue, queue[i])
        if good_pos then return good_pos end
        queue[i] = nil
        i = i + 1
    end
end

-- uses the flood search algorithm to find a free tile. if that fails, returns
-- the position of the first fort citizen. if that fails, returns the position
-- of the first active unit.
local function get_dump_pos(bld)
    local dump_pos = search_dump_pos(bld)
    if dump_pos then
        return dump_pos
    end
    for _,unit in ipairs(dfhack.units.getCitizens(true)) do
        return unit.pos
    end
    -- fall back to position of first active unit
    return df.global.world.units.active[0].pos
end

-- move items away from the construction site
local function clear_footprint(bld, ignore_items)
    -- check building tiles for items. if none exist, exit early with success
    local blocks = get_map_blocks_with_items_in_footprint(bld)
    if #blocks == 0 then return true end
    local ok, items = get_items_within_footprint(blocks, bld, ignore_items)
    if not ok then return false end
    local dump_pos = get_dump_pos(bld)
    for _,item in ipairs(items) do
        if not dfhack.items.moveToGround(item, dump_pos) then return false end
    end
    return true
end

local function get_items(job)
    local items = {}
    for _,item_ref in ipairs(job.items) do
        table.insert(items, item_ref.item)
    end
    return items
end

-- teleport any items that are not already part of the building to the building
-- center and mark them as part of the building. this handles both partially-
-- built buildings and items that are being carried to the building correctly.
local function attach_items(bld, items)
    for _,item in ipairs(items) do
        -- skip items that have already been brought to the building
        if item.flags.in_building then goto continue end
        -- 2 means "make part of bld" (which causes constructions to crash on
        -- deconstruct)
        local use = bld:getType() == df.building_type.Construction and 0 or 2
        if not dfhack.items.moveToBuilding(item, bld, use) then return false end
        ::continue::
    end
    return true
end

-- complete architecture, if required, and perform the adjustments the game
-- normally does when a building is built. this logic is reverse engineered from
-- observing game behavior and may be incomplete.
local function build_building(bld)
    if bld:needsDesign() then
        -- unlike "natural" builds, we don't set the architect or builder unit
        -- id. however, this doesn't seem to have any in-game effect.
        local design = bld.design
        design.flags.designed = true
        design.flags.built = true
        design.hitpoints = 80640
        design.max_hitpoints = 80640
    end
    bld:setBuildStage(bld:getMaxBuildStage())
    dfhack.buildings.completeBuild(bld)
end

local function throw(bld, msg)
    msg = msg .. ('; please remove and recreate the %s at (%d, %d, %d)')
                 :format(df.building_type[bld:getType()],
                         bld.centerx, bld.centery, bld.z)
    qerror(msg)
end

-- main script
local opts = parse_commandline({...})
if opts.help then print(dfhack.script_help()) return end

-- ensure buildingplan is up to date so we don't skip buildings just because
-- buildingplan hasn't scanned them yet
if buildingplan then
    buildingplan.doCycle()
end

local num_jobs = 0
for _,job in ipairs(get_jobs(opts)) do
    local bld = dfhack.job.getHolder(job)

    -- retrieve the items attached to the job before we destroy the references
    local items = get_items(job)

    local bld_type = bld:getType()
    if #items == 0 and bld_type ~= df.building_type.RoadDirt
            and bld_type ~= df.building_type.FarmPlot then
        print(('skipping building with no items attached at'..
               ' (%d, %d, %d)'):format(bld.centerx, bld.centery, bld.z))
        goto continue
    end

    -- skip jobs whose attached items are already owned by the target building
    -- but are not already part of the building. They are actively being used to
    -- construct the building and we can't safely change the building's state.
    for _,item in ipairs(items) do
        if not item.flags.in_building and
                bld == dfhack.items.getHolderBuilding(item) then
            if not opts.quiet then
                print(
                    ('skipping building that is actively being constructed at'..
                     ' (%d, %d, %d)'):format(bld.centerx, bld.centery, bld.z))
            end
            goto continue
        end
    end

    -- clear non-job items from the planned building footprint
    if not clear_footprint(bld, items) then
        dfhack.printerr(
            ('cannot move items blocking building site at (%d, %d, %d)')
            :format(bld.centerx, bld.centery, bld.z))
        goto continue
    end

    -- remove job data and attach items to building.
    if not dfhack.job.removeJob(job) then
        throw(bld, 'failed to remove job; job state may be inconsistent')
    end

    if not attach_items(bld, items) then
        throw(bld,
              'failed to attach items to building; state may be inconsistent')
    end

    build_building(bld)

    num_jobs = num_jobs + 1
    ::continue::
end

if num_jobs > 0 then
    df.global.world.reindex_pathfinding = true
end

if not opts.quiet then
    print(('Completed %d construction job%s')
        :format(num_jobs, num_jobs ~= 1 and 's' or ''))
end
